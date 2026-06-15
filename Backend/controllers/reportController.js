const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const CivicIssueAnalyzer = require('../services/aiAnalyzer');
const {
    generateTrackingId,
    getNextSequenceNumber,
    severityToPriority,
    normalizeDistrictName,
    extractDistrictFromAddress,
    initializeTimeline
} = require('../utils/reportHelpers');

const { createNotification } = require('../utils/notificationHelper');

const FEED_CACHE_TTL_MS = 5000; // 5 seconds - reduced for live data visibility
const feedCache = {};

function getFeedCacheKey(query) {
    const { district = '', status = '', category = '', severity = '', dateRange = '' } = query || {};
    return [district, status, category, severity, dateRange].join('|');
}

function parseCreatedAt(value) {
    if (!value) return 0;
    if (value._seconds) {
        return value._seconds * 1000;
    }
    return new Date(value).getTime();
}

// Setup multer for temp uploads
const upload = multer({
    dest: 'uploads/',
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

// Initialize Analyzer
// CAUTION: Ensure GEMINI_API_KEY is set in .env.
// If not, AI categorization will simply result in "General" without crashing.
const apiKey = process.env.GEMINI_API_KEY;

let analyzer = null;
if (apiKey) {
    try {
        analyzer = new CivicIssueAnalyzer(apiKey);
        console.log("✅ AI Analyzer initialized successfully with gemini-flash-latest");
    } catch (error) {
        console.error("❌ Failed to initialize AI Analyzer:", error.message);
    }
} else {
    console.warn("⚠️  GEMINI_API_KEY not found. AI features will be disabled.");
}

// Tamil Nadu Districts List
const TN_DISTRICTS = [
    "Ariyalur", "Chengalpattu", "Chennai", "Coimbatore", "Cuddalore", "Dharmapuri",
    "Dindigul", "Erode", "Kallakurichi", "Kancheepuram", "Karur", "Krishnagiri",
    "Madurai", "Mayiladuthurai", "Nagapattinam", "Namakkal", "Nilgiris", "Perambalur",
    "Pudukkottai", "Ramanathapuram", "Ranipet", "Salem", "Sivaganga", "Tenkasi",
    "Thanjavur", "Theni", "Thoothukudi", "Tiruchirappalli", "Tirunelveli", "Tirupathur",
    "Tiruppur", "Tiruvallur", "Tiruvannamalai", "Tiruvarur", "Vellore", "Viluppuram",
    "Tiruvarur", "Vellore", "Viluppuram", "Virudhunagar", "Kanyakumari"
];

// POST /analyze
exports.analyze = async (req, res) => {
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
};

// GET /classify-district
exports.classifyDistrict = (req, res) => {
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
};

// POST /submit - Submit a new report (PRODUCTION-READY)
exports.submitReport = async (req, res) => {
    try {
        const {
            generateTrackingId,
            generateGeoHash,
            severityToPriority,
            getNextSequenceNumber
        } = require('../utils/reportHelpers');

        // Load mapping once during route execution
        let CATEGORY_TO_DEPARTMENT = {};
        try {
            const mappingPath = path.join(__dirname, '../mapping.json');
            const mappingData = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));
            Object.keys(mappingData).forEach(cat => {
                CATEGORY_TO_DEPARTMENT[cat] = mappingData[cat].department;
            });
        } catch (e) {
            console.error("Error loading mapping.json in report.js:", e);
        }

        // Parse request body
        let {
            userId,
            userName,
            userEmail,
            category,
            subCategory,
            title,
            description,
            location,
            district,
            pincode,
            landmark,
            severity,
            department,
            tags,
            isAnonymous,
            metadata
        } = req.body;

        // Normalization & Fallback
        district = normalizeDistrictName(district);

        // If district is still "Tamil Nadu" (default/fallback), try extracting from address
        if (district === 'Tamil Nadu' && location && location.address) {
            const extracted = extractDistrictFromAddress(location.address);
            if (extracted) {
                console.log(`📍 Extracted specific district '${extracted}' from address.`);
                district = extracted;
            }
        }

        // Force category to lowercase/slug format
        if (category) category = category.toLowerCase().replace(/ /g, '_');

        // Parse nested JSON strings
        try {
            if (typeof location === 'string') location = JSON.parse(location);
            if (typeof tags === 'string') tags = JSON.parse(tags);
            if (typeof metadata === 'string') metadata = JSON.parse(metadata);
        } catch (e) {
            console.error('JSON parse error:', e);
        }

        // Validation
        if (!userId || !category || !description) {
            return res.status(400).json({
                success: false,
                message: 'Missing required fields (userId, category, description)'
            });
        }

        if (!location || !location.latitude || !location.longitude) {
            return res.status(400).json({
                success: false,
                message: 'Valid location (latitude, longitude) is required'
            });
        }

        const db = req.app.locals.db;

        // Generate tracking ID
        const currentYear = new Date().getFullYear();
        const sequenceNumber = await getNextSequenceNumber(db, district || 'TN', currentYear);
        const trackingId = generateTrackingId(district || 'Tamil Nadu', sequenceNumber);

        // Handle image upload (Base64 Priority)
        let imageUrl = null;
        let imageMetadata = null;

        if (req.body.image) {
            // User sent Base64 string
            imageUrl = req.body.image;

            // Basic metadata estimation for Base64
            const sizeInBytes = 4 * Math.ceil((imageUrl.length / 3)) * 0.5624896334383429;
            imageMetadata = {
                url: "Base64 Image",
                size: Math.round(sizeInBytes),
                format: imageUrl.substring(imageUrl.indexOf('/') + 1, imageUrl.indexOf(';')),
                uploadedAt: new Date().toISOString()
            };
        } else if (req.file) {
            // Legacy: File upload (Convert to Base64 if needed, but user asked to store Base64)
            // For now, let's read the file and convert to Base64 to strictly follow "store base64"
            const fileBuffer = require('fs').readFileSync(req.file.path);
            const base64Image = 'data:' + req.file.mimetype + ';base64,' + fileBuffer.toString('base64');
            require('fs').unlinkSync(req.file.path); // Cleanup temp file containing original

            imageUrl = base64Image;
            imageMetadata = {
                url: "Base64 Image",
                size: req.file.size,
                format: req.file.mimetype.split('/')[1],
                uploadedAt: new Date().toISOString()
            };
        }


        // 🤖 PROACTIVE AI ANALYSIS & AUTO-RESOLUTION
        let aiResult = null;
        if (imageUrl) {
            try {
                console.log("🚀 Starting AI Analysis for report...");
                const mimeType = imageMetadata ? `image/${imageMetadata.format}` : 'image/jpeg';
                aiResult = await analyzer.analyzeImage(imageUrl, mimeType);
                console.log("✅ AI Analysis Complete:", aiResult ? `Success (${aiResult.issue_type})` : "No Result");

                // 🏗️ Robust Category Resolution
                if (aiResult && aiResult.confidence > 0.7) {
                    const aiType = aiResult.issue_type;

                    // Priority 1: User sent "others" or generic, but AI is certain
                    const isGeneric = !category || ['others', 'unknown', 'general', 'garbage', 'pothole', 'streetlight'].includes(category);

                    if (isGeneric) {
                        // Priority 2: Try to find the exact mapping key
                        const mappingKeys = Object.keys(CATEGORY_TO_DEPARTMENT);
                        const bestMatch = mappingKeys.find(k => k === aiType || aiType.includes(k) || k.includes(aiType));

                        if (bestMatch) {
                            console.log(`✨ AI Auto-Resolved Generic '${category}' to '${bestMatch}'`);
                            category = bestMatch;
                        }
                    }
                }
            } catch (aiError) {
                console.error("⚠️ AI Analysis Failed (Continuing submission):", aiError.message);
            }
        }


        const admin = require('firebase-admin');

        // Determine priority from severity if not directly provided
        const numericPriority = Number(req.body.priority) || severityToPriority(severity);

        // 🏗️ Build CITIZEN-SIDE report structure (100% Match with 'Pothole' Baseline)
        const reportData = {
            category: category || 'others',
            communityVerification: {
                isVerified: false,
                verificationCount: 0,
                verifiedBy: []
            },
            createdAt: admin.firestore.Timestamp.now(),
            department: CATEGORY_TO_DEPARTMENT[category] || department || 'Roads',
            description: description || '',
            district: district || 'Tamil Nadu',

            // 📸 Images (Strict Baseline Structure)
            images: imageUrl ? [{
                id: `img_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                base64: imageUrl,
                height: 1080,
                isMain: true,
                mimeType: imageMetadata ? `image/${imageMetadata.format}` : 'image/jpeg',
                size: imageMetadata ? Number(imageMetadata.size) : 0,
                uploadedAt: admin.firestore.Timestamp.now(),
                width: 1920
            }] : [],

            // 📍 Location
            location: {
                latitude: parseFloat(location.latitude),
                longitude: parseFloat(location.longitude),
                address: location.address || ''
            },

            metadata: {
                submittedFrom: "mobile_app",
                version: "1.0.0",
                priority: numericPriority,
                severity: (severity || 'high').toLowerCase(),
                status: 'pending'
            },

            tags: tags || [category],
            trackingId,
            updatedAt: admin.firestore.Timestamp.now(),
            upvoteCount: 0,
            upvotes: [],
            userEmail: userEmail || "",
            userId: userId
        };

        // Save to Firestore
        const docRef = await db.collection('reports').add(reportData);

        console.log(`✅ Report created: ${trackingId} (${docRef.id})`);

        // Notify user of submission
        await createNotification(
            db,
            userId,
            'UPDATE',
            'Report Submitted',
            `Your report ${trackingId} for ${category.replace(/_/g, ' ')} has been received and is pending verification.`,
            docRef.id
        );

        return res.json({
            success: true,
            reportId: docRef.id,
            trackingId,
            message: 'Report submitted successfully'
        });

    } catch (error) {
        console.error('Submit Report Error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to submit report',
            error: error.message
        });
    }
};

// GET /user/:userId - Get reports for a specific user
exports.getUserReports = async (req, res) => {
    try {
        const userId = req.params.userId;
        const db = req.app.locals.db;

        const snapshot = await db.collection('reports')
            .where('userId', '==', userId)
            .get();

        if (snapshot.empty) {
            return res.json({ success: true, reports: [] });
        }

        const reports = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            // SPEED OPTIMIZATION: Exclude heavy Base64 images from user list view
            if (data.images && data.images.length > 0) {
                // Keep the first (main) image's base64 for preview, strip others
                data.images = data.images.map((img, idx) => {
                    if (idx === 0) return img; // Keep primary Base64
                    const { base64, ...lightImg } = img;
                    return lightImg;
                });
            }
            reports.push({ id: doc.id, ...data });
        });

        reports.sort((a, b) => parseCreatedAt(b.createdAt) - parseCreatedAt(a.createdAt));

        return res.json({ success: true, reports });

    } catch (error) {
        console.error("Fetch User Reports Error:", error);
        return res.status(500).json({ success: false, message: "Failed to fetch reports", error: error.message });
    }
};

// GET /stats/:district
exports.getStats = async (req, res) => {
    try {
        const district = req.params.district;
        const db = req.app.locals.db;

        const snapshot = await db.collection('reports').where('district', '==', district).get();

        let total = 0;
        let resolved = 0;
        let pending = 0;
        let inProgress = 0;
        let verified = 0;
        let rejected = 0;

        snapshot.forEach(doc => {
            total++;
            const status = (doc.data().status || 'PENDING').toUpperCase();
            if (status === 'RESOLVED') resolved++;
            else if (status === 'IN_PROGRESS') inProgress++;
            else if (status === 'VERIFIED') verified++;
            else if (status === 'REJECTED') rejected++;
            else pending++;
        });

        return res.json({
            success: true,
            total,
            resolved,
            pending,
            inProgress,
            verified,
            rejected,
            district
        });
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.getFeed = async (req, res) => {
    try {
        const { district, status, category, severity, dateRange, limit = 20, lastId } = req.query;
        const db = req.app.locals.db;

        const numericLimit = Math.min(parseInt(limit) || 20, 50); // Cap at 50 per page for performance

        const cacheKey = getFeedCacheKey(req.query);
        const now = Date.now();
        const cached = feedCache[cacheKey];
        if (cached && (now - cached.timestamp) < FEED_CACHE_TTL_MS) {
            return res.json(cached.payload);
        }

        let query = db.collection('reports');

        if (district && district !== 'All Districts') {
            const normalizedDist = normalizeDistrictName(district);
            query = query.where('district', '==', normalizedDist);
        }

        if (status && status !== 'All Reports') {
            query = query.where('status', '==', status.toUpperCase().replace(/\s/g, '_'));
        }

        if (category && category !== 'All' && category !== 'all') {
            query = query.where('category', '==', category);
        }

        if (severity && severity !== 'All' && severity !== 'all') {
            query = query.where('severity', '==', severity.toLowerCase());
        }

        if (dateRange && dateRange !== 'All' && dateRange !== 'all') {
            const now = new Date();
            let startDate = new Date();

            if (dateRange === 'today') {
                startDate.setHours(0, 0, 0, 0);
            } else if (dateRange === 'week') {
                startDate.setDate(now.getDate() - 7);
            } else if (dateRange === 'month') {
                startDate.setMonth(now.getMonth() - 1);
            }

            // Note: Firestore requires a composite index for inequalities on different fields.
            // For simplicity in this iteration without complex indexing, we might filter dates in memory 
            // if the dataset is small, or assume the client accepts strict ordering.
            // Ideally: query = query.where('createdAt', '>=', startDate);
        }

        if (lastId) {
            const lastDoc = await db.collection('reports').doc(lastId).get();
            if (lastDoc.exists) {
                query = query.startAfter(lastDoc);
            }
        }

        const snapshot = await query.limit(numericLimit).get();

        if (snapshot.empty) {
            const emptyPayload = { success: true, reports: [] };
            feedCache[cacheKey] = { timestamp: Date.now(), payload: emptyPayload };
            return res.json(emptyPayload);
        }

        let reports = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            // SPEED OPTIMIZATION: Stripping heavy Base64 strings for feed listing
            if (data.images && data.images.length > 0) {
                // Preserving ONLY the first image's Base64 for the feed preview.
                // This keeps the feed relatively lightweight while ensuring images load.
                data.images = data.images.map((img, idx) => {
                    if (idx === 0) return img; // Keep main image intact
                    const { base64, ...metaOnly } = img;
                    return metaOnly;
                });
            }
            reports.push({ id: doc.id, ...data });
        });

        // Sort by createdAt descending in Node and cap to 50 for map density
        // Reduced from 100 to improve rendering performance on mobile
        reports.sort((a, b) => parseCreatedAt(b.createdAt) - parseCreatedAt(a.createdAt));
        reports = reports.slice(0, 50);

        // In-memory date filtering to avoid complex composite index requirement immediately
        if (dateRange && dateRange !== 'All' && dateRange !== 'all') {
            const now = new Date();
            let startDate = new Date();
            if (dateRange === 'today') startDate.setHours(0, 0, 0, 0);
            else if (dateRange === 'week') startDate.setDate(now.getDate() - 7);
            else if (dateRange === 'month') startDate.setMonth(now.getMonth() - 1);

            reports = reports.filter(r => {
                const created = new Date(r.createdAt._seconds ? r.createdAt._seconds * 1000 : r.createdAt);
                return created >= startDate;
            });
        }

        const payload = { success: true, reports };
        feedCache[cacheKey] = { timestamp: Date.now(), payload };
        return res.json(payload);

    } catch (error) {
        console.error("Fetch Feed Error:", error);
        return res.status(500).json({ success: false, message: "Failed to fetch feed", error: error.message });
    }
};

// POST /upvote/:reportId
exports.upvoteReport = async (req, res) => {
    try {
        const reportId = req.params.reportId;
        const db = req.app.locals.db;
        const reportRef = db.collection('reports').doc(reportId);

        await db.runTransaction(async (t) => {
            const doc = await t.get(reportRef);
            if (!doc.exists) throw new Error("Report does not exist");
            const data = doc.data();
            const newUpvotes = (data.upvotes || 0) + 1;

            t.update(reportRef, {
                upvotes: newUpvotes,
                'engagement.upvotes': (data.engagement?.upvotes || 0) + 1,
                updatedAt: new Date().toISOString()
            });
        });

        // SOCIAL NOTIFICATION: Notify owner of upvote
        try {
            const upvoterId = req.body.userId;
            const upvoterPhoto = req.body.userPhoto; // Expect photo from frontend
            const doc = await reportRef.get();
            const data = doc.data();

            // Only notify if someone else upvoted
            if (upvoterId && data.userId !== upvoterId) {
                await createNotification(
                    db,
                    data.userId,
                    'AWARD',
                    'New Upvote!',
                    `Someone upvoted your report ${data.trackingId}. Your community impact is growing!`,
                    reportId,
                    upvoterPhoto
                );
            }
        } catch (notifErr) {
            console.error("Upvote notification error:", notifErr);
        }

        return res.json({ success: true, message: "Upvoted successfully" });
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};

// POST /verify/:reportId - Community verification endpoint
exports.verifyReport = async (req, res) => {
    try {
        const { reportId } = req.params;
        const { userId, userEmail } = req.body;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        const db = req.app.locals.db;
        const reportRef = db.collection('reports').doc(reportId);
        const reportDoc = await reportRef.get();

        if (!reportDoc.exists) {
            return res.status(404).json({ success: false, message: 'Report not found' });
        }

        const reportData = reportDoc.data();
        const verification = reportData.communityVerification || {
            isVerified: false,
            verificationCount: 0,
            verifiedBy: [],
            verificationThreshold: 3
        };

        // Check if user already verified
        if (verification.verifiedBy.includes(userId)) {
            return res.status(400).json({ success: false, message: 'You have already verified this report' });
        }

        // Add verification
        verification.verifiedBy.push(userId);
        verification.verificationCount = verification.verifiedBy.length;
        verification.lastVerifiedAt = new Date().toISOString();

        // Check if threshold reached
        if (verification.verificationCount >= verification.verificationThreshold) {
            verification.isVerified = true;
        }

        const history = reportData.history || [];
        const updateData = {
            communityVerification: verification,
            updatedAt: new Date().toISOString()
        };

        if (verification.isVerified && reportData.status === 'PENDING') {
            // Auto-update status to verified
            const { createHistoryEntry } = require('../utils/reportHelpers');
            history.push(createHistoryEntry(
                'VERIFIED',
                'system',
                'system',
                'auto_verified',
                `Report verified by community (${verification.verificationCount} verifications)`
            ));

            updateData.status = 'VERIFIED';
            updateData.subStatus = 'awaiting_assignment';
            updateData['timeline.verifiedAt'] = new Date().toISOString();
            updateData.history = history;
        }

        await reportRef.update(updateData);

        return res.json({
            success: true,
            verificationCount: verification.verificationCount,
            isVerified: verification.isVerified,
            message: verification.isVerified
                ? 'Report verified by community!'
                : `Verification recorded (${verification.verificationCount}/${verification.verificationThreshold})`
        });

    } catch (error) {
        console.error('Verification Error:', error);
        return res.status(500).json({ success: false, message: 'Failed to verify report', error: error.message });
    }
};

// GET /comments/:reportId
exports.getComments = async (req, res) => {
    try {
        const reportId = req.params.reportId;
        const db = req.app.locals.db;
        const snapshot = await db.collection('reports').doc(reportId).collection('comments')
            .orderBy('createdAt', 'desc').get();

        const comments = [];
        snapshot.forEach(doc => comments.push({ id: doc.id, ...doc.data() }));
        return res.json({ success: true, comments });
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};

// POST /comment/:reportId
exports.addComment = async (req, res) => {
    try {
        const reportId = req.params.reportId;
        const { userId, userName, text, userPhoto } = req.body;
        const db = req.app.locals.db;

        if (!text) return res.status(400).json({ success: false, message: "Comment text required" });

        const commentData = {
            userId,
            userName: userName || 'Anonymous',
            userPhoto: userPhoto || '',
            text,
            createdAt: new Date().toISOString()
        };

        await db.collection('reports').doc(reportId).collection('comments').add(commentData);

        // SOCIAL NOTIFICATION: Notify owner of new comment
        try {
            const reportRef = db.collection('reports').doc(reportId);
            const doc = await reportRef.get();
            const data = doc.data();

            // Only notify if someone else commented
            if (userId && data.userId !== userId) {
                await createNotification(
                    db,
                    data.userId,
                    'UPDATE',
                    'New Comment',
                    `${userName || 'Someone'} commented on your report ${data.trackingId}: "${text.length > 30 ? text.substring(0, 30) + '...' : text}"`,
                    reportId,
                    userPhoto
                );
            }
        } catch (notifErr) {
            console.error("Comment notification error:", notifErr);
        }

        return res.json({ success: true, message: "Comment added" });
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};

// GET /details/:reportId - Fetch FULL report including high-res Base64 images
exports.getDetails = async (req, res) => {
    try {
        const reportId = req.params.reportId;
        const db = req.app.locals.db;
        const doc = await db.collection('reports').doc(reportId).get();

        if (!doc.exists) {
            return res.status(404).json({ success: false, message: "Report not found" });
        }

        return res.json({ success: true, report: { id: doc.id, ...doc.data() } });
    } catch (error) {
        console.error("Fetch Details Error:", error);
        return res.status(500).json({ success: false, message: "Failed to fetch details", error: error.message });
    }
};

/**
 * SIMULATION ROUTES FOR TESTING NOTIFICATION PHASES
 * Realistically, these would be called by the admin/worker apps.
 */

// POST /simulate-assign/:reportId
exports.simulateAssign = async (req, res) => {
    try {
        const { reportId } = req.params;
        const db = req.app.locals.db;
        const reportRef = db.collection('reports').doc(reportId);
        const doc = await reportRef.get();
        if (!doc.exists) return res.status(404).json({ success: false, message: "Not found" });

        const data = doc.data();
        const { initializeAssignment, createHistoryEntry } = require('../utils/reportHelpers');

        const assignment = initializeAssignment(data.department || 'Sanitation');
        const history = data.history || [];
        history.push(createHistoryEntry('IN_PROGRESS', assignment.workerId, 'official', 'assigned', `Assigned to ${assignment.workerName}`));

        await reportRef.update({
            status: 'IN_PROGRESS',
            assignment,
            history,
            updatedAt: new Date().toISOString(),
            'timeline.inProgressAt': new Date().toISOString()
        });

        return res.json({ success: true, message: "Simulated assignment complete" });
    } catch (e) {
        return res.status(500).json({ success: false, message: e.message });
    }
};

// POST /simulate-resolve/:reportId
exports.simulateResolve = async (req, res) => {
    try {
        const { reportId } = req.params;
        const db = req.app.locals.db;
        const reportRef = db.collection('reports').doc(reportId);
        const doc = await reportRef.get();
        if (!doc.exists) return res.status(404).json({ success: false, message: "Not found" });

        const data = doc.data();
        const { createHistoryEntry } = require('../utils/reportHelpers');

        const history = data.history || [];
        history.push(createHistoryEntry('RESOLVED', 'dept_admin', 'official', 'resolved', 'Issue fixed and verified by department.'));

        await reportRef.update({
            status: 'RESOLVED',
            history,
            updatedAt: new Date().toISOString(),
            'timeline.resolvedAt': new Date().toISOString()
        });

        return res.json({ success: true, message: "Simulated resolution complete" });
    } catch (e) {
        return res.status(500).json({ success: false, message: e.message });
    }
};


