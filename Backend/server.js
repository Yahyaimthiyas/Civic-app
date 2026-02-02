require('dotenv').config();
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4000;

// Initialize Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});

// Expose Firestore instance if needed later
const db = admin.firestore();
app.locals.db = db;

// Middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.ip}`);
  next();
});
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ success: true, message: 'Aadhaar TN backend is running' });
});

// Aadhaar routes (placeholder for now)
const aadhaarRoutes = require('./routes/aadhaar');
app.use('/aadhaar', aadhaarRoutes);

// Report/AI Routes
const reportRoutes = require('./routes/report');
app.use('/report', reportRoutes);

// Start server
app.listen(PORT, () => {
  console.log(`Aadhaar TN backend listening on port ${PORT}`);
});
