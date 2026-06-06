const { sendOneSignalNotification } = require('../services/notificationService');
const logger = require('../utils/logger');

const sentMessageIds = new Set();
const DEDUP_TTL_MS = 5 * 60 * 1000;

function markSent(messageId) {
  sentMessageIds.add(messageId);
  setTimeout(() => sentMessageIds.delete(messageId), DEDUP_TTL_MS);
}

async function handleSendNotification(req, res) {
  try {
    const {
      senderId,
      receiverId,
      roomId,
      message,
      messageType,
      messageId,
      senderName,
      notificationsEnabled,
      soundEnabled,
      vibrationEnabled,
      isMuted,
    } = req.body;

    logger.info(`[REQUEST] senderId=${senderId} receiverId=${receiverId} roomId=${roomId} messageType=${messageType} messageId=${messageId}`);

    if (!senderId || !receiverId || !roomId || !message) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: senderId, receiverId, roomId, message',
      });
    }

    if (!notificationsEnabled) {
      logger.info(`[SKIP] notifications disabled for receiver ${receiverId}`);
      return res.json({ success: true, skipped: 'notifications disabled' });
    }

    if (isMuted) {
      logger.info(`[SKIP] chat muted for receiver ${receiverId} room ${roomId}`);
      return res.json({ success: true, skipped: 'chat muted' });
    }

    if (messageId && sentMessageIds.has(messageId)) {
      logger.info(`[SKIP] duplicate message ${messageId}`);
      return res.json({ success: true, skipped: 'duplicate' });
    }

    if (messageId) {
      markSent(messageId);
    }

    const title = 'New Message';
    const body = 'You have received a new message';

    const dataPayload = {
      type: 'new_message',
      senderId,
      receiverId,
      roomId,
      messageId: messageId || '',
    };

    logger.info(`[ONESIGNAL SEND] externalId=${receiverId} title="${title}" body="${body}"`);

    const result = await sendOneSignalNotification({
      externalId: receiverId,
      title,
      body,
      data: dataPayload,
      soundEnabled,
      vibrationEnabled,
    });

    if (result.success) {
      logger.info(`[ONESIGNAL OK] notificationId=${result.notificationId} messageId=${messageId}`);
    } else {
      logger.error(`[ONESIGNAL FAIL] error=${result.error} messageId=${messageId}`);
    }

    return res.json({ success: result.success, data: result });
  } catch (error) {
    logger.error('[CONTROLLER ERROR]', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
}

module.exports = { handleSendNotification };
