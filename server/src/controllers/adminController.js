const User = require("../models/User");
const { validPermissions, hasSection } = require("../middleware/employeeAccess");
const StudentProfile = require("../models/StudentProfile");
const Application = require("../models/Application");
const University = require("../models/University");
const Program = require("../models/Program");
const Country = require("../models/Country");
const ExhibitionArticle = require("../models/ExhibitionArticle");
const SiteSettings = require("../models/SiteSettings");
const Testimonial = require("../models/Testimonial");
const Recognition = require("../models/Recognition");
const OurService = require("../models/OurService");
const OurStory = require("../models/OurStory");
const Faq = require("../models/Faq");
const UpcomingEvent = require("../models/UpcomingEvent");
const PastEvent = require("../models/PastEvent");
const EventRegistration = require("../models/EventRegistration");
const AgencyRequest = require("../models/AgencyRequest");
const slugify = require("slugify");
const asyncHandler = require("../utils/asyncHandler");
const {
  attachResolvedSeo,
  buildExhibitionPayload: buildExhibitionSeoPayload,
} = require("../utils/exhibitionSeo");
const { clearResponseCache } = require("../utils/responseCache");
const { normalizeOptionalText, normalizeOurService } = require("../utils/text");
const { uploadFileToCloudinary } = require("../utils/uploadToCloudinary");
const {
  hydrateApplicationsWithStudentProfiles,
} = require("../utils/hydrateApplications");

const normalizeArticlePairs = (headings = [], bodies = []) => {
  const maxLength = Math.max(headings.length, bodies.length);

  return Array.from({ length: maxLength }, (_, index) => ({
    heading: String(headings[index] || "").trim(),
    body: String(bodies[index] || "").trim(),
  })).filter((item) => item.heading || item.body);
};

const buildExhibitionSections = (body) => {
  const articleItems = normalizeArticlePairs(body.articleHeadings, body.articleBodies);

  if (articleItems.length) {
    return articleItems.map((item) => ({
      title: item.heading,
      summary: "",
      body: item.body,
      titleColor: body.articleHeadingColor || "#0f172a",
      youtubeUrl: "",
    }));
  }

  if (!Array.isArray(body.sections) || body.sections.length === 0) {
    return [
      {
        title: body.title,
        summary: body.summary || "",
        body: body.body,
        titleColor: body.titleColor || "#0f172a",
        youtubeUrl: body.youtubeUrl,
      },
    ];
  }

  return body.sections
    .map((section) => ({
      title: section.title,
      summary: section.summary || "",
      body: section.body,
      titleColor: section.titleColor || "#0f172a",
      youtubeUrl: section.youtubeUrl || "",
    }))
    .filter((section) => section.title && section.body);
};

const buildExhibitionPayload = (body) => {
  const sections = buildExhibitionSections(body);
  const firstSection = sections[0] || {};
  const normalizedArticleItems = normalizeArticlePairs(body.articleHeadings, body.articleBodies);
  const fallbackArticleItems = sections
    .map((section) => ({
      heading: String(section.title || "").trim(),
      body: String(section.body || "").trim(),
    }))
    .filter((item) => item.heading || item.body);
  const articleItems = normalizedArticleItems.length ? normalizedArticleItems : fallbackArticleItems;

  return {
    title: body.title || firstSection.title,
    summary: body.summary || firstSection.summary || "",
    image: body.image || "",
    body: body.body || firstSection.body,
    articleTitle: body.articleTitle || body.title || firstSection.title || "",
    articleTitleColor: body.articleTitleColor || body.titleColor || "#0f172a",
    articleHeadingColor: body.articleHeadingColor || "#0f172a",
    articleBodyColor: body.articleBodyColor || "#475569",
    articleHeadings: articleItems.map((item) => item.heading),
    articleBodies: articleItems.map((item) => item.body),
    titleColor: body.titleColor || firstSection.titleColor || "#0f172a",
    ctaText: body.ctaText || "",
    ctaUrl: body.ctaUrl || "",
    youtubeUrl: body.youtubeUrl || firstSection.youtubeUrl,
    sections,
    featured: typeof body.featured === "boolean" ? body.featured : true,
    published: typeof body.published === "boolean" ? body.published : true,
    country: body.country || null,
  };
};

const triggerFrontendRebuild = async (reason) => {
  const deployHookUrl = String(process.env.FRONTEND_DEPLOY_HOOK_URL || "").trim();

  if (!deployHookUrl) {
    return;
  }

  try {
    await fetch(deployHookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        trigger: "article-seo-update",
        reason,
      }),
    });
  } catch (error) {
    console.error("Unable to trigger frontend rebuild", error);
  }
};

const invalidatePublicContent = () => {
  clearResponseCache();
};

const buildRecognitionSlug = async (title, currentId) => {
  const baseSlug = slugify(String(title || "recognition"), {
    lower: true,
    strict: true,
  }) || "recognition";

  let slug = baseSlug;
  let suffix = 2;

  while (
    await Recognition.exists({
      slug,
      ...(currentId ? { _id: { $ne: currentId } } : {}),
    })
  ) {
    slug = `${baseSlug}-${suffix}`;
    suffix += 1;
  }

  return slug;
};

const buildRecognitionPayload = async (body, currentRecognition = null) => {
  const title = String(body.title || currentRecognition?.title || "").trim();
  const titleChanged = title && title !== currentRecognition?.title;
  const slug =
    currentRecognition?.slug && !titleChanged
      ? currentRecognition.slug
      : await buildRecognitionSlug(title, currentRecognition?._id);

  return {
    title,
    slug,
    image: body.image || "",
    link: body.link || "",
    detailTitle: body.detailTitle || title,
    detailBody: body.detailBody || "",
    detailImage: body.detailImage || body.image || "",
    featured: typeof body.featured === "boolean" ? body.featured : true,
    sortOrder: Number.isFinite(Number(body.sortOrder)) ? Number(body.sortOrder) : 0,
  };
};

const buildOurServiceSlug = async (title, currentId) => {
  const baseSlug = slugify(String(title || "service"), {
    lower: true,
    strict: true,
  }) || "service";

  let slug = baseSlug;
  let suffix = 2;

  while (
    await OurService.exists({
      slug,
      ...(currentId ? { _id: { $ne: currentId } } : {}),
    })
  ) {
    slug = `${baseSlug}-${suffix}`;
    suffix += 1;
  }

  return slug;
};

const buildOurServicePayload = async (body, currentService = null) => {
  const numeric = {};
  for(const key of ['price','durationDays']){
    const value = body[key] === undefined ? currentService?.[key] ?? 0 : Number(body[key]);
    if(!Number.isFinite(value) || value < 0 || (key==='durationDays' && !Number.isInteger(value)))throw Object.assign(new Error(`Invalid service field: ${key}`),{statusCode:400});
    numeric[key]=value;
  }
  const journeyStage=body.journeyStage===undefined?currentService?.journeyStage || '':body.journeyStage;
  if(!['','visa','travel','housing','arrival','registration','residence'].includes(journeyStage))throw Object.assign(new Error('Invalid journey stage'),{statusCode:400});

  const details = {};
  for (const [key, limit] of Object.entries({ priceDescription: 200, estimatedDuration: 200, requirementsText: 4000, documentsText: 4000 })) {
    const value = body[key] === undefined ? currentService?.[key] || '' : body[key];
    if (typeof value !== 'string' || value.length > limit) {
      throw Object.assign(new Error(`Invalid service field: ${key}`), { statusCode: 400 });
    }
    details[key] = value.trim();
  }
  const title = normalizeOptionalText(body.title, currentService?.title || "");
  const titleChanged = title && title !== currentService?.title;
  const slug =
    currentService?.slug && !titleChanged
      ? currentService.slug
      : await buildOurServiceSlug(title, currentService?._id);

  return {
    ...details,
    ...numeric,
    journeyStage,
    title,
    slug,
    image: body.image || "",
    detailTitle: normalizeOptionalText(body.detailTitle, title),
    detailBody: normalizeOptionalText(body.detailBody),
    detailImage: body.detailImage || body.image || "",
    featured: typeof body.featured === "boolean" ? body.featured : true,
    sortOrder: Number.isFinite(Number(body.sortOrder)) ? Number(body.sortOrder) : 0,
    country: body.country || null,
  };
};

const buildPastEventSlug = async (title, currentId) => {
  const baseSlug = slugify(String(title || "event"), {
    lower: true,
    strict: true,
  }) || "event";

  let slug = baseSlug;
  let suffix = 2;

  while (
    await PastEvent.exists({
      slug,
      ...(currentId ? { _id: { $ne: currentId } } : {}),
    })
  ) {
    slug = `${baseSlug}-${suffix}`;
    suffix += 1;
  }

  return slug;
};

const buildPastEventPayload = async (body, currentEvent = null) => {
  const title = String(body.title || currentEvent?.title || "").trim();
  const titleChanged = title && title !== currentEvent?.title;
  const slug =
    currentEvent?.slug && !titleChanged
      ? currentEvent.slug
      : await buildPastEventSlug(title, currentEvent?._id);

  return {
    title,
    slug,
    category: String(body.category || currentEvent?.category || "expos-fairs").trim(),
    eventDate: body.eventDate || null,
    countryCode: String(body.countryCode || "").trim().toUpperCase(),
    summary: String(body.summary || "").trim(),
    coverImage: body.coverImage || "",
    mediaItems: Array.isArray(body.mediaItems)
      ? body.mediaItems
          .map((item) => ({
            type: item?.type === "video" ? "video" : "image",
            url: String(item?.url || "").trim(),
          }))
          .filter((item) => item.url)
      : [],
    featured: typeof body.featured === "boolean" ? body.featured : true,
    sortOrder: Number.isFinite(Number(body.sortOrder)) ? Number(body.sortOrder) : 0,
  };
};

const buildOurStoryPayload = (body) => ({
  heroEyebrow: String(body.heroEyebrow || "").trim(),
  heroTitle: String(body.heroTitle || "").trim(),
  heroBody: String(body.heroBody || "").trim(),
  heroImage: body.heroImage || "",
  heroCtaText: String(body.heroCtaText || "").trim(),
  heroCtaLink: String(body.heroCtaLink || "").trim(),
  storyEyebrow: String(body.storyEyebrow || "").trim(),
  storyTitle: String(body.storyTitle || "").trim(),
  storyBody: String(body.storyBody || "").trim(),
  storyImage: body.storyImage || "",
  missionTitle: String(body.missionTitle || "").trim(),
  missionBody: String(body.missionBody || "").trim(),
  visionTitle: String(body.visionTitle || "").trim(),
  visionBody: String(body.visionBody || "").trim(),
  foundersTitle: String(body.foundersTitle || "").trim(),
  foundersBody: String(body.foundersBody || "").trim(),
  founders: Array.isArray(body.founders)
    ? body.founders
        .map((item) => ({
          name: String(item?.name || "").trim(),
          role: String(item?.role || "").trim(),
          bio: String(item?.bio || "").trim(),
          image: item?.image || "",
        }))
        .filter((item) => item.name || item.role || item.bio || item.image)
    : [],
  timelineTitle: String(body.timelineTitle || "").trim(),
  timelineBody: String(body.timelineBody || "").trim(),
  timelineItems: Array.isArray(body.timelineItems)
    ? body.timelineItems
        .map((item, index) => ({
          year: String(item?.year || "").trim(),
          dateLabel: String(item?.dateLabel || "").trim(),
          title: String(item?.title || "").trim(),
          body: String(item?.body || "").trim(),
          image: item?.image || "",
          sortOrder: Number.isFinite(Number(item?.sortOrder)) ? Number(item.sortOrder) : index,
        }))
        .filter((item) => item.year || item.dateLabel || item.title || item.body || item.image)
    : [],
  impactTitle: String(body.impactTitle || "").trim(),
  impactBody: String(body.impactBody || "").trim(),
  impactStats: Array.isArray(body.impactStats)
    ? body.impactStats
        .map((item) => ({
          value: String(item?.value || "").trim(),
          label: String(item?.label || "").trim(),
        }))
        .filter((item) => item.value || item.label)
    : [],
  isPublished: typeof body.isPublished === "boolean" ? body.isPublished : true,
});

const getStats = asyncHandler(async (req, res) => {
  const [students, universities, programs, applications] = await Promise.all([
    User.countDocuments({ role: "student" }),
    University.countDocuments(),
    Program.countDocuments(),
    Application.countDocuments(),
  ]);

  res.json({
    students,
    universities,
    programs,
    applications,
  });
});

const getStudents = asyncHandler(async (req, res) => {
  if (req.user.role === "employee" && !hasSection(req.user, "students")) {
    return res.json(await User.find({ role: "student" }).select("name email").sort({ name: 1 }).lean());
  }
  const students = await User.find({ role: "student" }).select("-password").sort({ createdAt: -1 }).lean();
  const profiles = await StudentProfile.find({ user: { $in: students.map((student) => student._id) } }).lean();
  const profileMap = new Map(profiles.map((profile) => [String(profile.user), profile]));

  res.json(
    students.map((student) => ({
      ...student,
      profile: profileMap.get(String(student._id)) || null,
    }))
  );
});

const getAdminApplications = asyncHandler(async (req, res) => {
  const applications = await Application.find()
    .populate("student", "-password")
    .populate({
      path: "program",
      populate: { path: "university", populate: { path: "country" } },
    })
    .populate("documents")
    .populate("statusTimeline.changedBy", "name role")
    .sort({ createdAt: -1 });

  res.json(await hydrateApplicationsWithStudentProfiles(applications));
});

const getOverview = asyncHandler(async (req, res) => {
  const [stats, recentApplications, recentUsers, statusBuckets] = await Promise.all([
    Promise.all([
      User.countDocuments(),
      User.countDocuments({ role: "student" }),
      User.countDocuments({ role: "admin" }),
      User.countDocuments({ role: "partner" }),
      User.countDocuments({ isActive: false }),
      University.countDocuments(),
      Program.countDocuments(),
      Application.countDocuments(),
      Application.countDocuments({ status: "submitted" }),
      Application.countDocuments({ status: "under-review" }),
    ]),
    Application.find()
      .populate("student", "-password")
      .populate({
        path: "program",
        populate: { path: "university", populate: { path: "country" } },
      })
      .populate("documents")
      .sort({ createdAt: -1 })
      .limit(6),
    User.find().select("-password").sort({ createdAt: -1 }).limit(6),
    Application.aggregate([{ $group: { _id: "$status", count: { $sum: 1 } } }]),
  ]);

  const [
    users,
    students,
    admins,
    partners,
    inactiveUsers,
    universities,
    programs,
    applications,
    submittedApplications,
    underReviewApplications,
  ] = stats;

  res.json({
    stats: {
      users,
      students,
      admins,
      partners,
      inactiveUsers,
      universities,
      programs,
      applications,
      submittedApplications,
      underReviewApplications,
    },
    recentApplications: await hydrateApplicationsWithStudentProfiles(
      recentApplications
    ),
    recentUsers,
    applicationsByStatus: statusBuckets.reduce((accumulator, item) => {
      accumulator[item._id] = item.count;
      return accumulator;
    }, {}),
  });
});

const getUsers = asyncHandler(async (req, res) => {
  const users = await User.find().select("-password").sort({ createdAt: -1 });
  res.json(users);
});

const updateUser = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);

  if (!user) {
    res.status(404);
    throw new Error("User not found");
  }

  const { name, email, role, isActive, linkedUniversity, permissions } = req.body;
  if (role !== undefined && !User.schema.path("role").enumValues.includes(role)) {
    res.status(400);
    throw new Error("Invalid account role");
  }
  if (role === "employee" || permissions !== undefined) {
    const nextRole = role || user.role;
    if (nextRole !== "employee" || !validPermissions(permissions)) {
      res.status(400);
      throw new Error("Select valid employee sections");
    }
    user.permissions = [...new Set(permissions)];
  } else if (role && role !== "employee") {
    user.permissions = [];
  }

  if (role === "university" || linkedUniversity !== undefined) {
    const nextRole = typeof role === "string" ? role : user.role;
    const universityId = linkedUniversity !== undefined ? linkedUniversity : user.linkedUniversity?.toString();
    if (nextRole !== "university" || typeof universityId !== "string" || !/^[a-f\d]{24}$/i.test(universityId)) {
      res.status(400);
      throw new Error("A valid linked university is required for university accounts");
    }
    if (!(await University.exists({ _id: universityId }))) {
      res.status(400);
      throw new Error("Selected university does not exist");
    }
    user.linkedUniversity = universityId;
  } else if (typeof role === "string" && role !== "university") {
    user.linkedUniversity = null;
  }

  if (typeof name === "string") {
    user.name = name;
  }

  if (typeof email === "string") {
    user.email = email.toLowerCase().trim();
  }

  if (typeof role === "string") {
    user.role = role;
  }

  if (typeof isActive === "boolean") {
    user.isActive = isActive;
  }

  await user.save();

  res.json(await User.findById(user._id).select("-password"));
});

// Section-scoped account activation never accepts role or permission changes.
const updateSectionAccountStatus = asyncHandler(async (req, res) => {
  const role = req.path.startsWith("/students/") ? "student" : "partner";
  if (typeof req.body.isActive !== "boolean" || Object.keys(req.body).some((key) => key !== "isActive")) {
    res.status(400);
    throw new Error("Only isActive can be updated here");
  }
  const user = await User.findOneAndUpdate({ _id: req.params.id, role }, { isActive: req.body.isActive }, { new: true }).select("-password");
  if (!user) { res.status(404); throw new Error("Account not found in this section"); }
  res.json(user);
});

const getCountriesAdmin = asyncHandler(async (req, res) => {
  const countries = await Country.find().sort({ featured: -1, name: 1 });
  res.json(countries);
});

const buildCountryPayload = (body) => ({
  name: body.name,
  code: body.code,
  description: body.description || "",
  visaNotes: body.visaNotes || "",
  heroImage: body.heroImage || "",
  universityCount: Number.isFinite(Number(body.universityCount)) ? Number(body.universityCount) : 0,
  specialtyCount: Number.isFinite(Number(body.specialtyCount)) ? Number(body.specialtyCount) : 0,
  averageTuition: Number.isFinite(Number(body.averageTuition)) ? Number(body.averageTuition) : 0,
  articleTitle: body.articleTitle || "",
  articleTitleColor: body.articleTitleColor || "#0f172a",
  articleHeadingColor: body.articleHeadingColor || "#0f172a",
  articleBodyColor: body.articleBodyColor || "#475569",
  articleHeadings: Array.isArray(body.articleHeadings) ? body.articleHeadings : [],
  articleBodies: Array.isArray(body.articleBodies) ? body.articleBodies : [],
  featured: Boolean(body.featured),
  visaRequirements: Array.isArray(body.visaRequirements) ? body.visaRequirements : [],
  processingDays: Number.isFinite(Number(body.processingDays)) ? Number(body.processingDays) : 0,
  visaFeeUsd: Number.isFinite(Number(body.visaFeeUsd)) ? Number(body.visaFeeUsd) : 0,
  languageRequirements: Array.isArray(body.languageRequirements) ? body.languageRequirements : [],
  visaNotesList: Array.isArray(body.visaNotesList) ? body.visaNotesList : [],
});

const createCountry = asyncHandler(async (req, res) => {
  const country = await Country.create(buildCountryPayload(req.body));
  invalidatePublicContent();
  res.status(201).json(country);
});

const uploadCountryHeroImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Country cover image is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/countries");
  res.status(201).json({ url: uploadResult.url });
});

const updateCountry = asyncHandler(async (req, res) => {
  const country = await Country.findByIdAndUpdate(req.params.id, buildCountryPayload(req.body), { new: true, runValidators: true });

  if (!country) {
    res.status(404);
    throw new Error("Country not found");
  }

  invalidatePublicContent();
  res.json(country);
});

const deleteCountry = asyncHandler(async (req, res) => {
  if(await University.exists({country:req.params.id})){res.status(409);throw new Error('Country has universities and cannot be deleted');}
  const country = await Country.findByIdAndDelete(req.params.id);

  if (!country) {
    res.status(404);
    throw new Error("Country not found");
  }

  invalidatePublicContent();
  res.json({ message: "Country deleted" });
});

const getSiteSettingsAdmin = asyncHandler(async (req, res) => {
  const settings = await SiteSettings.findOne().sort({ createdAt: -1 });
  res.json(
    settings || {
      contactEmail: "",
      whatsappUrl: "",
      facebookUrl: "",
      instagramUrl: "",
      tiktokUrl: "",
      britishMembershipUrl: "",
      supportHours: "",
      officeLocations: "",
      leadCapturePromptEnabled: true,
    }
  );
});

const updateSiteSettings = asyncHandler(async (req, res) => {
  const payload = {
    contactEmail: req.body.contactEmail || "",
    whatsappUrl: req.body.whatsappUrl || "",
    facebookUrl: req.body.facebookUrl || "",
    instagramUrl: req.body.instagramUrl || "",
    tiktokUrl: req.body.tiktokUrl || "",
    britishMembershipUrl: req.body.britishMembershipUrl || "",
    supportHours: req.body.supportHours || "",
    officeLocations: req.body.officeLocations || "",
    leadCapturePromptEnabled: typeof req.body.leadCapturePromptEnabled === "boolean" ? req.body.leadCapturePromptEnabled : true,
  };

  const existingSettings = await SiteSettings.findOne().sort({ createdAt: -1 });
  const settings = existingSettings
    ? await SiteSettings.findByIdAndUpdate(existingSettings._id, payload, {
        new: true,
        runValidators: true,
      })
    : await SiteSettings.create(payload);

  invalidatePublicContent();
  res.json(settings);
});

const getTestimonialsAdmin = asyncHandler(async (req, res) => {
  const testimonials = await Testimonial.find().sort({ featured: -1, createdAt: -1 });
  res.json(testimonials);
});

const getRecognitionsAdmin = asyncHandler(async (req, res) => {
  const recognitions = await Recognition.find().sort({ featured: -1, sortOrder: 1, createdAt: -1 });
  res.json(recognitions);
});

const getFaqsAdmin = asyncHandler(async (req, res) => {
  const faqs = await Faq.find()
    .populate("country", "name code slug")
    .sort({ featured: -1, sortOrder: 1, createdAt: -1 });
  res.json(faqs);
});

const getOurServicesAdmin = asyncHandler(async (req, res) => {
  const services = await OurService.find()
    .populate("country", "name code slug")
    .sort({ featured: -1, sortOrder: 1, createdAt: -1 });
  res.json(services.map((service) => normalizeOurService(service.toObject())));
});

const getOurStoryAdmin = asyncHandler(async (req, res) => {
  const story = await OurStory.findOne().sort({ updatedAt: -1, createdAt: -1 });
  res.json(
    story || {
      heroEyebrow: "",
      heroTitle: "",
      heroBody: "",
      heroImage: "",
      heroCtaText: "",
      heroCtaLink: "",
      storyEyebrow: "",
      storyTitle: "",
      storyBody: "",
      storyImage: "",
      missionTitle: "",
      missionBody: "",
      visionTitle: "",
      visionBody: "",
      foundersTitle: "",
      foundersBody: "",
      founders: [],
      timelineTitle: "",
      timelineBody: "",
      timelineItems: [],
      impactTitle: "",
      impactBody: "",
      impactStats: [],
      isPublished: false,
    }
  );
});

const getExhibitionArticlesAdmin = asyncHandler(async (req, res) => {
  const articles = await ExhibitionArticle.find()
    .populate("country", "name code slug")
    .sort({ featured: -1, createdAt: -1 })
    .lean();
  res.json(articles.map(attachResolvedSeo));
});

const getUpcomingEventAdmin = asyncHandler(async (req, res) => {
  const upcomingEvent = await UpcomingEvent.findOne().sort({ updatedAt: -1, createdAt: -1 });
  res.json(
    upcomingEvent || {
      title: "",
      subtitle: "",
      eventType: "",
      eventDate: null,
      ctaText: "",
      backgroundImage: "",
      isPublished: false,
    }
  );
});

const getPastEventsAdmin = asyncHandler(async (req, res) => {
  const events = await PastEvent.find().sort({ sortOrder: 1, eventDate: -1, createdAt: -1 });
  res.json(events);
});

const getEventRegistrationsAdmin = asyncHandler(async (req, res) => {
  const registrations = await EventRegistration.find()
    .populate("upcomingEvent", "title eventDate")
    .sort({ createdAt: -1 });
  res.json(registrations);
});

const getAgencyRequestsAdmin = asyncHandler(async (req, res) => {
  const agencyRequests = await AgencyRequest.find()
    .populate("student", "name email role createdAt")
    .populate("reviewedBy", "name email role")
    .sort({ submittedAt: -1, createdAt: -1 });

  res.json(agencyRequests);
});

const updateAgencyRequestStatus = asyncHandler(async (req, res) => {
  const agencyRequest = await AgencyRequest.findById(req.params.id).populate("student");

  if (!agencyRequest) {
    res.status(404);
    throw new Error("Agency request not found");
  }

  const nextStatus = String(req.body.status || "").trim();

  if (!["pending", "approved", "rejected"].includes(nextStatus)) {
    res.status(400);
    throw new Error("Invalid agency request status");
  }

  agencyRequest.status = nextStatus;
  agencyRequest.adminNote = String(req.body.adminNote || "").trim();
  agencyRequest.reviewedAt = nextStatus === "pending" ? undefined : new Date();
  agencyRequest.reviewedBy = nextStatus === "pending" ? undefined : req.user._id;

  if (agencyRequest.student && ["student", "partner"].includes(agencyRequest.student.role)) {
    if (nextStatus === "approved") {
      agencyRequest.student.role = "partner";
      await agencyRequest.student.save();
    } else if (nextStatus === "rejected" && agencyRequest.student.role !== "admin") {
      agencyRequest.student.role = "student";
      await agencyRequest.student.save();
    }
  }

  await agencyRequest.save();

  res.json(
    await AgencyRequest.findById(agencyRequest._id)
      .populate("student", "name email role createdAt")
      .populate("reviewedBy", "name email role")
  );
});

const createTestimonial = asyncHandler(async (req, res) => {
  const testimonial = await Testimonial.create(req.body);
  invalidatePublicContent();
  res.status(201).json(testimonial);
});

const createRecognition = asyncHandler(async (req, res) => {
  const recognition = await Recognition.create(await buildRecognitionPayload(req.body));
  invalidatePublicContent();
  res.status(201).json(recognition);
});

const createFaq = asyncHandler(async (req, res) => {
  const faq = await Faq.create({
    question: req.body.question,
    answer: req.body.answer,
    featured: typeof req.body.featured === "boolean" ? req.body.featured : true,
    sortOrder: Number.isFinite(Number(req.body.sortOrder)) ? Number(req.body.sortOrder) : 0,
    country: req.body.country || null,
  });

  invalidatePublicContent();
  const populatedFaq = await Faq.findById(faq._id).populate("country", "name code slug");
  res.status(201).json(populatedFaq);
});

const createOurService = asyncHandler(async (req, res) => {
  const service = await OurService.create(await buildOurServicePayload(req.body));
  invalidatePublicContent();
  res.status(201).json(normalizeOurService(service.toObject()));
});

const upsertOurStory = asyncHandler(async (req, res) => {
  const payload = buildOurStoryPayload(req.body);
  const existingStory = await OurStory.findOne().sort({ updatedAt: -1, createdAt: -1 });

  if (!existingStory) {
    const createdStory = await OurStory.create(payload);
    invalidatePublicContent();
    res.status(201).json(createdStory);
    return;
  }

  existingStory.set(payload);
  await existingStory.save();
  invalidatePublicContent();
  res.json(existingStory);
});

const createExhibitionArticle = asyncHandler(async (req, res) => {
  const payload = {
    ...buildExhibitionPayload(req.body),
    ...(await buildExhibitionSeoPayload(req.body)),
  };
  const article = await ExhibitionArticle.create(payload);
  invalidatePublicContent();
  await triggerFrontendRebuild(`create:${article.slug}`);
  res.status(201).json(attachResolvedSeo(article.toObject()));
});

const upsertUpcomingEvent = asyncHandler(async (req, res) => {
  const payload = {
    title: String(req.body.title || "").trim(),
    subtitle: String(req.body.subtitle || "").trim(),
    eventType: String(req.body.eventType || "").trim(),
    eventDate: req.body.eventDate || null,
    ctaText: String(req.body.ctaText || "").trim(),
    backgroundImage: req.body.backgroundImage || "",
    isPublished: typeof req.body.isPublished === "boolean" ? req.body.isPublished : true,
  };

  const existingEvent = await UpcomingEvent.findOne().sort({ updatedAt: -1, createdAt: -1 });

  if (!existingEvent) {
    const createdEvent = await UpcomingEvent.create(payload);
    invalidatePublicContent();
    res.status(201).json(createdEvent);
    return;
  }

  existingEvent.set(payload);
  await existingEvent.save();
  invalidatePublicContent();
  res.json(existingEvent);
});

const createPastEvent = asyncHandler(async (req, res) => {
  const event = await PastEvent.create(await buildPastEventPayload(req.body));
  invalidatePublicContent();
  res.status(201).json(event);
});

const updateTestimonial = asyncHandler(async (req, res) => {
  const testimonial = await Testimonial.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });

  if (!testimonial) {
    res.status(404);
    throw new Error("Testimonial not found");
  }

  invalidatePublicContent();
  res.json(testimonial);
});

const updateRecognition = asyncHandler(async (req, res) => {
  const currentRecognition = await Recognition.findById(req.params.id);

  if (!currentRecognition) {
    res.status(404);
    throw new Error("Recognition not found");
  }

  const recognition = await Recognition.findByIdAndUpdate(
    req.params.id,
    await buildRecognitionPayload(req.body, currentRecognition),
    { new: true, runValidators: true }
  );

  if (!recognition) {
    res.status(404);
    throw new Error("Recognition not found");
  }

  invalidatePublicContent();
  res.json(recognition);
});

const updateFaq = asyncHandler(async (req, res) => {
  const faq = await Faq.findByIdAndUpdate(
    req.params.id,
    {
      question: req.body.question,
      answer: req.body.answer,
      featured: Boolean(req.body.featured),
      sortOrder: Number.isFinite(Number(req.body.sortOrder)) ? Number(req.body.sortOrder) : 0,
      country: req.body.country || null,
    },
    { new: true, runValidators: true }
  ).populate("country", "name code slug");

  if (!faq) {
    res.status(404);
    throw new Error("FAQ not found");
  }

  invalidatePublicContent();
  res.json(faq);
});

const updateOurService = asyncHandler(async (req, res) => {
  const currentService = await OurService.findById(req.params.id);

  if (!currentService) {
    res.status(404);
    throw new Error("Service not found");
  }

  const service = await OurService.findByIdAndUpdate(
    req.params.id,
    await buildOurServicePayload(req.body, currentService),
    { new: true, runValidators: true }
  );

  if (!service) {
    res.status(404);
    throw new Error("Service not found");
  }

  invalidatePublicContent();
  res.json(normalizeOurService(service.toObject()));
});

const updateExhibitionArticle = asyncHandler(async (req, res) => {
  const currentArticle = await ExhibitionArticle.findById(req.params.id);

  if (!currentArticle) {
    res.status(404);
    throw new Error("Exhibition article not found");
  }

  const payload = {
    ...buildExhibitionPayload(req.body),
    ...(await buildExhibitionSeoPayload(req.body, currentArticle)),
  };
  const article = await ExhibitionArticle.findByIdAndUpdate(req.params.id, payload, { new: true, runValidators: true });

  if (!article) {
    res.status(404);
    throw new Error("Exhibition article not found");
  }

  invalidatePublicContent();
  await triggerFrontendRebuild(`update:${article.slug}`);
  res.json(attachResolvedSeo(article.toObject()));
});

const updatePastEvent = asyncHandler(async (req, res) => {
  const currentEvent = await PastEvent.findById(req.params.id);

  if (!currentEvent) {
    res.status(404);
    throw new Error("Past event not found");
  }

  const event = await PastEvent.findByIdAndUpdate(
    req.params.id,
    await buildPastEventPayload(req.body, currentEvent),
    { new: true, runValidators: true }
  );

  invalidatePublicContent();
  res.json(event);
});

const deleteTestimonial = asyncHandler(async (req, res) => {
  const testimonial = await Testimonial.findByIdAndDelete(req.params.id);

  if (!testimonial) {
    res.status(404);
    throw new Error("Testimonial not found");
  }

  invalidatePublicContent();
  res.json({ message: "Testimonial deleted" });
});

const deleteRecognition = asyncHandler(async (req, res) => {
  const recognition = await Recognition.findByIdAndDelete(req.params.id);

  if (!recognition) {
    res.status(404);
    throw new Error("Recognition not found");
  }

  invalidatePublicContent();
  res.json({ message: "Recognition deleted" });
});

const deleteFaq = asyncHandler(async (req, res) => {
  const faq = await Faq.findByIdAndDelete(req.params.id);

  if (!faq) {
    res.status(404);
    throw new Error("FAQ not found");
  }

  invalidatePublicContent();
  res.json({ message: "FAQ deleted" });
});

const deleteOurService = asyncHandler(async (req, res) => {
  if(await require('../models/ServiceRequest').exists({service:req.params.id}))return res.status(409).json({message:'لا يمكن حذف خدمة مرتبطة بطلبات؛ يمكنك تعديلها.'});

  const service = await OurService.findByIdAndDelete(req.params.id);

  if (!service) {
    res.status(404);
    throw new Error("Service not found");
  }

  invalidatePublicContent();
  res.json({ message: "Service deleted" });
});

const uploadTestimonialAvatar = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Testimonial avatar is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/testimonials");
  res.status(201).json({ url: uploadResult.url });
});

const uploadRecognitionImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Recognition image is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/recognitions");
  res.status(201).json({ url: uploadResult.url });
});

const uploadOurServiceImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Service image is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/services");
  res.status(201).json({ url: uploadResult.url });
});

const uploadOurStoryImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Story image is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/our-story");
  res.status(201).json({ url: uploadResult.url });
});

const uploadExhibitionImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Exhibition image is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/exhibitions");
  res.status(201).json({ url: uploadResult.url });
});

const uploadUpcomingEventImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Upcoming event image is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/events/upcoming");
  res.status(201).json({ url: uploadResult.url });
});

const uploadPastEventMedia = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error("Past event media file is required");
  }

  const uploadResult = await uploadFileToCloudinary(req.file, "study-birds/events/past");
  const mediaType = req.file.mimetype.startsWith("video/") ? "video" : "image";
  res.status(201).json({ url: uploadResult.url, type: mediaType });
});

const deleteExhibitionArticle = asyncHandler(async (req, res) => {
  const article = await ExhibitionArticle.findByIdAndDelete(req.params.id);

  if (!article) {
    res.status(404);
    throw new Error("Exhibition article not found");
  }

  invalidatePublicContent();
  await triggerFrontendRebuild(`delete:${article.slug}`);
  res.json({ message: "Exhibition article deleted" });
});

const deletePastEvent = asyncHandler(async (req, res) => {
  const event = await PastEvent.findByIdAndDelete(req.params.id);

  if (!event) {
    res.status(404);
    throw new Error("Past event not found");
  }

  invalidatePublicContent();
  res.json({ message: "Past event deleted" });
});

const getMyKpis = asyncHandler(async (req, res) => {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const userId = req.user._id;

  const [processedThisMonth, totalProcessed, teamStats] = await Promise.all([
    Application.countDocuments({
      'statusTimeline': {
        $elemMatch: {
          changedBy: userId,
          changedAt: { $gte: startOfMonth },
        },
      },
    }),
    Application.countDocuments({
      'statusTimeline.changedBy': userId,
    }),
    req.user.role === 'admin' || req.user.employeeRole === 'super_admin'
      ? Application.aggregate([
          { $unwind: '$statusTimeline' },
          {
            $match: {
              'statusTimeline.changedAt': { $gte: startOfMonth },
              'statusTimeline.changedBy': { $ne: null },
            },
          },
          {
            $group: {
              _id: '$statusTimeline.changedBy',
              count: { $sum: 1 },
            },
          },
          { $sort: { count: -1 } },
          { $limit: 10 },
          {
            $lookup: {
              from: 'users',
              localField: '_id',
              foreignField: '_id',
              as: 'user',
            },
          },
          { $unwind: '$user' },
          {
            $project: {
              name: '$user.name',
              employeeRole: '$user.employeeRole',
              count: 1,
            },
          },
        ])
      : Promise.resolve(null),
  ]);

  res.json({
    processedThisMonth,
    totalProcessed,
    teamStats,
    month: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`,
  });
});

module.exports = {
  getMyKpis,
  updateSectionAccountStatus,
  getOverview,
  getStats,
  getStudents,
  getAdminApplications,
  getUsers,
  updateUser,
  getCountriesAdmin,
  createCountry,
  uploadCountryHeroImage,
  updateCountry,
  deleteCountry,
  getSiteSettingsAdmin,
  updateSiteSettings,
  getTestimonialsAdmin,
  getRecognitionsAdmin,
  getOurServicesAdmin,
  getOurStoryAdmin,
  getFaqsAdmin,
  getExhibitionArticlesAdmin,
  getUpcomingEventAdmin,
  getPastEventsAdmin,
  getEventRegistrationsAdmin,
  getAgencyRequestsAdmin,
  createTestimonial,
  uploadTestimonialAvatar,
  createRecognition,
  createOurService,
  upsertOurStory,
  createFaq,
  createExhibitionArticle,
  upsertUpcomingEvent,
  createPastEvent,
  updateTestimonial,
  updateRecognition,
  updateOurService,
  updateFaq,
  updateExhibitionArticle,
  updatePastEvent,
  updateAgencyRequestStatus,
  deleteTestimonial,
  deleteRecognition,
  deleteOurService,
  deleteFaq,
  deleteExhibitionArticle,
  deletePastEvent,
  uploadRecognitionImage,
  uploadOurServiceImage,
  uploadOurStoryImage,
  uploadExhibitionImage,
  uploadUpcomingEventImage,
  uploadPastEventMedia,
};
