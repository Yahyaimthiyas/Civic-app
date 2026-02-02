const express = require('express');
const router = express.Router();

// In-memory OTP storage (sufficient for development/testing)
// Keyed by aadhaarNumber
const otpStorage = new Map();

function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// POST /aadhaar/send-otp
router.post('/send-otp', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { aadhaarNumber } = req.body;

    if (!db) {
      return res.status(500).json({
        success: false,
        message: 'Firestore is not initialized on the server',
      });
    }

    if (!aadhaarNumber) {
      return res.status(400).json({
        success: false,
        message: 'aadhaarNumber is required',
      });
    }

    const cleanAadhaar = String(aadhaarNumber).trim();

    // Basic Aadhaar format validation
    if (!/^\d{12}$/.test(cleanAadhaar)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid Aadhaar format. Must be 12 digits.',
      });
    }

    // Look up Aadhaar record in Firestore
    const docRef = db.collection('aadhaarRegistry').doc(cleanAadhaar);
    const snapshot = await docRef.get();

    if (!snapshot.exists) {
      return res.status(404).json({
        success: false,
        message: 'Aadhaar number not found in registry.',
      });
    }

    const user = snapshot.data();

    // Enforce Tamil Nadu residency
    if (user.state !== 'Tamil Nadu') {
      return res.status(403).json({
        success: false,
        message: 'Only Tamil Nadu residents are allowed.',
      });
    }

    // Enforce age >= 18
    if (typeof user.age !== 'number' || user.age < 18) {
      return res.status(403).json({
        success: false,
        message: 'You must be 18 or older to register.',
      });
    }

    const phoneNumber = String(user.mobile || '').trim();
    if (!phoneNumber || phoneNumber.length < 10) {
      return res.status(400).json({
        success: false,
        message: 'Invalid mobile number in Aadhaar record.',
      });
    }

    // Generate OTP and store it in memory with expiry (5 minutes)
    const otp = generateOTP();
    const otpData = {
      otp,
      aadhaarNumber: cleanAadhaar,
      phoneNumber,
      createdAt: Date.now(),
      expiresAt: Date.now() + 5 * 60 * 1000,
      attempts: 0,
    };

    otpStorage.set(cleanAadhaar, otpData);

    // Development mode: log OTP to server console instead of sending SMS
    console.log('============================');
    console.log('DEV OTP GENERATED');
    console.log('Aadhaar:', cleanAadhaar);
    console.log('Mobile:', phoneNumber);
    console.log('OTP:', otp);
    console.log('============================');

    // Mask mobile number for response
    const maskedMobile = phoneNumber.replace(
      /(\+\d{2})(\d{2})(\d{6})(\d{2})/,
      '$1$2******$4'
    );

    return res.json({
      success: true,
      message:
        'OTP generated in development mode. Check backend console for the actual OTP.',
      maskedMobile,
      phoneE164: phoneNumber,
    });
  } catch (error) {
    console.error('Send OTP error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
});

// POST /aadhaar/verify-otp
router.post('/verify-otp', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { aadhaarNumber, otp } = req.body;

    if (!db) {
      return res.status(500).json({
        success: false,
        message: 'Firestore is not initialized on the server',
      });
    }

    if (!aadhaarNumber || !otp) {
      return res.status(400).json({
        success: false,
        message: 'aadhaarNumber and otp are required',
      });
    }

    const cleanAadhaar = String(aadhaarNumber).trim();
    const otpString = String(otp).trim();

    const storedOtpData = otpStorage.get(cleanAadhaar);

    if (!storedOtpData) {
      return res.status(400).json({
        success: false,
        message:
          'No OTP found for this Aadhaar number. Please request a new OTP.',
      });
    }

    // Check expiry
    if (Date.now() > storedOtpData.expiresAt) {
      otpStorage.delete(cleanAadhaar);
      return res.status(400).json({
        success: false,
        message: 'OTP has expired. Please request a new OTP.',
      });
    }

    // Check attempts limit
    if (storedOtpData.attempts >= 3) {
      otpStorage.delete(cleanAadhaar);
      return res.status(400).json({
        success: false,
        message:
          'Too many failed attempts. Please request a new OTP.',
      });
    }

    // Verify OTP
    if (storedOtpData.otp !== otpString) {
      storedOtpData.attempts += 1;
      otpStorage.set(cleanAadhaar, storedOtpData);
      return res.status(400).json({
        success: false,
        message: `Invalid OTP. ${3 - storedOtpData.attempts} attempts remaining.`,
      });
    }

    // OTP is correct - fetch user details from Firestore
    const docRef = db.collection('aadhaarRegistry').doc(cleanAadhaar);
    const snapshot = await docRef.get();

    otpStorage.delete(cleanAadhaar);

    if (!snapshot.exists) {
      return res.status(404).json({
        success: false,
        message: 'Aadhaar number not found in registry after verification.',
      });
    }

    const user = snapshot.data();

    return res.json({
      success: true,
      message: 'OTP verified successfully.',
      user: {
        aadhaarNumber: cleanAadhaar,
        fullName: user.fullName,
        district: user.district,
        state: user.state,
        phoneNumber: storedOtpData.phoneNumber,
        verifiedAt: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error('Verify OTP error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
});

// GET /aadhaar/test/:aadhaarNumber
// Simple test endpoint to verify Firestore connectivity and data
router.get('/test/:aadhaarNumber', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { aadhaarNumber } = req.params;

    if (!db) {
      return res.status(500).json({
        success: false,
        message: 'Firestore is not initialized on the server',
      });
    }

    if (!aadhaarNumber) {
      return res.status(400).json({
        success: false,
        message: 'aadhaarNumber is required',
      });
    }

    const docRef = db.collection('aadhaarRegistry').doc(aadhaarNumber);
    const snapshot = await docRef.get();

    if (!snapshot.exists) {
      return res.status(404).json({
        success: false,
        message: 'Aadhaar not found in registry',
      });
    }

    return res.json({
      success: true,
      data: snapshot.data(),
    });
  } catch (error) {
    console.error('Test Aadhaar fetch error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
});

module.exports = router;
