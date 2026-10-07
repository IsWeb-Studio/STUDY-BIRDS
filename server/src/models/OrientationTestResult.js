const mongoose = require("mongoose");

const orientationTestResultSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
      index: true,
    },
    answers: {
      favoriteSubjects: [String],
      interestedFields: [String],
      studyStyle: String,
      preferredLanguage: String,
      preferredCountry: String,
      approximateBudget: String,
      desiredDegreeLevel: String,
      avoidFields: [String],
    },
    recommendationSummary: String,
    suggestedFields: [String],
    suggestedCountries: [String],
    // #23: ranked matched programs with score
    matchedPrograms: [{
      program: { type: mongoose.Schema.Types.ObjectId, ref: 'Program' },
      score:   { type: Number },
    }],
    adminNote: String,
    reviewedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("OrientationTestResult", orientationTestResultSchema);
