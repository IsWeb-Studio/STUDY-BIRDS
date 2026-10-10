const StudyField = require("../models/StudyField");
const asyncHandler = require("../utils/asyncHandler");
const { clearResponseCache } = require("../utils/responseCache");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");

const studyFieldSort = { featured: -1, sortOrder: 1, createdAt: -1, name: 1 };

const getStudyFields = asyncHandler(async (req, res) => {
  const studyFields = await StudyField.find().sort(studyFieldSort);
  res.json(studyFields);
});

const createStudyField = asyncHandler(async (req, res) => {
  const studyField = await StudyField.create({
    name: req.body.name,
    description: req.body.description || "",
    image: req.body.image || "",
    featured: typeof req.body.featured === "boolean" ? req.body.featured : true,
    sortOrder: Number.isFinite(Number(req.body.sortOrder)) ? Number(req.body.sortOrder) : 0,
  });

  clearResponseCache();
  res.status(201).json(studyField);
});

const updateStudyField = asyncHandler(async (req, res) => {
  const studyField = await StudyField.findByIdAndUpdate(
    req.params.id,
    {
      name: req.body.name,
      description: req.body.description || "",
      image: req.body.image || "",
      featured: Boolean(req.body.featured),
      sortOrder: Number.isFinite(Number(req.body.sortOrder)) ? Number(req.body.sortOrder) : 0,
    },
    { new: true, runValidators: true }
  );

  if (!studyField) {
    res.status(404);
    throw new Error("Study field not found");
  }

  clearResponseCache();
  res.json(studyField);
});

const deleteStudyField = asyncHandler(async (req, res) => {
  const existing=await StudyField.findById(req.params.id);
  if(existing && (await require('../models/Program').exists({$or:[{fieldOfStudy:existing.name},{fieldsOfStudy:existing.name}]}) || await require('../models/CommunityPost').exists({studyField:existing._id}))){res.status(409);throw new Error('Study field is in use and cannot be deleted');}
  const studyField = await StudyField.findByIdAndDelete(req.params.id);

  if (!studyField) {
    res.status(404);
    throw new Error("Study field not found");
  }

  clearResponseCache();
  res.json({ message: "Study field deleted" });
});

const uploadStudyFieldImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Study field image is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/study-fields");
  res.status(201).json({ url: uploadResult.url });
});

module.exports = {
  getStudyFields,
  createStudyField,
  updateStudyField,
  deleteStudyField,
  uploadStudyFieldImage,
};
