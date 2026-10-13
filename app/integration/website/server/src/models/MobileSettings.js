const mongoose = require("mongoose");
const { defaults } = require("../utils/mobileConfig");
const schema = new mongoose.Schema({
  key: { type: String, unique: true, default: "mobile" },
  config: { type: mongoose.Schema.Types.Mixed, default: defaults },
  revision: { type: Number, default: 0 },
  updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
}, { timestamps: true });
module.exports = mongoose.model("MobileSettings", schema);
