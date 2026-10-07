const Program = require("../models/Program");
const University = require("../models/University");
const asyncHandler = require("../utils/asyncHandler");
const { buildPaginationMeta, parsePagination } = require("../utils/queryUtils");
const { timedOperation } = require("../utils/perf");
const { clearResponseCache } = require("../utils/responseCache");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");

const getPrograms = asyncHandler(async (req, res) => {
  const requestStartedAt = Date.now();
  const query = {};
  const { page, limit, skip } = parsePagination(req.query, 12);
  const shouldPaginate = "page" in req.query || "limit" in req.query || req.query.paginate === "true";

  if (req.query.keyword) {
    query.title = { $regex: req.query.keyword, $options: "i" };
  }

  if (req.query.country) {
    const matchingUniversities = await timedOperation("programs.countryUniversityLookup", () =>
      University.find({ country: req.query.country }).select("_id").lean()
    );
    query.university = { $in: matchingUniversities.map((item) => item._id) };
  }

  if (req.query.university) {
    query.university = req.query.university;
  }

  if (req.query.degreeLevel) {
    query.degreeLevel = req.query.degreeLevel;
  }

  if (req.query.fieldOfStudy) {
    query.$or = [
      { fieldOfStudy: req.query.fieldOfStudy },
      { fieldsOfStudy: req.query.fieldOfStudy },
    ];
  }

  if (req.query.intake) {
    query.intake = req.query.intake;
  }

  if (req.query.tuitionMin || req.query.tuitionMax) {
    query.tuition = {};
    if (req.query.tuitionMin) {
      query.tuition.$gte = Number(req.query.tuitionMin);
    }
    if (req.query.tuitionMax) {
      query.tuition.$lte = Number(req.query.tuitionMax);
    }
  }

  const sortMap = {
    tuition: { tuition: 1 },
    deadline: { applicationDeadline: 1 },
    popularity: { popularity: -1 },
  };

  const listQuery = Program.find(query)
    .select("title slug degreeLevel fieldOfStudy fieldsOfStudy language duration tuition partnerTuition applicationDeadline intake summary popularity coverImage university featured createdAt")
    .populate({
      path: "university",
      select: "name slug city language ranking logo tuitionRange country featured isPartnerInstitution",
      populate: { path: "country", select: "name slug code heroImage featured" },
    })
    .sort(sortMap[req.query.sortBy] || { featured: -1, createdAt: -1 });

  if (shouldPaginate) {
    listQuery.skip(skip).limit(limit);
  }

  const [programs, total] = await Promise.all([
    timedOperation("programs.listQuery", () => listQuery.lean()),
    shouldPaginate ? timedOperation("programs.countQuery", () => Program.countDocuments(query)) : Promise.resolve(0),
  ]);

  res.set("X-Response-Time", `${Date.now() - requestStartedAt}ms`);

  if (shouldPaginate) {
    res.json({
      items: programs,
      pagination: buildPaginationMeta({ page, limit, total }),
    });
    return;
  }

  res.json(programs);
});

const getProgramById = asyncHandler(async (req, res) => {
  const program = await Program.findById(req.params.id).populate({
    path: "university",
    populate: { path: "country" },
  }).lean();

  if (!program) {
    res.status(404);
    throw new Error("Program not found");
  }

  // PRD 21: the same program at other universities, and related programs in
  // the same field. Title matching is exact (case-insensitive), not fuzzy.
  const escaped = String(program.title || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const [offeredAt, related] = await Promise.all([
    Program.find({ _id: { $ne: program._id }, title: new RegExp(`^${escaped}$`, "i") })
      .select("title degreeLevel tuition language duration university")
      .populate({ path: "university", select: "name city country", populate: { path: "country", select: "name" } })
      .limit(10).lean(),
    program.fieldOfStudy
      ? Program.find({ _id: { $ne: program._id }, fieldOfStudy: program.fieldOfStudy, title: { $not: new RegExp(`^${escaped}$`, "i") } })
        .select("title degreeLevel university").populate({ path: "university", select: "name" })
        .sort({ featured: -1, popularity: -1 }).limit(6).lean()
      : [],
  ]);

  res.json({ ...program, offeredAt, relatedPrograms: related });
});

const handleProgramWriteError = (res) => (error) => {
  if (['ValidationError', 'CastError'].includes(error.name)) res.status(400);
  if (error.code === 11000) res.status(409);
  throw error;
};

const createProgram = asyncHandler(async (req, res) => {
  let program;
  try {
    program = await Program.create(req.body);
  } catch (error) {
    if (error.code === 11000 && error.keyPattern?.slug) {
      const suffix = Math.random().toString(36).slice(2, 6);
      const base = req.body.slug || error.keyValue?.slug || "";
      const body = { ...req.body, slug: `${base}-${suffix}` };
      program = await Program.create(body).catch(handleProgramWriteError(res));
    } else {
      handleProgramWriteError(res)(error);
    }
  }
  clearResponseCache();
  res.status(201).json(program);
});

const updateProgram = asyncHandler(async (req, res) => {
  const program = await Program.findByIdAndUpdate(req.params.id, req.body, {
    new: true,
    runValidators: true,
  }).catch(handleProgramWriteError(res));

  if (!program) {
    res.status(404);
    throw new Error("Program not found");
  }

  clearResponseCache();
  res.json(program);
});

const deleteProgram = asyncHandler(async (req, res) => {
  const program = await Program.findByIdAndDelete(req.params.id);

  if (!program) {
    res.status(404);
    throw new Error("Program not found");
  }

  clearResponseCache();
  res.json({ message: "Program deleted" });
});

const uploadProgramCover = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Cover image is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/programs");
  res.status(201).json({ url: uploadResult.url });
});

module.exports = {
  getPrograms,
  getProgramById,
  createProgram,
  updateProgram,
  deleteProgram,
  uploadProgramCover,
};
