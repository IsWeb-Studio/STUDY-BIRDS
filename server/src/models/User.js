const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    crmIdentity: { owner: mongoose.Schema.Types.ObjectId, companyId: String, recordId: String },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: {
      type: String,
    },
    appleId: { type: String, unique: true, sparse: true },
    referralCode: { type: String, unique: true, sparse: true },
    verifiedPhone: { type: String },
    googleId: {
      type: String,
      unique: true,
      sparse: true,
    },
    authProvider: {
      type: String,
      enum: ["local", "google", "apple"],
      default: "local",
    },
    emailVerified: {
      type: Boolean,
      default: false,
    },
    role: {
      type: String,
      enum: ["student", "admin", "partner", "parent", "university", "employee"],
      default: "student",
    },
    // NEW — only meaningful when role === "admin". Optional so every
    // existing admin account (employeeRole: null) behaves exactly as before
    // wherever code only checks role === "admin".
    employeeRole: {
      type: String,
      enum: [
        "educational_consultant",
        "sales",
        "admission",
        "admission_manager",
        "visa_officer",
        "travel_coordinator",
        "accommodation_officer",
        "finance",
        "customer_support",
        "branch_manager",
        "operations",
        "marketing",
        "university_relations",
        "agent_manager",
        "content_manager",
        "super_admin",
      ],
      default: null,
    },
    // NEW — free-form permission keys for employeeRole-based authorization.
    // Empty by default; existing admin accounts are unaffected until an
    // admin explicitly assigns permissions to them.
    permissions: {
      type: [String],
      default: [],
    },
    // NEW — only meaningful when role === "university". Links this login
    // account to a catalog University document so the university portal
    // can scope every query to `university: this field`.
    linkedUniversity: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "University",
      default: null,
    },
    avatar: String,
    isActive: {
      type: Boolean,
      default: true,
    },
    lastLoginAt: Date,
    passwordChangedAt: Date,
    tokenVersion: { type: Number, default: 0 },
    twoFactorEnabled: { type: Boolean, default: false },
    refreshTokenHash: { type: String, select: false },
    refreshTokenExpiry: { type: Date },
  },
  { timestamps: true }
);

userSchema.index({'crmIdentity.owner':1,'crmIdentity.companyId':1,'crmIdentity.recordId':1}, {unique:true,partialFilterExpression:{'crmIdentity.recordId':{$type:'string'}}});

userSchema.pre("save", async function preSave(next) {
  if (!this.isModified("password") || !this.password) {
    next();
    return;
  }

  const salt = await bcrypt.genSalt(10);
    if (!this.isNew) {
      this.refreshTokenHash = undefined;
      this.refreshTokenExpiry = undefined;
    }
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

userSchema.methods.comparePassword = function comparePassword(candidatePassword) {
  if (!this.password || !candidatePassword) {
    return false;
  }

  return bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model("User", userSchema);
