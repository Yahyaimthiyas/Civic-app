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

const app = express();
const PORT = process.env.PORT || 4000;

// Initialize Firebase Admin SDK using the local service account key.
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
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
