const { Timestamp, FieldValue } = require('firebase-admin').firestore;
const { getDb } = require('../firebase/firebaseAdmin');
const logger = require('../utils/logger');

async function cleanupExpiredMedia() {
  const db = getDb();
  const now = new Date();

  try {
    const expiredMessages = await db
      .collectionGroup('messages')
      .where('messageType', '==', 'image')
      .where('imageMode', '==', 'temporary')
      .where('expiresAt', '<=', Timestamp.fromDate(now))
      .get();

    let deletedCount = 0;
    let batch = db.batch();
    let batchCount = 0;

    expiredMessages.forEach((doc) => {
      batch.update(doc.ref, {
        isDeleted: true,
        deletedAt: FieldValue.serverTimestamp(),
      });
      deletedCount++;
      batchCount++;

      if (batchCount >= 500) {
        batch.commit().catch((err) => {
          logger.error('Batch commit error:', err);
        });
        batch = db.batch();
        batchCount = 0;
      }
    });

    if (batchCount > 0) {
      await batch.commit();
    }

    if (deletedCount > 0) {
      logger.info(`Cleaned up ${deletedCount} expired media messages`);
    }

    return { deleted: deletedCount };
  } catch (error) {
    logger.error('Error cleaning up expired media:', error);
    return { deleted: 0, error: error.message };
  }
}

function startCleanupJob(intervalMinutes = 60) {
  logger.info(`Starting cleanup job (interval: ${intervalMinutes} minutes)`);
  cleanupExpiredMedia().catch((err) => {
    logger.error('Initial cleanup job error:', err);
  });

  setInterval(() => {
    cleanupExpiredMedia().catch((err) => {
      logger.error('Cleanup job error:', err);
    });
  }, intervalMinutes * 60 * 1000);
}

module.exports = { cleanupExpiredMedia, startCleanupJob };
