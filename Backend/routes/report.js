const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const CivicIssueAnalyzer = require('../services/aiAnalyzer');

// Setup multer for temp uploads
const upload = multer({
    dest: 'uploads/',
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

// Initialize Analyzer
// CAUTION: Ensure GOOGLE_API_KEY is set in .env. 
// We will lazy-load or check it here.
const apiKey = process.env.GOOGLE_API_KEY;
let analyzer;
try {
    if (apiKey) {
        analyzer = new CivicIssueAnalyzer(apiKey);
    } else {
        console.warn("GOOGLE_API_KEY not found. AI features will fail.");
    }
} catch (e) {
    console.error("Failed to init analyzer:", e);
}

// Tamil Nadu Districts List
const TN_DISTRICTS = [
    "Ariyalur", "Chengalpattu", "Chennai", "Coimbatore", "Cuddalore", "Dharmapuri",
    "Dindigul", "Erode", "Kallakurichi", "Kancheepuram", "Karur", "Krishnagiri",
    "Madurai", "Mayiladuthurai", "Nagapattinam", "Namakkal", "Nilgiris", "Perambalur",
    "Pudukkottai", "Ramanathapuram", "Ranipet", "Salem", "Sivaganga", "Tenkasi",
    "Thanjavur", "Theni", "Thoothukudi", "Tiruchirappalli", "Tirunelveli", "Tirupathur",
    "Tiruppur", "Tiruvallur", "Tiruvannamalai", "Tiruvarur", "Vellore", "Viluppuram",
    "Virudhunagar"
];

// POST /analyze
router.post('/analyze', upload.single('file'), async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ success: false, message: "No file uploaded" });
    }

    if (!analyzer) {
        // Cleanup
        fs.unlinkSync(req.file.path);
        return res.status(500).json({ success: false, message: "AI Service not configured (Missing API Key)" });
    }

    try {
        const filePath = req.file.path;
        let mimeType = req.file.mimetype; // e.g., image/jpeg

        // Fix for Flutter ImagePicker sending octet-stream
        if (mimeType === 'application/octet-stream') {
            mimeType = 'image/jpeg';
        }

        console.log(`Received file: ${req.file.originalname} (${mimeType})`);

        const result = await analyzer.analyzeImage(filePath, mimeType);

        // Cleanup temp file
        fs.unlinkSync(filePath);

        return res.json({
            success: true,
            ...result
        });

    } catch (error) {
        // Cleanup temp file in case of error
        if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);

        console.error("Analysis route error:", error);
        return res.status(500).json({ success: false, message: "AI Analysis Failed", error: error.message });
    }
});

// GET /classify-district
router.get('/classify-district', (req, res) => {
    const address = req.query.address;
    if (!address) {
        return res.status(400).json({ success: false, message: "Address is required" });
    }

    const addressLower = address.toLowerCase();

    // Quick check if in Tamil Nadu
    if (!addressLower.includes('tamil nadu') && !addressLower.includes('tn') && !addressLower.includes('chennai')) {
        // Being lenient, maybe they didn't write state
        // But let's return "Not in TN" if we are strict. 
        // For now, let's just try to find the district.
    }

    let detectedDistrict = "Tamil Nadu (District Unknown)";

    for (const district of TN_DISTRICTS) {
        if (addressLower.includes(district.toLowerCase())) {
            detectedDistrict = district;
            break;
        }
    }

    return res.json({
        success: true,
        address: address,
        district: detectedDistrict
    });
});

// POST /submit
router.post('/submit', upload.single('file'), async (req, res) => {
    try {
        // req.body fields are strings when using multer
        let { userId, userName, category, description, location, district, status, urgency, department } = req.body;

        // Parse nested JSON strings if they come as strings
        try {
            if (typeof location === 'string') location = JSON.parse(location);
        } catch (e) { }

        if (!userId || !category) {
            return res.status(400).json({ success: false, message: "Missing required fields (userId, category)" });
        }

        let imageUrl = null;
        if (req.file) {
            // In a real app, upload to S3/Firebase Storage here
            // For now, we'll assume the file in 'uploads/' is served statically or just store the filename
            // We need to move it to a 'public' folder or similar if we want to serve it
            // For this MVP, we will just use the filename
            imageUrl = req.file.path.replace(/\\/g, '/'); // Normalize path
        }

        const db = req.app.locals.db;

        const reportData = {
            userId,
            userName: userName || 'Anonymous',
            category,
            description: description || '',
            location: location || { lat: 0, lng: 0, address: '' },
            district: district || 'Unknown',
            department: department || 'Unknown',
            status: status || 'PENDING',
            urgency: urgency || 'MEDIUM',
            imageUrl: imageUrl,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            upvotes: 0
        };

        const docRef = await db.collection('reports').add(reportData);

        return res.json({
            success: true,
            reportId: docRef.id,
            message: "Report submitted successfully"
        });

    } catch (error) {
        console.error("Submit Report Error:", error);
        return res.status(500).json({ success: false, message: "Failed to submit report", error: error.message });
    }
});

// GET /user/:userId - Get reports for a specific user
router.get('/user/:userId', async (req, res) => {
    try {
        const userId = req.params.userId;
        const db = req.app.locals.db;

        const snapshot = await db.collection('reports')
            .where('userId', '==', userId)
            .orderBy('createdAt', 'desc')
            .get();

        if (snapshot.empty) {
            return res.json({ success: true, reports: [] });
        }

        const reports = [];
        snapshot.forEach(doc => {
            reports.push({ id: doc.id, ...doc.data() });
        });

        return res.json({ success: true, reports });

    } catch (error) {
        console.error("Fetch User Reports Error:", error);
        return res.status(500).json({ success: false, message: "Failed to fetch reports", error: error.message });
    }
});

// GET /feed - Get public feed of reports (latest 50)
router.get('/feed', async (req, res) => {
    try {
        const db = req.app.locals.db;

        const snapshot = await db.collection('reports')
            .orderBy('createdAt', 'desc')
            .limit(50)
            .get();

        if (snapshot.empty) {
            return res.json({ success: true, reports: [] });
        }

        const reports = [];
        snapshot.forEach(doc => {
            // Filter out sensitive data if needed, but for now sending full object
            // Maybe dont send userId/Phone/Address to public?
            // Sending minimal info for feed
            const data = doc.data();
            reports.push({
                id: doc.id,
                category: data.category,
                description: data.description,
                location: data.location,
                imageUrl: data.imageUrl,
                status: data.status,
                createdAt: data.createdAt,
                department: data.department,
                urgency: data.urgency,
                upvotes: data.upvotes || 0
            });
        });

        return res.json({ success: true, reports });

    } catch (error) {
        console.error("Fetch Feed Error:", error);
        return res.status(500).json({ success: false, message: "Failed to fetch feed", error: error.message });
    }
});

module.exports = router;
