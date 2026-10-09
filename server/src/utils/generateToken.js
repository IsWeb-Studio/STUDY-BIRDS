const jwt = require('jsonwebtoken');
const { randomUUID } = require('node:crypto');
module.exports = (userId, tokenVersion = 0, claims = {}) => jwt.sign({ ...claims, userId, tokenVersion }, process.env.JWT_SECRET, {
<<<<<<< HEAD
  expiresIn: process.env.JWT_EXPIRES_IN || '7d', jwtid: randomUUID(),
=======
  expiresIn: process.env.JWT_EXPIRES_IN || '30d', jwtid: randomUUID(),
>>>>>>> ca38f8bcb181b23c22878a1c5e0ffadca5f022e7
});
