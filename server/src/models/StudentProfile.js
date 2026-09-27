const mongoose = require("mongoose");

const studentProfileSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    phone: String,
    englishFullName: String,
    passportNumber: String,
    dateOfBirth: Date,
    nationality: String,
    currentEducation: String,
    currentEducationLevel: {
      type: String,
      enum: ["high-school", "bachelor", "master", "phd", ""],
      default: "",
    },
    currentResidenceCountry: String,
    gpa: String,
    englishTest: {
      exam: String,
      score: String,
    },
    targetCountries: [String],
    intake: String,
    bio: String,
    address: String,
    parentInfo: { name: String, phone: String, relationship: String },
    emergencyContact: { name: String, phone: String, relationship: String },
    nativeLanguage: String,
    otherLanguages: [String],
    companyName: String,
    website: String,
    location: String,
    taxId: String,
    verificationStatus: {
      type: String,
      enum: ["pending", "verified", "rejected"],
      default: "pending",
    },
    verificationReason: String,
    referralCode: {
      type: String,
      index: true,
      sparse: true,
    },
    applicationStage: {
      type: String,
      enum: [
        "file-received",
        "applying",
        "preliminary-accepted",
        "first-payment",
        "final-accepted",
        "travel-and-settlement",
      ],
      default: "file-received",
    },
    // NEW — granular 14-stage journey used by the mobile app's Journey
    // Tracker. `applicationStage` above is left completely untouched and is
    // kept in sync automatically (see pre-save hook below), so every
    // existing website view that reads applicationStage keeps working
    // exactly as before with zero code changes on the website side.
    journeyStage: {
      type: String,
      enum: [
        "file-received",
        "documents-review",
        "university-selection",
        "applying",
        "university-review",
        "preliminary-accepted",
        "first-payment",
        "final-accepted",
        "visa",
        "travel",
        "reception",
        "accommodation",
        "university-registration",
        "studies-started",
      ],
      default: "file-received",
    },
  },
  { timestamps: true }
);

const { JOURNEY_STAGE_TO_LEGACY_STAGE } = require("../constants/roles");

// Keep the legacy 6-value field in sync whenever the app sets the new
// granular 14-value field, WITHOUT ever writing a value the website doesn't
// already recognize. If something instead sets applicationStage directly
// (e.g. an older code path), journeyStage is left as-is — it is not
// reverse-derived, since the mapping is many-to-one and not invertible.
studentProfileSchema.pre("save", function syncLegacyApplicationStage(next) {
  if (this.isModified("journeyStage")) {
    const legacyStage = JOURNEY_STAGE_TO_LEGACY_STAGE[this.journeyStage];
    if (legacyStage) {
      this.applicationStage = legacyStage;
    }
  }
  next();
});

module.exports = mongoose.model("StudentProfile", studentProfileSchema);
