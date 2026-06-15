/**
 * @file communityController.js
 * @description Controller for community analytics and leaderboard logic.
 */
const { normalizeDistrictName } = require('../utils/reportHelpers');

const ANALYTICS_CACHE_TTL_MS = 60000; // 1 minute
const LEADERBOARD_CACHE_TTL_MS = 60000; // 1 minute

const analyticsCache = {};
const leaderboardCache = {};

function getDistrictKey(district) {
    return district && district !== 'All Districts' ? district : 'ALL';
}

/**
 * Fetches high-level analytics for reports (by district or all).
 */
exports.getAnalytics = async (req, res) => {
    try {
        const { district } = req.query;
        const db = req.app.locals.db;

        const key = getDistrictKey(district);
        const nowMs = Date.now();
        const cached = analyticsCache[key];

        const LIVE_TTL = 30000; // 30 seconds
        if (cached && (nowMs - cached.timestamp) < LIVE_TTL) {
            return res.json(cached.payload);
        }

        let query = db.collection('reports');
        if (district && district !== 'All Districts') {
            const normalizedDist = normalizeDistrictName(district);
            query = query.where('district', '==', normalizedDist);
        }

        const snapshot = await query.get();

        let total = 0;
        let resolved = 0;
        let pending = 0;
        let inProgress = 0;
        let verified = 0;
        let rejected = 0;

        const categoryCounts = {};
        const dailyTrend = {};

        const nowDate = new Date();
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(nowDate.getDate() - 7);

        snapshot.forEach(doc => {
            const data = doc.data();
            total++;

            // Status counts - GRANULAR
            const status = (data.status || 'PENDING').toUpperCase();
            if (status === 'RESOLVED') resolved++;
            else if (status === 'IN_PROGRESS') inProgress++;
            else if (status === 'VERIFIED') verified++;
            else if (status === 'REJECTED') rejected++;
            else pending++;

            // Category counts
            const cat = data.category || 'Other';
            categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;

            // Daily Trend (Last 7 Days)
            const createdAt = data.createdAt ? (data.createdAt.toDate ? data.createdAt.toDate() : new Date(data.createdAt)) : new Date();
            if (createdAt >= sevenDaysAgo) {
                const dateKey = createdAt.toISOString().split('T')[0];
                dailyTrend[dateKey] = (dailyTrend[dateKey] || 0) + 1;
            }
        });

        const trendData = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(nowDate.getDate() - i);
            const key = d.toISOString().split('T')[0];
            const count = dailyTrend[key] || 0;
            trendData.push({ date: key, count });
        }

        const payload = {
            success: true,
            stats: {
                total,
                resolved,
                pending,
                inProgress,
                verified,
                rejected,
                categoryCounts,
                trendData
            }
        };

        analyticsCache[key] = { timestamp: Date.now(), payload };
        return res.json(payload);

    } catch (error) {
        console.error("Analytics Error:", error);
        return res.status(500).json({ success: false, message: "Failed to fetch analytics" });
    }
};

/**
 * Fetches the community leaderboard based on user impact points.
 */
exports.getLeaderboard = async (req, res) => {
    try {
        const { district } = req.query;
        const db = req.app.locals.db;

        const key = getDistrictKey(district);
        const now = Date.now();
        const cached = leaderboardCache[key];

        const LIVE_TTL = 30000; // 30 seconds
        if (cached && (now - cached.timestamp) < LIVE_TTL) {
            return res.json(cached.payload);
        }

        let query = db.collection('reports');
        if (district && district !== 'All Districts') {
            const normalizedDist = normalizeDistrictName(district);
            query = query.where('district', '==', normalizedDist);
        }

        // Safety limit
        query = query.limit(200);

        const snapshot = await query.get();
        const userScores = {};

        snapshot.forEach(doc => {
            const data = doc.data();
            const uid = data.userId;
            if (!uid) return;

            if (!userScores[uid]) {
                userScores[uid] = {
                    userId: uid,
                    // Use a placeholder name, we will resolve "Citizen" names later
                    name: (data.userName && data.userName !== 'Anonymous' && data.userName !== 'Citizen')
                        ? data.userName
                        : (data.fullName || data.name || 'Citizen'),
                    reports: 0,
                    resolved: 0,
                    score: 0
                };
            }

            userScores[uid].reports++;
            if (data.status === 'RESOLVED') userScores[uid].resolved++;
        });

        // RESOLVE NAMES for "Citizen" users from aadhaarRegistry
        const uidsToResolve = Object.keys(userScores).filter(uid => userScores[uid].name === 'Citizen' || userScores[uid].name === 'Unknown');

        if (uidsToResolve.length > 0) {
            // Fetch in batches of 10 to avoid too many parallel reads
            for (let i = 0; i < uidsToResolve.length; i += 10) {
                const batch = uidsToResolve.slice(i, i + 10);
                const userDocs = await Promise.all(batch.map(uid => db.collection('aadhaarRegistry').doc(uid).get()));

                userDocs.forEach((doc, idx) => {
                    if (doc.exists) {
                        const userData = doc.data();
                        const realName = userData.fullName || userData.name;
                        if (realName) {
                            userScores[batch[idx]].name = realName;
                        }
                    }
                });
            }
        }

        const leaderboard = Object.values(userScores).map(user => ({
            ...user,
            score: (user.reports * 10) + (user.resolved * 50)
        }));

        leaderboard.sort((a, b) => b.score - a.score);
        const topUsers = leaderboard.slice(0, 50);

        const payload = { success: true, leaderboard: topUsers };
        leaderboardCache[key] = { timestamp: Date.now(), payload };
        return res.json(payload);

    } catch (error) {
        console.error("Leaderboard Error:", error);
        return res.status(500).json({ success: false, message: "Failed to fetch leaderboard" });
    }
};
