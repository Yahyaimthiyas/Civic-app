/**
 * @file notifications.js
 * @description Manages push notifications and real-time alerts for the Civic App.
 */
const express = require('express');
const router = express.Router();
const notificationsController = require('../controllers/notificationsController');

// GET /notifications/:userId - Fetch notifications for a specific user
router.get('/:userId', notificationsController.getNotifications);

// POST /notifications/mark-read/:id - Mark single notification as read
router.post('/mark-read/:id', notificationsController.markRead);

// POST /notifications/mark-all-read/:userId - Mark all read for user
router.post('/mark-all-read/:userId', notificationsController.markAllRead);

module.exports = router;
