const mongoose = require("mongoose");
const slugify = require("slugify");

const programSchema = new mongoose.Schema(
  {
    university: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "University",
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    slug: {
      type: String,
      unique: true,
    },
    degreeLevel: {
      type: String,
      required: true,
    },
    fieldOfStudy: {
      type: String,
      required: true,
    },
    fieldsOfStudy: {
      type: [String],
      default: [],
    },
    language: String,
    duration: String,
    tuition: Number,
    partnerTuition: Number,
    applicationDeadline: Date,
    intake: String,
    requirements: [String],
    // Career paths and job areas after graduation (PRD 21).
    careerOpportunities: { type: [String], default: [] },
    requiredDocumentTypes: {
      type: [{ type: String, enum: ['passport', 'biometric-photo', 'latest-qualification', 'transcript', 'language-certificate', 'other'] }],
      default: undefined,
      validate: { validator: (items) => !items || (items.length <= 6 && new Set(items).size === items.length), message: 'Document requirements must be unique' },
    },
    summary: String,
    articleTitle: String,
    articleTitleColor: {
      type: String,
      default: "#0f172a",
    },
    articleHeadingColor: {
      type: String,
      default: "#0f172a",
    },
    articleBodyColor: {
      type: String,
      default: "#475569",
    },
    articleHeadings: {
      type: [String],
      default: [],
    },
    articleBodies: {
      type: [String],
      default: [],
    },
    coverImage: String,
    featured: {
      type: Boolean,
      default: false,
    },
    popularity: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

programSchema.pre("validate", function setSlug(next) {
  if (!this.slug && this.title) {
    const base = slugify([this.title, this.degreeLevel, this.language].filter(Boolean).join("-"), {
      lower: true,
      strict: true,
    });
    // Each language offering is a separate program. Its id keeps the slug
    // unique even when slugify removes or normalizes characters in its name.
    this.slug = `${base || "program"}-${this._id}`;
  }
  next();
});

programSchema.index({ university: 1, featured: -1, createdAt: -1 });
programSchema.index({ degreeLevel: 1, intake: 1, featured: -1, createdAt: -1 });
programSchema.index({ fieldOfStudy: 1, featured: -1, createdAt: -1 });
programSchema.index({ fieldsOfStudy: 1 });
programSchema.index({ updatedAt: -1 });

module.exports = mongoose.model("Program", programSchema);
