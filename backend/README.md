# Chat App Backend - Push Notification Server

Node.js backend for handling push notifications via Firebase Cloud Messaging.

## Architecture

```
Flutter App -> Firestore -> Node.js Backend -> FCM -> Receiver Device
```

The backend listens to Firestore for new messages using collectionGroup queries and sends FCM notifications to the receiver.

## Setup

1. Install dependencies:
   ```bash
   cd backend
   npm install
   ```

2. Set up Firebase Admin SDK:
   - Download service account key from Firebase Console
   - Save as `service-account.json` in the backend root
   - OR set environment variables:
     ```
     FIREBASE_PROJECT_ID=your-project-id
     FIREBASE_CLIENT_EMAIL=your-client-email
     FIREBASE_PRIVATE_KEY="your-private-key"
     ```

3. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

4. Start the server:
   ```bash
   npm start
   ```

## API Endpoints

### POST /api/notifications/send
Send a push notification for a new message.

**Auth:** Bearer token (Firebase ID token)

**Body:**
```json
{
  "senderId": "string",
  "receiverId": "string",
  "roomId": "string",
  "message": "string",
  "messageType": "text|image|audio|video",
  "messageId": "string"
}
```

### GET /api/notifications/health
Health check endpoint.

## Deployment on Render

1. Push the backend folder to a GitHub repository
2. On Render, create a new Web Service
3. Connect your repository
4. Set:
   - Build Command: `npm install`
   - Start Command: `npm start`
5. Add environment variables from `.env.example`
6. Deploy

## Firestore Listener

The server automatically listens to Firestore collectionGroup `messages` for new documents and sends push notifications.
