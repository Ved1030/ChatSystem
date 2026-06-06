const express = require('express');
const router = express.Router();
const { sendMessageNotification } = require('../controllers/notificationController');
const { authMiddleware } = require('../middleware/auth');

router.post('/send', authMiddleware, sendMessageNotification);

router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

module.exports = router;
