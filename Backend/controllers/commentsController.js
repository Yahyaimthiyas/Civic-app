/**
 * @file commentsController.js
 * @description Controller for managing comments and discussions on civic reports.
 */

/**
 * Adds a new comment to a report.
 */
exports.addComment = async (req, res) => {
    try {
        const { reportId, userId, userName, userEmail, comment, parentCommentId } = req.body;

        if (!reportId || !userId || !comment) {
            return res.status(400).json({
                success: false,
                message: 'Missing required fields (reportId, userId, comment)'
            });
        }

        if (comment.trim().length < 3) {
            return res.status(400).json({
                success: false,
                message: 'Comment must be at least 3 characters long'
            });
        }

        const db = req.app.locals.db;
        const reportRef = db.collection('reports').doc(reportId);
        const reportDoc = await reportRef.get();

        if (!reportDoc.exists) {
            return res.status(404).json({
                success: false,
                message: 'Report not found'
            });
        }

        const commentData = {
            reportId,
            userId,
            userName: userName || 'Anonymous',
            userEmail: userEmail || '',
            comment: comment.trim(),
            parentCommentId: parentCommentId || null,
            upvotes: 0,
            downvotes: 0,
            isEdited: false,
            isFlagged: false,
            flagReason: null,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            deletedAt: null
        };

        const commentRef = await db.collection('comments').add(commentData);

        const currentData = reportDoc.data();
        const currentCommentCount = currentData.engagement?.comments || 0;

        await reportRef.update({
            'engagement.comments': currentCommentCount + 1,
            updatedAt: new Date().toISOString()
        });

        return res.json({
            success: true,
            commentId: commentRef.id,
            message: 'Comment added successfully'
        });

    } catch (error) {
        console.error('Add Comment Error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to add comment',
            error: error.message
        });
    }
};

/**
 * Fetches all comments for a specific report.
 */
exports.getComments = async (req, res) => {
    try {
        const { reportId } = req.params;
        const db = req.app.locals.db;

        const snapshot = await db.collection('comments')
            .where('reportId', '==', reportId)
            .where('deletedAt', '==', null)
            .orderBy('createdAt', 'desc')
            .get();

        if (snapshot.empty) {
            return res.json({
                success: true,
                comments: []
            });
        }

        const comments = [];
        snapshot.forEach(doc => {
            comments.push({ id: doc.id, ...doc.data() });
        });

        const parentComments = comments.filter(c => !c.parentCommentId);
        const replies = comments.filter(c => c.parentCommentId);

        const threaded = parentComments.map(parent => ({
            ...parent,
            replies: replies.filter(r => r.parentCommentId === parent.id)
        }));

        return res.json({
            success: true,
            comments: threaded,
            total: comments.length
        });

    } catch (error) {
        console.error('Fetch Comments Error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch comments',
            error: error.message
        });
    }
};

/**
 * Updates an existing comment.
 */
exports.updateComment = async (req, res) => {
    try {
        const { commentId } = req.params;
        const { userId, comment } = req.body;

        if (!comment || comment.trim().length < 3) {
            return res.status(400).json({
                success: false,
                message: 'Comment must be at least 3 characters long'
            });
        }

        const db = req.app.locals.db;
        const commentRef = db.collection('comments').doc(commentId);
        const commentDoc = await commentRef.get();

        if (!commentDoc.exists) {
            return res.status(404).json({ success: false, message: 'Comment not found' });
        }

        if (commentDoc.data().userId !== userId) {
            return res.status(403).json({ success: false, message: 'Unauthorized to edit this comment' });
        }

        await commentRef.update({
            comment: comment.trim(),
            isEdited: true,
            updatedAt: new Date().toISOString()
        });

        return res.json({ success: true, message: 'Comment updated successfully' });

    } catch (error) {
        console.error('Update Comment Error:', error);
        return res.status(500).json({ success: false, message: 'Failed to update comment', error: error.message });
    }
};

/**
 * Soft deletes a comment.
 */
exports.deleteComment = async (req, res) => {
    try {
        const { commentId } = req.params;
        const { userId } = req.body;

        const db = req.app.locals.db;
        const commentRef = db.collection('comments').doc(commentId);
        const commentDoc = await commentRef.get();

        if (!commentDoc.exists) {
            return res.status(404).json({ success: false, message: 'Comment not found' });
        }

        if (commentDoc.data().userId !== userId) {
            return res.status(403).json({ success: false, message: 'Unauthorized to delete this comment' });
        }

        await commentRef.update({
            deletedAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        });

        const reportId = commentDoc.data().reportId;
        const reportRef = db.collection('reports').doc(reportId);
        const reportDoc = await reportRef.get();

        if (reportDoc.exists) {
            const currentCommentCount = reportDoc.data().engagement?.comments || 0;
            await reportRef.update({
                'engagement.comments': Math.max(0, currentCommentCount - 1),
                updatedAt: new Date().toISOString()
            });
        }

        return res.json({ success: true, message: 'Comment deleted successfully' });

    } catch (error) {
        console.error('Delete Comment Error:', error);
        return res.status(500).json({ success: false, message: 'Failed to delete comment', error: error.message });
    }
};

/**
 * Upvotes a comment.
 */
exports.upvoteComment = async (req, res) => {
    try {
        const { commentId } = req.params;
        
        const db = req.app.locals.db;
        const commentRef = db.collection('comments').doc(commentId);
        const commentDoc = await commentRef.get();

        if (!commentDoc.exists) {
            return res.status(404).json({ success: false, message: 'Comment not found' });
        }

        const currentUpvotes = commentDoc.data().upvotes || 0;

        await commentRef.update({
            upvotes: currentUpvotes + 1,
            updatedAt: new Date().toISOString()
        });

        return res.json({
            success: true,
            upvotes: currentUpvotes + 1,
            message: 'Comment upvoted successfully'
        });

    } catch (error) {
        console.error('Upvote Comment Error:', error);
        return res.status(500).json({ success: false, message: 'Failed to upvote comment', error: error.message });
    }
};
