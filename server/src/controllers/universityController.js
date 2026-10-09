const University = require("../models/University");
const asyncHandler = require("../utils/asyncHandler");
const { buildPaginationMeta, parsePagination } = require("../utils/queryUtils");
const { timedOperation } = require("../utils/perf");
const { clearResponseCache } = require("../utils/responseCache");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");

const buildUniversityPayload = (body) => ({
  name: body.name,
  country: body.country,
  city: body.city || "",
  language: body.language || "",
  studentCount: Number.isFinite(Number(body.studentCount)) ? Number(body.studentCount) : 0,
  specialtyCount: Number.isFinite(Number(body.specialtyCount)) ? Number(body.specialtyCount) : 0,
  ranking: Number.isFinite(Number(body.ranking)) ? Number(body.ranking) : undefined,
  overview: body.overview || "",
  articleTitle: body.articleTitle || "",
  articleTitleColor: body.articleTitleColor || "#0f172a",
  articleHeadingColor: body.articleHeadingColor || "#0f172a",
  articleBodyColor: body.articleBodyColor || "#475569",
  articleHeadings: Array.isArray(body.articleHeadings) ? body.articleHeadings : [],
  articleBodies: Array.isArray(body.articleBodies) ? body.articleBodies : [],
  featured: Boolean(body.featured),
  isPartnerInstitution: Boolean(body.isPartnerInstitution),
  logo: body.logo || "",
  campusImages: Array.isArray(body.campusImages) ? body.campusImages : [],
  tuitionRange: {
    min: Number.isFinite(Number(body.tuitionRange?.min)) ? Number(body.tuitionRange.min) : undefined,
    max: Number.isFinite(Number(body.tuitionRange?.max)) ? Number(body.tuitionRange.max) : undefined,
  },
});

const getUniversities = asyncHandler(async (req, res) => {
  const requestStartedAt = Date.now();
  const query = {};
  const { page, limit, skip } = parsePagination(req.query, 12);
  const shouldPaginate = "page" in req.query || "limit" in req.query || req.query.paginate === "true";

  if (req.query.country) {
    query.country = req.query.country;
  }

  if (req.query.featured) {
    query.featured = req.query.featured === "true";
  }

  const listQuery = University.find(query)
    .select(
      "name slug city language studentCount specialtyCount overview ranking tuitionRange logo campusImages articleTitle articleTitleColor articleHeadingColor articleBodyColor articleHeadings articleBodies featured isPartnerInstitution country createdAt"
    )
    .populate("country", "name slug code heroImage featured")
    .sort({ featured: -1, name: 1 });

  if (shouldPaginate) {
    listQuery.skip(skip).limit(limit);
  }

  const [universities, total] = await Promise.all([
    timedOperation("universities.listQuery", () => listQuery.lean()),
    shouldPaginate ? timedOperation("universities.countQuery", () => University.countDocuments(query)) : Promise.resolve(0),
  ]);

  res.set("X-Response-Time", `${Date.now() - requestStartedAt}ms`);

  if (shouldPaginate) {
    res.json({
      items: universities,
      pagination: buildPaginationMeta({ page, limit, total }),
    });
    return;
  }

  res.json(universities);
});

const getUniversityById = asyncHandler(async (req, res) => {
  const university = await University.findById(req.params.id).populate("country").lean();

  if (!university) {
    res.status(404);
    throw new Error("University not found");
  }

  res.json(university);
});

const createUniversity = asyncHandler(async (req, res) => {
  const university = await University.create(buildUniversityPayload(req.body));
  clearResponseCache();
  res.status(201).json(university);
});

const updateUniversity = asyncHandler(async (req, res) => {
  const university = await University.findByIdAndUpdate(req.params.id, buildUniversityPayload(req.body), {
    new: true,
  });

  if (!university) {
    res.status(404);
    throw new Error("University not found");
  }

  clearResponseCache();
  res.json(university);
});

const deleteUniversity = asyncHandler(async (req, res) => {
  if (await require('../models/Program').exists({university:req.params.id}) || await require('../models/Application').exists({university:req.params.id})) {
    res.status(409); throw new Error('University has programs or applications and cannot be deleted');
  }
  const university = await University.findByIdAndDelete(req.params.id);

  if (!university) {
    res.status(404);
    throw new Error("University not found");
  }

  clearResponseCache();
  res.json({ message: "University deleted" });
});

const uploadUniversityImages = asyncHandler(async (req, res) => {
  if (!req.files?.length) {
    res.status(400);
    throw new Error("At least one image is required");
  }

  const uploads = await Promise.all(
    req.files.map((file) => uploadFileToCloudinary(file, "study-birds/universities"))
  );
  const urls = uploads.map((item) => item.url);
  res.status(201).json({ urls });
});

module.exports = {
  getUniversities,
  getUniversityById,
  createUniversity,
  updateUniversity,
  deleteUniversity,
  uploadUniversityImages,
};
