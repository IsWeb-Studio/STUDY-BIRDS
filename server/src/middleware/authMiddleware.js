const jwt = require("jsonwebtoken");
const crypto = require('node:crypto');
const User = require("../models/User");
const asyncHandler = require("../utils/asyncHandler");

const protect = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization;

  if (!header || !header.startsWith("Bearer ")) {
    res.status(401);
    throw new Error("Not authorized");
  }

  const token = header.split(" ")[1];
  let decoded;
  try {
    decoded = jwt.verify(token, process.env.JWT_SECRET);
  } catch (error) {
    if (!["JsonWebTokenError", "TokenExpiredError", "NotBeforeError"].includes(error.name)) throw error;
    res.status(401);
    throw new Error("Your session has expired. Please sign in again.");
  }
  const user = await User.findById(decoded.userId).select("-password");

  if (!user) {
    res.status(401);
    throw new Error("User no longer exists");
  }

  if (!user.isActive) {
    res.status(403);
    throw new Error("This account is inactive");
  }

  if ((decoded.tokenVersion || 0) !== (user.tokenVersion || 0)) {
    res.status(401); throw new Error('Password changed. Please sign in again.');
  }
  const { Session } = require('../models/MobileWorkspace');
  const digest = crypto.createHash('sha256').update(token).digest('hex');
  if (await Session.exists({ digest, revoked: true })) {
    res.status(401); throw new Error('Session revoked. Please sign in again.');
  }
  // Track mobile devices, but enforce revocation even when the header is omitted.
  if (['mobile', 'web'].includes(req.headers['x-study-birds-client'])) {
    const session = await Session.findOneAndUpdate({ digest }, {
      $set: { lastSeen: new Date() },
      $setOnInsert: { user: user._id, expiresAt: new Date(decoded.exp * 1000), device: String(req.headers['user-agent'] || 'Study Birds Mobile').slice(0, 200) },
    }, { upsert: true, new: true });
    if (session.revoked) { res.status(401); throw new Error('Session revoked. Please sign in again.'); }
  }

  req.user = user;
  req.googlePasswordVerifiedAt = decoded.googlePasswordVerifiedAt;
  next();
});

const authorize = (...roles) => (req, res, next) => {
  if (!req.user || !roles.includes(req.user.role)) {
    res.status(403);
    throw new Error("Forbidden");
  }

  next();
};

module.exports = {
  protect,
  authorize,
};
