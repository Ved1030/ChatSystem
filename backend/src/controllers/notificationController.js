const { sendNotification } = require('../services/notificationService');
const logger = require('../utils/logger');

async function sendMessageNotification(req, res) {
  try {
    const { senderId, receiverId, roomId, message, messageType, messageId } = req.body;

    if (!senderId || !receiverId || !roomId || !message) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: senderId, receiverId, roomId, message',
      });
    }

    logger.info(`Notification request: sender=${senderId}, receiver=${receiverId}, room=${roomId}`);

    const result = await sendNotification(
      senderId,
      receiverId,
      roomId,
      message,
      messageType || 'text',
      messageId,
    );

    return res.status(200).json({
      success: result.success !== false,
      data: result,
    });
  } catch (error) {
    logger.error('Error sending notification:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
}

module.exports = { sendMessageNotification };
