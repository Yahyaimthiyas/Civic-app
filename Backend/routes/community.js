/**
 * @file community.js
 * @description Manages community-focused features of the Civic App.
 */
const express = require('express');
const router = express.Router();
const communityController = require('../controllers/communityController');

// GET /community/analytics
router.get('/analytics', communityController.getAnalytics);

// GET /community/leaderboard
router.get('/leaderboard', communityController.getLeaderboard);

module.exports = router;
