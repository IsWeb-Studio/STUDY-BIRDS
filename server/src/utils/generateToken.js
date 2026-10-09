const jwt = require('jsonwebtoken');
const { randomUUID } = require('node:crypto');
module.exports = (userId, tokenVersion = 0, claims = {}) => jwt.sign({ ...claims, userId, tokenVersion }, process.env.JWT_SECRET, {
  expiresIn: process.env.JWT_EXPIRES_IN || '30d', jwtid: randomUUID(),
});
