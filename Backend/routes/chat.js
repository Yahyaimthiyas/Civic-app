const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');

/**
 * @route POST /chat
 * @description Processes a user message using Google's Gemini AI.
 */
router.post('/', chatController.handleChat);

module.exports = router;
