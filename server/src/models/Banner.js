const mongoose = require("mongoose");

const bannerSchema = new mongoose.Schema(
  {
    tag: { type: String, default: "" },
    title: { type: String, required: true },
    subtitle: { type: String, default: "" },
    actionLabel: { type: String, default: "اكتشف المزيد" },
    destination: { type: String, default: "universities" },
    imageUrl: { type: String, default: "" },
    active: { type: Boolean, default: true },
    order: { type: Number, default: 0 },
  },
  { timestamps: true }
);

bannerSchema.index({ active: 1, order: 1 });

module.exports = mongoose.model("Banner", bannerSchema);
