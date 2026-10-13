const mongoose = require("mongoose");
module.exports = mongoose.model("MobileRequest", new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
  content: { type: mongoose.Schema.Types.ObjectId, ref: "MobileContent", required: true },
  title: String, section: String, message: { type: String, maxlength: 4000 },
  status: { type: String, enum: ["submitted", "in-progress", "completed", "cancelled"], default: "submitted" },
  adminNote: { type: String, maxlength: 4000, default: "" },
}, { timestamps: true }));
