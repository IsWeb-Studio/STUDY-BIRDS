const express = require("express");
const {
  register,
  login,
  googleLogin,
  requestOtp,
  verifyOtp,
  requestEmailOtp,
  verifyEmailOtp,
  me,
  changePassword,
  refresh,
  logout,
  deleteAccount,
} = require("../controllers/authController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();
const { rateLimit } = require('express-rate-limit');
const authAttempts = rateLimit({ windowMs: 15 * 60 * 1000, limit: 60,
  standardHeaders: 'draft-7', legacyHeaders: false,
  message: { message: 'محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم حاول مجددًا.' } });
router.use(['/register', '/login', '/google', '/otp/request', '/otp/verify', '/email-otp/request', '/email-otp/verify', '/change-password', '/account'], authAttempts);

router.post("/register", register);
router.post("/login", login);
router.post("/google", googleLogin);
// #6: Phone OTP login
router.post("/otp/request", requestOtp);
router.post("/otp/verify", verifyOtp);
router.post("/email-otp/request", requestEmailOtp);
router.post("/email-otp/verify", verifyEmailOtp);
router.get("/me", protect, me);
router.post("/change-password", protect, changePassword);
router.post("/refresh", refresh);
router.post("/logout", logout);
router.delete("/account", protect, deleteAccount);

module.exports = router;
