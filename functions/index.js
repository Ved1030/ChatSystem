const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

exports.sendMessageNotification = functions.firestore
  .document("chat_rooms/{roomId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const { roomId } = context.params;

    const messageData = snapshot.data();
    if (!messageData) {
      console.log("No message data found");
      return null;
    }

    const senderId = messageData.senderId;
    const receiverId = messageData.receiverId;
    const messageText = messageData.text || "";

    if (!receiverId || !senderId) {
      console.log("Missing senderId or receiverId");
      return null;
    }

    try {
      const senderSnapshot = await db.collection("users").doc(senderId).get();
      if (!senderSnapshot.exists) {
        console.log("Sender not found:", senderId);
        return null;
      }
      const senderData = senderSnapshot.data();
      const senderName = senderData?.name || senderData?.username || "Someone";

      const receiverSnapshot = await db.collection("users").doc(receiverId).get();
      if (!receiverSnapshot.exists) {
        console.log("Receiver not found:", receiverId);
        return null;
      }
      const receiverData = receiverSnapshot.data();
      const receiverFcmToken = receiverData?.fcmToken;

      if (!receiverFcmToken) {
        console.log("No FCM token for receiver:", receiverId);
        return null;
      }

      const payload = {
        token: receiverFcmToken,
        notification: {
          title: `New Message from ${senderName}`,
          body: messageText,
        },
        data: {
          chatRoomId: roomId,
          senderId: senderId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
            priority: "high",
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              alert: {
                title: `New Message from ${senderName}`,
                body: messageText,
              },
            },
          },
        },
      };

      const response = await admin.messaging().send(payload);
      console.log("Notification sent successfully:", response);
      return response;
    } catch (error) {
      console.error("Error sending notification:", error);
      if (
        error.code === "messaging/invalid-argument" ||
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        try {
          await db.collection("users").doc(receiverId).update({
            fcmToken: admin.firestore.FieldValue.delete(),
          });
          console.log("Cleared invalid FCM token for:", receiverId);
        } catch (updateError) {
          console.error("Error clearing token:", updateError);
        }
      }
      return null;
    }
  });
