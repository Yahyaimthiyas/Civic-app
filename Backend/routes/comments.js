/**
 * @file comments.js
 * @description Manages the commenting and discussion system for individual reports.
 */
const express = require('express');
const router = express.Router();
const commentsController = require('../controllers/commentsController');

// POST /comments - Add a new comment
router.post('/', commentsController.addComment);

// GET /comments/:reportId - Get all comments for a report
router.get('/:reportId', commentsController.getComments);

// PUT /comments/:commentId - Update a comment
router.put('/:commentId', commentsController.updateComment);

// DELETE /comments/:commentId - Soft delete a comment
router.delete('/:commentId', commentsController.deleteComment);

// POST /comments/:commentId/upvote - Upvote a comment
router.post('/:commentId/upvote', commentsController.upvoteComment);

module.exports = router;
