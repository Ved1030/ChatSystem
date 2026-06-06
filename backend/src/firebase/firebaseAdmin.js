const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

let db;
let messaging;

function initializeFirebase() {
  if (admin.apps.length > 0) {
    return;
  }

  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (serviceAccountPath && fs.existsSync(path.resolve(serviceAccountPath))) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } else if (process.env.FIREBASE_PRIVATE_KEY) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      }),
    });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }

  db = admin.firestore();
  messaging = admin.messaging();
}

function getDb() {
  if (!db) throw new Error('Firebase not initialized');
  return db;
}

function getMessaging() {
  if (!messaging) throw new Error('Firebase not initialized');
  return messaging;
}

async function verifyIdToken(idToken) {
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    return decoded;
  } catch (error) {
    throw new Error('Invalid token');
  }
}

async function sendFcmNotification({ token, title, body, data }) {
  const message = {
    token,
    notification: { title, body },
    data: data || {},
    android: {
      priority: 'high',
      notification: {
        channelId: 'chat_messages',
        priority: 'high',
        sound: 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          contentAvailable: true,
        },
      },
    },
  };

  try {
    const response = await getMessaging().send(message);
    return { success: true, messageId: response };
  } catch (error) {
    if (error.code === 'messaging/registration-token-not-registered') {
      return { success: false, error: 'TOKEN_NOT_REGISTERED' };
    }
    return { success: false, error: error.message };
  }
}

module.exports = {
  initializeFirebase,
  getDb,
  getMessaging,
  verifyIdToken,
  sendFcmNotification,
};
