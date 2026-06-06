const admin = require('firebase-admin');
const { getDb, sendFcmNotification } = require('../firebase/firebaseAdmin');
const logger = require('../utils/logger');

async function getReceiverInfo(receiverId) {
  const db = getDb();
  const userDoc = await db.collection('users').doc(receiverId).get();
  if (!userDoc.exists) return null;
  return userDoc.data();
}

async function getChatRoomInfo(roomId) {
  const db = getDb();
  const roomDoc = await db.collection('chat_rooms').doc(roomId).get();
  if (!roomDoc.exists) return null;
  return roomDoc.data();
}

async function getSenderName(senderId) {
  const db = getDb();
  const senderDoc = await db.collection('users').doc(senderId).get();
  if (!senderDoc.exists) return 'Someone';
  const data = senderDoc.data();
  return data.name || data.username || 'Someone';
}

function isMuted(roomData, receiverId) {
  if (!roomData) return false;

  const mutedBy = roomData.mutedBy || [];
  if (mutedBy.includes(receiverId)) return true;

  const mutedUntil = roomData.mutedUntil || {};
  const until = mutedUntil[receiverId];
  if (until) {
    const untilDate = typeof until.toDate === 'function' ? until.toDate() : new Date(until);
    if (untilDate > new Date()) return true;
  }

  return false;
}

function buildNotificationBody(messageType, text, messageData) {
  switch (messageType) {
    case 'image':
      return '📷 Photo';
    case 'audio':
      return '🎤 Voice Message';
    case 'video':
      return '📹 Video';
    default:
      return text || 'New message';
  }
}

async function processNewMessage(messageData, messageId) {
  const { senderId, receiverId, text, messageType } = messageData;
  let roomId = messageData.roomId;

  const [receiver, roomData, senderName] = await Promise.all([
    getReceiverInfo(receiverId),
    roomId ? getChatRoomInfo(roomId) : Promise.resolve(null),
    getSenderName(senderId),
  ]);

  if (!receiver) {
    logger.warn(`Receiver ${receiverId} not found`);
    return { sent: false, reason: 'Receiver not found' };
  }

  if (receiver.notificationsEnabled === false) {
    logger.debug(`Notifications disabled for user ${receiverId}`);
    return { sent: false, reason: 'Notifications disabled by receiver' };
  }

  if (roomData && isMuted(roomData, receiverId)) {
    logger.debug(`Chat ${roomId} muted for user ${receiverId}`);
    return { sent: false, reason: 'Chat muted by receiver' };
  }

  const fcmToken = receiver.fcmToken;
  if (!fcmToken) {
    logger.debug(`No FCM token for user ${receiverId}`);
    return { sent: false, reason: 'No FCM token' };
  }

  const title = `New message from ${senderName}`;
  const body = buildNotificationBody(messageType, text);

  const dataPayload = {
    type: 'new_message',
    senderId,
    receiverId,
    roomId: roomId || '',
    messageId: messageId || '',
  };

  logger.info(`Sending notification to ${receiverId}: ${title}`);

  const result = await sendFcmNotification({
    token: fcmToken,
    title,
    body,
    data: dataPayload,
  });

  if (result.success) {
    logger.info(`Notification sent successfully: ${result.messageId}`);
    if (roomId && messageId) {
      try {
        const db = getDb();
        const msgRef = db
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId);
        await msgRef.update({
          status: 'delivered',
          deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.debug(`Marked message ${messageId} as delivered`);
      } catch (err) {
        logger.error('Failed to mark message as delivered:', err);
      }
    }
  } else if (result.error === 'TOKEN_NOT_REGISTERED') {
    logger.warn(`FCM token not registered for user ${receiverId}, clearing token`);
    try {
      const db = getDb();
      await db.collection('users').doc(receiverId).update({
        fcmToken: null,
      });
    } catch (err) {
      logger.error('Failed to clear invalid token:', err);
    }
  } else {
    logger.error(`Failed to send notification: ${result.error}`);
  }

  return result;
}

function listenForNewMessages() {
  const db = getDb();

  try {
    const messagesRef = db.collectionGroup('messages');

    messagesRef.onSnapshot(
      (snapshot) => {
        snapshot.docChanges().forEach((change) => {
          if (change.type === 'added') {
            const messageData = change.doc.data();
            const messageId = change.doc.id;
            const roomId = change.doc.ref.path.split('/')[1];

            const senderId = messageData.senderId;
            const receiverId = messageData.receiverId;

            if (!senderId || !receiverId) return;
            if (senderId === receiverId) return;

            processNewMessage({ ...messageData, roomId }, messageId).catch((err) => {
              logger.error('Error processing message notification:', err);
            });
          }
        });
      },
      (error) => {
        logger.error('Firestore listener error:', error);
        setTimeout(listenForNewMessages, 5000);
      },
    );

    logger.info('Listening for new messages via collectionGroup...');
  } catch (error) {
    logger.error('Failed to start message listener:', error);
    setTimeout(listenForNewMessages, 10000);
  }
}

async function sendNotification(senderId, receiverId, roomId, message, messageType, messageId) {
  return processNewMessage(
    { senderId, receiverId, roomId, text: message, messageType },
    messageId,
  );
}

module.exports = {
  processNewMessage,
  listenForNewMessages,
  sendNotification,
};
