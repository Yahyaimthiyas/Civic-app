/**
 * @file aadhaarController.js
 * @description Controller for Aadhaar-related operations (Backend logic ONLY).
 * OTP delivery and verification are now handled fully by Firebase Phone Authentication on the frontend.
 */

/**
 * Validates the Aadhaar number and returns the associated E.164 phone number.
 * The frontend will use this phone number to trigger Firebase Phone Auth.
 */
exports.sendOtp = async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { aadhaarNumber } = req.body;

    if (!db) {
      return res.status(500).json({ success: false, message: 'Firestore is not initialized' });
    }
    if (!aadhaarNumber) {
      return res.status(400).json({ success: false, message: 'aadhaarNumber is required' });
    }

    const cleanAadhaar = String(aadhaarNumber).trim();
    if (!/^\d{12}$/.test(cleanAadhaar)) {
      return res.status(400).json({ success: false, message: 'Invalid Aadhaar format. Must be 12 digits.' });
    }

    const docRef = db.collection('aadhaarRegistry').doc(cleanAadhaar);
    const snapshot = await docRef.get();

    if (!snapshot.exists) {
      return res.status(404).json({ success: false, message: 'Aadhaar number not found in registry.' });
    }

    const user = snapshot.data();

    if (user.state !== 'Tamil Nadu') {
      return res.status(403).json({ success: false, message: 'Only Tamil Nadu residents are allowed.' });
    }
    if (typeof user.age !== 'number' || user.age < 18) {
      return res.status(403).json({ success: false, message: 'You must be 18 or older to register.' });
    }

    const phoneNumber = String(user.mobile || '').trim();
    if (!phoneNumber || phoneNumber.length < 10) {
      return res.status(400).json({ success: false, message: 'Invalid mobile number in Aadhaar record.' });
    }

    // Mask mobile number for display in the app UI
    const maskedMobile = phoneNumber.replace(
      /(\+\d{2})(\d{2})(\d{6})(\d{2})/,
      '$1$2******$4'
    );

    // Return the phone number to the frontend so it can trigger Firebase Phone Auth!
    return res.json({
      success: true,
      message: 'Aadhaar verified. Proceed with Firebase Phone Auth.',
      maskedMobile,
      phoneE164: phoneNumber, // Required by Firebase Phone Auth
    });

  } catch (error) {
    console.error('Check Aadhaar error:', error);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

/**
 * Retrieves the full Aadhaar profile after the frontend successfully completes Firebase Phone Auth.
 * NOTE: For production, this route should require the Firebase JWT token to prove the phone was actually verified.
 */
exports.verifyOtp = async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { aadhaarNumber } = req.body; // No need for 'otp' since Firebase handled it

    if (!db) {
      return res.status(500).json({ success: false, message: 'Firestore is not initialized' });
    }
    if (!aadhaarNumber) {
      return res.status(400).json({ success: false, message: 'aadhaarNumber is required' });
    }

    const cleanAadhaar = String(aadhaarNumber).trim();

    const docRef = db.collection('aadhaarRegistry').doc(cleanAadhaar);
    const snapshot = await docRef.get();

    if (!snapshot.exists) {
      return res.status(404).json({ success: false, message: 'Aadhaar not found.' });
    }

    const user = snapshot.data();

    return res.json({
      success: true,
      message: 'Profile retrieved successfully.',
      user: {
        ...user,
        verifiedAt: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error('Retrieve Profile error:', error);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

exports.testAadhaar = async (req, res) => {
  // Existing test logic
  try {
    const db = req.app.locals.db;
    const { aadhaarNumber } = req.params;

    if (!db) return res.status(500).json({ success: false });
    if (!aadhaarNumber) return res.status(400).json({ success: false });

    const docRef = db.collection('aadhaarRegistry').doc(aadhaarNumber);
    const snapshot = await docRef.get();

    if (!snapshot.exists) return res.status(404).json({ success: false });

    return res.json({ success: true, data: snapshot.data() });
  } catch (error) {
    return res.status(500).json({ success: false });
  }
};
