/**
 * Utility for creating and managing real-time notifications in Firestore.
 */

/**
 * Creates a notification for a specific user.
 * 
 * @param {Object} db - Firestore database instance
 * @param {string} userId - ID of the user to notify
 * @param {string} type - Notification category (UPDATE, DANGER, SUCCESS, AWARD)
 * @param {string} title - Short title for the notification
 * @param {string} message - Detailed description or message
 * @param {string} reportId - Optional associated report ID
 * @param {string} actorPhoto - Optional photo of the user who triggered the event
 * @returns {Promise<string>} - The ID of the created notification
 */
async function createNotification(db, userId, type, title, message, reportId = null, actorPhoto = null) {
    if (!userId) {
        console.warn('Cannot create notification: No userId provided.');
        return null;
    }

    try {
        const notificationData = {
            userId,
            type: type || 'UPDATE',
            title,
            message,
            reportId,
            actorPhoto,
            isRead: false,
            createdAt: new Date().toISOString(),
            // Map types to UI colors/icons for convenience
            category: type || 'UPDATE',
            status: 'active'
        };

        const docRef = await db.collection('notifications').add(notificationData);
        console.log(`🔔 Notification created for ${userId}: ${title}`);
        return docRef.id;
    } catch (error) {
        console.error('Error creating notification:', error);
        return null;
    }
}

/**
 * Marks all notifications for a user as read.
 */
async function markAllAsRead(db, userId) {
    try {
        const snapshot = await db.collection('notifications')
            .where('userId', '==', userId)
            .where('isRead', '==', false)
            .get();

        if (snapshot.empty) return;

        const batch = db.batch();
        snapshot.forEach(doc => {
            batch.update(doc.ref, { isRead: true });
        });

        await batch.commit();
    } catch (error) {
        console.error('Error marking notifications as read:', error);
    }
}

module.exports = {
    createNotification,
    markAllAsRead
};
