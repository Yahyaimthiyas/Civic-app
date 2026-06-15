const crypto = require('crypto');

/**
 * Helper utilities for report management
 */

/**
 * Generate a human-readable tracking ID
 * Format: TN-{DISTRICT_CODE}-{YEAR}-{SEQUENCE}
 * Example: TN-CHN-2026-00123
 */
function generateTrackingId(district, sequenceNumber) {
    // All 38 Tamil Nadu districts with official codes
    const districtCodes = {
        'Ariyalur': 'ARL',
        'Chengalpattu': 'CGP',
        'Chennai': 'CHN',
        'Coimbatore': 'CBE',
        'Cuddalore': 'CDL',
        'Dharmapuri': 'DHP',
        'Dindigul': 'DGL',
        'Erode': 'ERD',
        'Kallakurichi': 'KLK',
        'Kancheepuram': 'KCP',
        'Karur': 'KRR',
        'Krishnagiri': 'KGI',
        'Madurai': 'MDU',
        'Mayiladuthurai': 'MYL',
        'Nagapattinam': 'NGP',
        'Namakkal': 'NMK',
        'Nilgiris': 'NLG',
        'Perambalur': 'PRM',
        'Pudukkottai': 'PDK',
        'Ramanathapuram': 'RMD',
        'Ranipet': 'RNP',
        'Salem': 'SLM',
        'Sivaganga': 'SVG',
        'Tenkasi': 'TNK',
        'Thanjavur': 'TJV',
        'Theni': 'THN',
        'Thoothukudi': 'TUT',
        'Tiruchirappalli': 'TPJ',
        'Tirunelveli': 'TVL',
        'Tirupathur': 'TPT',
        'Tiruppur': 'TPR',
        'Tiruvallur': 'TVR',
        'Tiruvannamalai': 'TVM',
        'Tiruvarur': 'TVU',
        'Vellore': 'VLR',
        'Viluppuram': 'VLP',
        'Virudhunagar': 'VDN',
        'Kanyakumari': 'KKM'
    };

    const districtCode = districtCodes[district] || district.substring(0, 3).toUpperCase();
    const year = new Date().getFullYear();
    const sequence = String(sequenceNumber).padStart(5, '0');

    return `TN-${districtCode}-${year}-${sequence}`;
}

/**
 * Normalizes district names from various sources (geocoding, user input)
 * to match the standard list.
 * Example: "Erode District" -> "Erode"
 */
function normalizeDistrictName(name) {
    if (!name) return 'Tamil Nadu';

    // 1. Basic cleaning
    let clean = name.trim();

    // 2. Remove " District" suffix if present
    clean = clean.replace(/\s+District$/i, '');

    // 3. Title Case (first letter of each word upper, rest lower)
    clean = clean.split(' ').map(word => {
        if (!word) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    // 4. Manual mapping for common geocoding variations or aliases
    const aliases = {
        'Tuticorin': 'Thoothukudi',
        'Tanjore': 'Thanjavur',
        'Trichy': 'Tiruchirappalli',
        'Tiruchirapalli': 'Tiruchirappalli',
        'Coonoor': 'Nilgiris',
        'Ooty': 'Nilgiris',
        'Arcot': 'Ranipet'
    };

    if (aliases[clean]) return aliases[clean];

    // 5. Check against master list (as a safety check)
    const masterDistricts = [
        "Ariyalur", "Chengalpattu", "Chennai", "Coimbatore", "Cuddalore", "Dharmapuri",
        "Dindigul", "Erode", "Kallakurichi", "Kancheepuram", "Karur", "Krishnagiri",
        "Madurai", "Mayiladuthurai", "Nagapattinam", "Namakkal", "Nilgiris", "Perambalur",
        "Pudukkottai", "Ramanathapuram", "Ranipet", "Salem", "Sivaganga", "Tenkasi",
        "Thanjavur", "Theni", "Thoothukudi", "Tiruchirappalli", "Tirunelveli", "Tirupathur",
        "Tiruppur", "Tiruvallur", "Tiruvannamalai", "Tiruvarur", "Vellore", "Viluppuram",
        "Virudhunagar", "Kanyakumari"
    ];

    const match = masterDistricts.find(d => d.toLowerCase() === clean.toLowerCase());
    return match || clean;
}

/**
 * Attempts to extract a district name from a full address string.
 * Used as a fallback when geocoding returns a generic "Tamil Nadu" district.
 */
function extractDistrictFromAddress(address) {
    if (!address) return null;

    const masterDistricts = [
        "Ariyalur", "Chengalpattu", "Chennai", "Coimbatore", "Cuddalore", "Dharmapuri",
        "Dindigul", "Erode", "Kallakurichi", "Kancheepuram", "Karur", "Krishnagiri",
        "Madurai", "Mayiladuthurai", "Nagapattinam", "Namakkal", "Nilgiris", "Perambalur",
        "Pudukkottai", "Ramanathapuram", "Ranipet", "Salem", "Sivaganga", "Tenkasi",
        "Thanjavur", "Theni", "Thoothukudi", "Tiruchirappalli", "Tirunelveli", "Tirupathur",
        "Tiruppur", "Tiruvallur", "Tiruvannamalai", "Tiruvarur", "Vellore", "Viluppuram",
        "Virudhunagar", "Kanyakumari"
    ];

    // Try to find any master district name in the address string
    // Case-insensitive match with boundary checks
    for (const district of masterDistricts) {
        const regex = new RegExp(`\\b${district}\\b`, 'i');
        if (regex.test(address)) {
            return district;
        }
    }

    return null;
}

/**
 * Calculate impact score based on multiple factors
 * Returns a score from 0-100
 */
function calculateImpactScore(priority, severity, upvotes, verificationCount, category) {
    let score = 0;

    // Priority weight (40 points)
    const priorityScores = { 1: 40, 2: 30, 3: 20, 4: 10 };
    score += priorityScores[priority] || 10;

    // Severity weight (30 points)
    const severityScores = { 'critical': 30, 'high': 22, 'medium': 15, 'low': 8 };
    score += severityScores[severity] || 8;

    // Community engagement (20 points)
    score += Math.min(upvotes * 2, 10); // Max 10 points from upvotes
    score += Math.min(verificationCount * 2, 10); // Max 10 points from verifications

    // Category urgency (10 points)
    const urgentCategories = ['water_leakage', 'streetlight_not_working', 'broken_pole', 'no_water_supply', 'broken_pipeline'];
    if (urgentCategories.includes(category)) {
        score += 10;
    }

    return Math.min(Math.round(score), 100);
}

/**
 * Calculate SLA deadline based on priority and category
 * Returns ISO timestamp
 */
function calculateSLA(priority, category, createdAt = new Date()) {
    const slaHours = {
        1: 24,      // Critical: 24 hours
        2: 72,      // High: 3 days
        3: 168,     // Medium: 7 days
        4: 336      // Low: 14 days
    };

    const hours = slaHours[priority] || 168;
    const deadline = new Date(createdAt);
    deadline.setHours(deadline.getHours() + hours);

    return deadline.toISOString();
}

/**
 * Generate geohash for location-based queries
 * Simplified version - for production, use geohash library
 */
function generateGeoHash(latitude, longitude, precision = 6) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    let latRange = [-90, 90];
    let lonRange = [-180, 180];
    let hash = '';
    let isEven = true;
    let bit = 0;
    let ch = 0;

    while (hash.length < precision) {
        if (isEven) {
            const mid = (lonRange[0] + lonRange[1]) / 2;
            if (longitude > mid) {
                ch |= (1 << (4 - bit));
                lonRange[0] = mid;
            } else {
                lonRange[1] = mid;
            }
        } else {
            const mid = (latRange[0] + latRange[1]) / 2;
            if (latitude > mid) {
                ch |= (1 << (4 - bit));
                latRange[0] = mid;
            } else {
                latRange[1] = mid;
            }
        }

        isEven = !isEven;

        if (bit < 4) {
            bit++;
        } else {
            hash += base32[ch];
            bit = 0;
            ch = 0;
        }
    }

    return hash;
}

/**
 * Map severity string to priority number
 */
function severityToPriority(severity) {
    const mapping = {
        'critical': 1,
        'high': 2,
        'medium': 3,
        'low': 4
    };
    return mapping[severity] || 3;
}

/**
 * Check if report is overdue based on SLA
 */
function isOverdue(slaDeadline) {
    return new Date() > new Date(slaDeadline);
}

/**
 * Generate a unique sequence number for tracking ID
 * In production, this should use a counter in Firestore
 */
async function getNextSequenceNumber(db, district, year) {
    try {
        const counterRef = db.collection('counters').doc(`${district}-${year}`);
        const counterDoc = await counterRef.get();

        if (!counterDoc.exists) {
            await counterRef.set({ sequence: 1 });
            return 1;
        }

        const currentSequence = counterDoc.data().sequence;
        await counterRef.update({ sequence: currentSequence + 1 });
        return currentSequence + 1;
    } catch (error) {
        console.error('Error getting sequence number:', error);
        // Fallback to timestamp-based sequence
        return Date.now() % 100000;
    }
}

/**
 * Create initial history entry
 */
function createHistoryEntry(status, actorId, actorType, action, notes = '') {
    return {
        status,
        timestamp: new Date().toISOString(),
        actor: actorId,
        actorType, // 'citizen' | 'official' | 'system'
        action,
        notes
    };
}

/**
 * Initialize community verification structure
 */
function initializeCommunityVerification() {
    return {
        isVerified: false,
        verificationCount: 0,
        verifiedBy: [],
        verificationThreshold: 3,
        lastVerifiedAt: null
    };
}

/**
 * Initialize engagement metrics
 */
function initializeEngagement() {
    return {
        upvotes: 0,
        downvotes: 0,
        views: 0,
        shares: 0,
        comments: 0,
        followers: []
    };
}

/**
 * Initialize timeline
 */
function initializeTimeline(priority, category) {
    const reportedAt = new Date().toISOString();
    const slaDeadline = calculateSLA(priority, category);

    return {
        reportedAt,
        verifiedAt: null,
        acknowledgedAt: null,
        inProgressAt: null,
        resolvedAt: null,
        slaDeadline,
        isOverdue: false
    };
}

/**
 * Initialize worker assignment structure
 */
function initializeAssignment(department) {
    // Default workers based on department for testing
    const defaultWorkers = {
        'Roads': { id: 'road-worker-1', name: 'Raj Kumar' },
        'Electrical': { id: 'elec-worker-1', name: 'Sureshan K' },
        'Sanitation': { id: 'san-worker-1', name: 'Muthu P' },
        'Sewerage': { id: 'sew-worker-1', name: 'Arjun V' },
        'Water Supply': { id: 'wat-worker-1', name: 'Ganesh M' }
    };

    const worker = defaultWorkers[department] || { id: 'worker-1', name: 'System Assigned' };

    return {
        workerId: worker.id,
        workerName: worker.name,
        assignedAt: new Date().toISOString(),
        status: 'assigned'
    };
}

/**
 * Initialize department approval structure
 */
function initializeDepartmentApproval() {
    return {
        action: 'pending', // 'approve' | 'reject' | 'pending'
        approvedAt: null,
        approvedBy: null,
        signature: null,
        comments: null
    };
}

module.exports = {
    generateTrackingId,
    calculateImpactScore,
    calculateSLA,
    generateGeoHash,
    severityToPriority,
    isOverdue,
    getNextSequenceNumber,
    createHistoryEntry,
    initializeCommunityVerification,
    initializeEngagement,
    initializeTimeline,
    initializeAssignment,
    initializeDepartmentApproval,
    normalizeDistrictName,
    extractDistrictFromAddress
};
