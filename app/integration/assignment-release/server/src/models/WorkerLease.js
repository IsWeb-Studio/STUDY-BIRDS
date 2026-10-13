const mongoose = require('mongoose');

// Keep one persistent row per worker; expiration is checked atomically, not by TTL.
module.exports = mongoose.model('WorkerLease', new mongoose.Schema({
  _id: String,
  owner: { type: String, required: true },
  expiresAt: { type: Date, required: true },
}, { versionKey: false }));
