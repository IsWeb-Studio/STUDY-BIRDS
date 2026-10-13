const mongoose = require("mongoose");
const { contentModules } = require("../utils/mobileConfig");
module.exports = mongoose.model("MobileContent", new mongoose.Schema({
  section: { type: String, enum: contentModules, required: true, index: true },
  title: { type: String, required: true }, body: String, imageUrl: String, linkUrl: String,
  date: Date, published: { type: Boolean, default: false }, requestable: { type: Boolean, default: false },
  order: { type: Number, default: 0 },
}, { timestamps: true }));
