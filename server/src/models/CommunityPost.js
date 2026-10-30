const mongoose = require("mongoose");

const COMMUNITY_TOPICS = ["experience", "housing", "tips", "student_life", "faq", "other"];

const communityPostSchema = new mongoose.Schema(
  {
    author: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    title: { type: String, default: '', trim: true, maxlength: 150 },
    body: { type: String, required: true, trim: true, maxlength: 5000 },
    topic: { type: String, enum: COMMUNITY_TOPICS, default: "other", index: true },
    image: { type: new mongoose.Schema({ publicId: String, format: String,
      resourceType: String, deliveryType: String }, { _id: false }), select: false },
    hasImage: { type: Boolean, default: false },
    operationId: String,
    country: { type: mongoose.Schema.Types.ObjectId, ref: "Country" },
    university: { type: mongoose.Schema.Types.ObjectId, ref: "University" },
    studyField: { type: mongoose.Schema.Types.ObjectId, ref: "StudyField" },
    // Published comments only — hidden ones are not counted.
    commentCount: { type: Number, default: 0, min: 0 },
    // Open (unreviewed) reports against the post itself.
    reportCount: { type: Number, default: 0, min: 0 },
    status: { type: String, enum: ["published", "hidden"], default: "published", index: true },
    moderatedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    moderationNote: { type: String, default: "", trim: true },
  },
  { timestamps: true }
);

communityPostSchema.index({ status: 1, createdAt: -1 });
communityPostSchema.index({ author: 1, operationId: 1 }, { unique: true,
  partialFilterExpression: { operationId: { $type: 'string' } } });
communityPostSchema.index({ reportCount: -1, createdAt: -1 });

module.exports = mongoose.model("CommunityPost", communityPostSchema);
module.exports.COMMUNITY_TOPICS = COMMUNITY_TOPICS;
