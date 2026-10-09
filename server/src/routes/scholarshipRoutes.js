const { escapeSearch } = require('../middleware/requestSafety');
const express = require("express");
const mongoose = require("mongoose");
const { protect, authorize } = require("../middleware/authMiddleware");
const run = require("../utils/asyncHandler");
const schema = new mongoose.Schema(
  {
    title: { type: String, required: true, maxlength: 160 },
    university: String,
    country: String,
    degree: String,
    funding: String,
    eligibility: String,
    deadline: Date,
    active: { type: Boolean, default: false },
  },
  { timestamps: true },
);
const Scholarship = mongoose.model("Scholarship", schema);
const applicationSchema = new mongoose.Schema(
  {
    scholarship: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Scholarship",
      required: true,
    },
    student: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    status: {
      type: String,
      enum: ["submitted", "reviewing", "accepted", "rejected"],
      default: "submitted",
    },
  },
  { timestamps: true },
);
applicationSchema.index({ scholarship: 1, student: 1 }, { unique: true });
const Entry = mongoose.model("ScholarshipEntry", applicationSchema);
const router = express.Router();
const fail = (res, code, message) => {
  res.status(code);
  throw new Error(message);
};
const available = () => ({
  active: true,
  $or: [{ deadline: null }, { deadline: { $gt: new Date() } }],
});
const payload = (body) =>
  Object.fromEntries(
    [
      "title",
      "university",
      "country",
      "degree",
      "funding",
      "eligibility",
      "deadline",
      "active",
    ]
      .filter((key) => Object.hasOwn(body, key))
      .map((key) => [key, key === "deadline" && !body[key] ? null : body[key]]),
  );
router.get(
  "/",
  run(async (req, res) => {
    const filter = available();
    // #26: filter by country, degree level, field (partial match on title/eligibility)
    if (req.query.country) filter.country = new RegExp(escapeSearch(req.query.country), 'i');
    if (req.query.degree) filter.degree = new RegExp(escapeSearch(req.query.degree), 'i');
    if (req.query.field) filter.$or = [
      { title: new RegExp(escapeSearch(req.query.field), 'i') },
      { eligibility: new RegExp(escapeSearch(req.query.field), 'i') },
    ];
    res.json(await Scholarship.find(filter).sort({ createdAt: -1 }).limit(200).lean());
  }),
);
router.get(
  "/mine",
  protect,
  authorize("student"),
  run(async (req, res) =>
    res.json(
      await Entry.find({ student: req.user._id })
        .populate("scholarship")
        .sort({ createdAt: -1 })
        .lean(),
    ),
  ),
);
router.get(
  "/manage",
  protect,
  authorize("admin"),
  run(async (req, res) =>
    res.json(await Scholarship.find().sort({ createdAt: -1 }).lean()),
  ),
);
router.get(
  "/entries",
  protect,
  authorize("admin"),
  run(async (req, res) =>
    res.json(
      await Entry.find()
        .populate("student", "name email")
        .populate("scholarship", "title")
        .sort({ createdAt: -1 })
        .limit(500)
        .lean(),
    ),
  ),
);
router.post(
  "/",
  protect,
  authorize("admin"),
  run(async (req, res) =>
    res.status(201).json(await Scholarship.create(payload(req.body))),
  ),
);
router.param("id", (req, res, next, id) => {
  if (!mongoose.isValidObjectId(id))
    return res.status(400).json({ message: "Invalid ID" });
  next();
});
router.put(
  "/:id",
  protect,
  authorize("admin"),
  run(async (req, res) => {
    const row = await Scholarship.findByIdAndUpdate(
      req.params.id,
      { $set: payload(req.body) },
      { new: true, runValidators: true },
    );
    if (!row) fail(res, 404, "Scholarship not found");
    res.json(row);
  }),
);
router.post(
  "/:id/apply",
  protect,
  authorize("student"),
  run(async (req, res) => {
    const scholarship = await Scholarship.findOne({
      _id: req.params.id,
      ...available(),
    });
    if (!scholarship) fail(res, 404, "Scholarship is closed or unavailable");
    const row = await Entry.findOneAndUpdate(
      { scholarship: scholarship._id, student: req.user._id },
      { $setOnInsert: { status: "submitted" } },
      { upsert: true, new: true },
    );
    res.json(row);
  }),
);
router.patch(
  "/:id/status",
  protect,
  authorize("admin"),
  run(async (req, res) => {
    if (
      !["submitted", "reviewing", "accepted", "rejected"].includes(
        req.body.status,
      )
    )
      fail(res, 400, "Invalid status");
    const row = await Entry.findByIdAndUpdate(
      req.params.id,
      { $set: { status: req.body.status } },
      { new: true },
    );
    if (!row) fail(res, 404, "Application not found");
    res.json(row);
  }),
);
module.exports = router;
