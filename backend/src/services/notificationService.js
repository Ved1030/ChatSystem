const https = require('https');

const ONESIGNAL_APP_ID = '2d827c01-a2bd-47fb-a9f0-36744e68a51d';

async function sendOneSignalNotification({ externalId, title, body, data, soundEnabled, vibrationEnabled }) {
  const restApiKey = process.env.ONESIGNAL_REST_API_KEY;
  if (!restApiKey) {
    return { success: false, error: 'ONESIGNAL_REST_API_KEY not configured' };
  }

  const notificationPayload = {
    app_id: ONESIGNAL_APP_ID,
    include_aliases: {
      external_id: [externalId],
    },
    target_channel: 'push',
    headings: { en: title },
    contents: { en: body },
    data: data || {},
    priority: 10,
  };

  if (soundEnabled !== false) {
    notificationPayload.android_sound = 'default';
    notificationPayload.ios_sound = 'default';
  }
  if (vibrationEnabled !== false) {
    notificationPayload.android_vibrate = true;
  }

  return new Promise((resolve) => {
    const payload = JSON.stringify(notificationPayload);

    const options = {
      hostname: 'api.onesignal.com',
      path: '/notifications',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${restApiKey}`,
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    const req = https.request(options, (res) => {
      let responseBody = '';
      res.on('data', (chunk) => {
        responseBody += chunk;
      });
      res.on('end', () => {
        try {
          const result = JSON.parse(responseBody);
          if (result.id) {
            resolve({ success: true, notificationId: result.id });
          } else {
            resolve({ success: false, error: result.errors ? result.errors.join(', ') : 'Unknown error' });
          }
        } catch (e) {
          resolve({ success: false, error: responseBody });
        }
      });
    });

    req.on('error', (error) => {
      resolve({ success: false, error: error.message });
    });

    req.write(payload);
    req.end();
  });
}

module.exports = { sendOneSignalNotification };
