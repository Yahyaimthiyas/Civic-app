const { createNotification } = require('../utils/notificationHelper');

/**
 * Initializes a Firestore listener on the 'reports' collection
 * to detect status changes and trigger real-time notifications.
 * @param {object} db - Firestore database instance
 */
async function startStatusMonitor(db) {
    console.log("🔭 Real-Time Status Monitor: Pre-loading active report states...");

    try {
        // Pre-populate cache so we don't miss notifications after a server restart
        const snapshot = await db.collection('reports').get();
        snapshot.forEach(doc => {
            const data = doc.data();
            stateCache.set(doc.id, {
                status: (data.status || 'PENDING').toUpperCase(),
                verifications: data.communityVerification?.verificationCount || 0
            });
        });
        console.log(`✅ Loaded ${stateCache.size} reports into state cache.`);
    } catch (e) {
        console.error("⚠️ Failed to pre-load status cache:", e.message);
    }

    console.log("🔭 Real-Time Status Monitor: Listening for changes...");

    // Use docChanges for better performance - only process documents that actually changed
    db.collection('reports').onSnapshot(snapshot => {
        snapshot.docChanges().forEach(change => {
            if (change.type === 'added' || change.type === 'modified') {
                handleStatusChange(db, change.doc.id, change.doc.data());
            }
        });
    });
}

// Simple in-memory cache to track last known state of active reports
const stateCache = new Map();

async function handleStatusChange(db, reportId, data) {
    const currentStatus = (data.status || 'PENDING').toUpperCase();
    const currentVerifications = data.communityVerification?.verificationCount || 0;

    const lastState = stateCache.get(reportId) || { status: null, verifications: 0 };

    // Case 1: NEW Report Added
    if (lastState.status === null) {
        console.log(`📡 New report detected: ${data.trackingId}`);
        await createNotification(
            db,
            data.userId,
            'SUCCESS',
            'Report Received',
            `Your report ${data.trackingId} has been successfully submitted and is awaiting verification.`,
            reportId
        );
    }
    // Case 2: Status has changed
    else if (currentStatus !== lastState.status) {
        console.log(`🔔 Status change detected for ${data.trackingId}: ${lastState.status} -> ${currentStatus}`);

        // Prepare notification content
        let title = "Status Update";
        let message = `Your report ${data.trackingId} status has changed to ${currentStatus}.`;
        let type = 'UPDATE';

        if (currentStatus === 'RESOLVED') {
            title = "Issue Resolved! 🎉";
            message = `Great news! Your report ${data.trackingId} regarding ${data.category.replace(/_/g, ' ')} has been marked as resolved.`;
            type = 'SUCCESS';
        } else if (currentStatus === 'IN_PROGRESS') {
            const workerName = data.assignment?.workerName || 'an official';
            title = "Work in Progress 👷";
            message = `Your report ${data.trackingId} has been assigned to ${workerName} for inspection.`;
        } else if (currentStatus === 'VERIFIED') {
            title = "Report Verified ✅";
            message = `Your report ${data.trackingId} has been verified by the community and is awaiting assignment.`;
            type = 'SUCCESS';
        } else if (currentStatus === 'REJECTED') {
            title = "Report Update";
            message = `There is an update regarding your report ${data.trackingId}. Please check the details.`;
            type = 'DANGER';
        }

        await createNotification(db, data.userId, type, title, message, reportId);
    }
    // Case 3: Verification count increased (but status didn't necessarily change yet)
    else if (currentVerifications > lastState.verifications && currentStatus === 'PENDING') {
        console.log(`🔔 Verification added for ${data.trackingId}: ${currentVerifications} total`);

        await createNotification(
            db,
            data.userId,
            'SUCCESS',
            'Verification Added',
            `A community member verified your report ${data.trackingId}. (${currentVerifications}/${data.communityVerification?.verificationThreshold || 3})`,
            reportId
        );
    }

    // Update cache with full state
    stateCache.set(reportId, {
        status: currentStatus,
        verifications: currentVerifications
    });
}

module.exports = { startStatusMonitor };
