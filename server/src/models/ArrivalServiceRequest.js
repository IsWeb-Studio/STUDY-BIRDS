const mongoose = require("mongoose");

const arrivalServiceRequestSchema = new mongoose.Schema(
  {
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    application: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Application",
      index: true,
    },
    arrivalDate: Date,
    arrivalTime: String,
    flightNumber: String,
    airport: String,
    notes: String,
    services: {
      airportPickup: { type: Boolean, default: false },
      studentHousing: { type: Boolean, default: false },
      residencePermitSupport: { type: Boolean, default: false },
      visaSupport: { type: Boolean, default: false },
    },
    status: {
      type: String,
      enum: ["draft", "submitted", "in-progress", "completed"],
      default: "submitted",
      index: true,
    },
    adminNote: String,
    travelAlert: { type: String, default: "", trim: true },
    pickup: {
      status: { type: String, enum: ["not-assigned", "assigned", "en-route", "arrived", "completed"], default: "not-assigned" },
      driverName: { type: String, default: "", trim: true },
      driverPhone: { type: String, default: "", trim: true },
      confirmedAt: Date,
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("ArrivalServiceRequest", arrivalServiceRequestSchema);
