const mongoose = require("mongoose");
const { categories } = require("../utils/notificationPreferences");

const preferenceFields = Object.fromEntries(
  categories.map((category) => [category, { type: Boolean, default: true }])
);

const notificationPreferenceSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    ...preferenceFields,
  },
  { timestamps: true }
);

notificationPreferenceSchema.statics.categories = categories;

module.exports = mongoose.model("NotificationPreference", notificationPreferenceSchema);
