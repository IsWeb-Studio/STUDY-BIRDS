const mongoose = require("mongoose");
const slugify = require("slugify");

const ourServiceSchema = new mongoose.Schema(
  {
    slug: {
      type: String,
      unique: true,
      sparse: true,
      trim: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    image: {
      type: String,
      default: "",
    },
    detailTitle: {
      type: String,
      default: "",
      trim: true,
    },
    detailBody: {
      type: String,
      default: "",
      trim: true,
    },
    priceDescription: { type: String, trim: true, maxlength: 200, default: '' },
    estimatedDuration: { type: String, trim: true, maxlength: 200, default: '' },
    // #114: numeric price/duration for auto-invoice generation
    price: { type: Number, min: 0, default: 0 },
    durationDays: { type: Number, min: 0, default: 0 },
    // #75/76: link to journey stage for rules engine
    journeyStage: { type: String, trim: true, default: '' },
    requirementsText: { type: String, trim: true, maxlength: 4000, default: '' },
    documentsText: { type: String, trim: true, maxlength: 4000, default: '' },
    detailImage: {
      type: String,
      default: "",
    },
    featured: {
      type: Boolean,
      default: true,
    },
    sortOrder: {
      type: Number,
      default: 0,
    },
    country: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Country",
      default: null,
    },
  },
  { timestamps: true }
);

ourServiceSchema.pre("validate", function ourServicePreValidate(next) {
  if (this.title && (!this.slug || this.isModified("title"))) {
    this.slug = slugify(this.title, { lower: true, strict: true }) || `service-${this._id}`;
  }

  next();
});

ourServiceSchema.index({ featured: -1, sortOrder: 1, createdAt: -1 });
ourServiceSchema.index({ updatedAt: -1 });

module.exports = mongoose.model("OurService", ourServiceSchema);
