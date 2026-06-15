/**
 * @file report.js
 * @description Core route handler for the Civic App's complaint reporting system.
 */
const express = require('express');
const router = express.Router();
const multer = require('multer');
const reportController = require('../controllers/reportController');

// Setup multer for temp uploads
const upload = multer({
    dest: 'uploads/',
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

router.post('/analyze', upload.single('file'), reportController.analyze);
router.get('/classify-district', reportController.classifyDistrict);
router.post('/submit', upload.single('file'), reportController.submitReport);
router.get('/user/:userId', reportController.getUserReports);
router.get('/stats/:district', reportController.getStats);
router.get('/feed', reportController.getFeed);
router.post('/upvote/:reportId', reportController.upvoteReport);
router.post('/verify/:reportId', reportController.verifyReport);
router.get('/comments/:reportId', reportController.getComments);
router.post('/comment/:reportId', reportController.addComment);
router.get('/details/:reportId', reportController.getDetails);
router.post('/simulate-assign/:reportId', reportController.simulateAssign);
router.post('/simulate-resolve/:reportId', reportController.simulateResolve);

module.exports = router;
