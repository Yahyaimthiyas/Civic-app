const express = require('express');
const router = express.Router();
const aadhaarController = require('../controllers/aadhaarController');

/**
 * @route POST /aadhaar/send-otp
 * @description Generates and sends a 6-digit OTP.
 */
router.post('/send-otp', aadhaarController.sendOtp);

/**
 * @route POST /aadhaar/verify-otp
 * @description Verifies the OTP sent to the user's phone number.
 */
router.post('/verify-otp', aadhaarController.verifyOtp);

/**
 * @route GET /aadhaar/test/:aadhaarNumber
 * @description Simple test endpoint to verify Firestore connectivity.
 */
router.get('/test/:aadhaarNumber', aadhaarController.testAadhaar);

module.exports = router;
