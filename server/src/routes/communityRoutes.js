const express = require("express");
const { rateLimit } = require("express-rate-limit");
const { protect, authorize } = require("../middleware/authMiddleware");
const { getMyStatus, listPosts, createPost, getPost, deleteOwnPost, createComment, deleteOwnComment, reportPost, reportComment } = require("../controllers/communityController");

const router = express.Router();
router.use(protect, authorize('student', 'parent', 'university', 'employee', 'admin'));

const postLimit = rateLimit({ windowMs: 60 * 60 * 1000, limit: 10, keyGenerator: (req) => String(req.user._id), standardHeaders: "draft-7", legacyHeaders: false });
const commentLimit = rateLimit({ windowMs: 60 * 1000, limit: 20, keyGenerator: (req) => String(req.user._id), standardHeaders: "draft-7", legacyHeaders: false });
const reportLimit = rateLimit({ windowMs: 60 * 60 * 1000, limit: 20, keyGenerator: (req) => String(req.user._id), standardHeaders: "draft-7", legacyHeaders: false });

router.get("/status", getMyStatus);
router.get("/posts", listPosts);
router.post("/posts", postLimit, createPost);
router.post('/posts/image', postLimit, require('../middleware/uploadMiddleware').single('file'), createPost);
router.get('/posts/:id/image', require('../controllers/communityController').getPostImage);
const reactionLimit = rateLimit({ windowMs: 60000, limit: 60, keyGenerator: req => String(req.user._id) });
router.put('/posts/:id/reaction', reactionLimit, require('../controllers/communityController').setReaction);
router.delete('/posts/:id/reaction', reactionLimit, require('../controllers/communityController').setReaction);
router.put('/posts/:id/like', reactionLimit, require('../controllers/communityController').setReaction);
router.delete('/posts/:id/like', reactionLimit, require('../controllers/communityController').setReaction);
router.get("/posts/:id", getPost);
router.patch('/posts/:id', require('../controllers/communityController').editOwnPost);
router.patch('/comments/:id', require('../controllers/communityController').editOwnComment);
router.delete("/posts/:id", deleteOwnPost);
router.post("/posts/:id/comments", commentLimit, createComment);
router.post("/posts/:id/report", reportLimit, reportPost);
router.delete("/comments/:id", deleteOwnComment);
router.post("/comments/:id/report", reportLimit, reportComment);

router.capabilities = Object.freeze({ version: 2, text: true, images: true,
  reactions: true, optionalTitle: true, administrationFilter: true });
module.exports = router;
