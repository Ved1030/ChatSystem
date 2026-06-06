const express = require('express');
const router = express.Router();
const { apiKeyAuth } = require('../middleware/auth');
const { handleSendNotification } = require('../controllers/notificationController');

router.post('/send-notification', apiKeyAuth, handleSendNotification);

module.exports = router;
