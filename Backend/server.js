/**
 * @file server.js
 * @description Main entry point for the Node.js Express backend. Initializes
 * the Firebase Admin SDK, sets up middleware, and mounts API routes.
 */
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 4000;

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Check for required Gemini API key
if (!process.env.GEMINI_API_KEY) {
  console.warn('\n⚠️  [Civic App Warning]: GEMINI_API_KEY is missing in your .env configuration.');
  console.warn('👉 AI classification and chatbot services require a Gemini API key.');
  console.warn('👉 Refer to "Backend/.env.example" to set it up.\n');
}

// Initialize Firebase Admin SDK using the local service account key.
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(serviceAccountPath)) {
  console.error('\n❌ [Firebase Init Error]: serviceAccountKey.json not found!');
  console.error('👉 Please download your Firebase service account key and place it as "Backend/serviceAccountKey.json".');
  console.error('👉 Refer to "Backend/serviceAccountKey.example.json" for instructions.\n');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});

// Expose Firestore instance to the app locals for easy access in routes.
const db = admin.firestore();
app.locals.db = db;

// Start Real-Time Status Monitor
const { startStatusMonitor } = require('./services/statusMonitor');
startStatusMonitor(db);

/**
 * Global Middleware Setup
 * - Request logging
 * - CORS
 * - JSON and URL-encoded body parsing (50mb limit for image uploads)
 */
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.ip}`);
  next();
});
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

/**
 * Health Check Endpoint
 * @route GET /health
 */
app.get('/health', (req, res) => {
  res.json({ success: true, message: 'Civic App backend is running securely' });
});

/**
 * Route Mounts
 */
// Aadhaar Authentication Routes
const aadhaarRoutes = require('./routes/aadhaar');
app.use('/aadhaar', aadhaarRoutes);

// Complaint Reporting & AI Analysis Routes
const reportRoutes = require('./routes/report');
app.use('/report', reportRoutes);

// AI Chatbot Routes
const chatRoutes = require('./routes/chat');
app.use('/chat', chatRoutes);

// Community Feed & Analytics Routes
const communityRoutes = require('./routes/community');
app.use('/community', communityRoutes);

// Comments & Interactions Routes
const commentsRoutes = require('./routes/comments');
app.use('/comments', commentsRoutes);

// Push Notifications Routes
const notificationRoutes = require('./routes/notifications');
app.use('/notifications', notificationRoutes);

/**
 * Start the Express Server
 */
app.listen(PORT, () => {
  console.log(`Civic App backend listening on port ${PORT}`);
});
