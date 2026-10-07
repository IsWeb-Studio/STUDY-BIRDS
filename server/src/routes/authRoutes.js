const express = require("express");
const {
  register,
  login,
  googleLogin,
  requestOtp,
  verifyOtp,
  me,
  changePassword,
  refresh,
  logout,
  deleteAccount,
} = require("../controllers/authController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/register", register);
router.post("/login", login);
router.post("/google", googleLogin);
// #6: Phone OTP login
router.post("/otp/request", requestOtp);
router.post("/otp/verify", verifyOtp);
router.get("/me", protect, me);
router.post("/change-password", protect, changePassword);
router.post("/refresh", refresh);
router.post("/logout", logout);
router.delete("/account", protect, deleteAccount);

module.exports = router;
