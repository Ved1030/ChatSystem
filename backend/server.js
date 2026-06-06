require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { initializeFirebase } = require('./src/firebase/firebaseAdmin');
const { listenForNewMessages } = require('./src/services/notificationService');
const { startCleanupJob } = require('./src/jobs/cleanupExpiredMedia');
const notificationRoutes = require('./src/routes/notificationRoutes');
const logger = require('./src/utils/logger');

const app = express();
const PORT = process.env.PORT || 3000;

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: 'Too many requests, please try again later.' },
});

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '10kb' }));
app.use('/api/', limiter);

app.use('/api/notifications', notificationRoutes);

app.get('/', (req, res) => {
  res.json({
    name: 'Chat App Notification Server',
    version: '1.0.0',
    status: 'running',
  });
});

app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

initializeFirebase();
listenForNewMessages();
startCleanupJob(60);

app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Server running on port ${PORT}`);
});

module.exports = app;
