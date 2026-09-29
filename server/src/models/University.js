const mongoose = require("mongoose");
const slugify = require("slugify");

const universitySchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    slug: {
      type: String,
      unique: true,
    },
    country: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Country",
      required: true,
    },
    city: String,
    language: String,
    studentCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    specialtyCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    overview: String,
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
    ranking: Number,
    tuitionRange: {
      min: Number,
      max: Number,
    },
    logo: String,
    campusImages: [String],
    featured: {
      type: Boolean,
      default: false,
    },
    isPartnerInstitution: {
      type: Boolean,
      default: false,
    },
    // #76: documents required before application to this university
    requiredDocuments: { type: [String], default: [] },
  },
  { timestamps: true }
);

universitySchema.pre("validate", function setSlug(next) {
  if (!this.slug && this.name) {
    this.slug = slugify(this.name, { lower: true, strict: true });
  }
  next();
});

universitySchema.index({ country: 1, featured: -1, name: 1 });
universitySchema.index({ featured: 1, createdAt: -1 });
universitySchema.index({ updatedAt: -1 });

module.exports = mongoose.model("University", universitySchema);
