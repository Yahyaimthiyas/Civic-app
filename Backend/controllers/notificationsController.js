/**
 * @file notificationsController.js
 * @description Controller for fetching and managing user notifications.
 */
const { markAllAsRead } = require('../utils/notificationHelper');

/**
 * Fetches notifications for a specific user.
 */
exports.getNotifications = async (req, res) => {
    try {
        const userId = req.params.userId;
        const db = req.app.locals.db;

        const snapshot = await db.collection('notifications')
            .where('userId', '==', userId)
            .limit(50)
            .get();

        const notifications = [];
        snapshot.forEach(doc => {
            notifications.push({ id: doc.id, ...doc.data() });
        });

        // Sort in-memory (descending order by createdAt)
        notifications.sort((a, b) => {
            return new Date(b.createdAt) - new Date(a.createdAt);
        });

        return res.json({ success: true, notifications });
    } catch (error) {
        console.error('Fetch Notifications Error:', error);
        return res.status(500).json({ success: false, message: 'Failed to fetch notifications', error: error.message });
    }
};

/**
 * Marks a single notification as read.
 */
exports.markRead = async (req, res) => {
    try {
        const id = req.params.id;
        const db = req.app.locals.db;
        await db.collection('notifications').doc(id).update({ isRead: true });
        return res.json({ success: true, message: 'Notification marked as read' });
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Marks all notifications as read for a given user.
 */
exports.markAllRead = async (req, res) => {
    try {
        const userId = req.params.userId;
        const db = req.app.locals.db;
        await markAllAsRead(db, userId);
        return res.json({ success: true, message: 'All notifications marked as read' });
    } catch (error) {
        return res.status(500).json({ success: false, message: error.message });
    }
};
