const StudentProfile = require("../models/StudentProfile");
const { applicationStatusInfo, documentStatusInfo } = require("../constants/statusCatalog");

const buildApplicantProfile = (application, studentProfile) => {
  const existingProfile = application.applicantProfile || {};
  const existingEnglishTest = existingProfile.englishTest || {};
  const profileEnglishTest = studentProfile?.englishTest || {};
  const student = application.student || {};

  return {
    name: existingProfile.name || student.name || "",
    email: existingProfile.email || student.email || "",
    phone: existingProfile.phone || studentProfile?.phone || "",
    dateOfBirth: existingProfile.dateOfBirth || studentProfile?.dateOfBirth || null,
    nationality: existingProfile.nationality || studentProfile?.nationality || "",
    currentEducation:
      existingProfile.currentEducation || studentProfile?.currentEducation || "",
    gpa: existingProfile.gpa || studentProfile?.gpa || "",
    intake: existingProfile.intake || studentProfile?.intake || "",
    address: existingProfile.address || studentProfile?.address || "",
    englishTest: {
      exam: existingEnglishTest.exam || profileEnglishTest.exam || "",
      score: existingEnglishTest.score || profileEnglishTest.score || "",
    },
  };
};

const buildCurrentStudentProfile = (application, studentProfile) => {
  const profileEnglishTest = studentProfile?.englishTest || {};
  const student = application.student || {};

  return {
    name: student.name || "",
    email: student.email || "",
    phone: studentProfile?.phone || "",
    dateOfBirth: studentProfile?.dateOfBirth || null,
    nationality: studentProfile?.nationality || "",
    currentEducation: studentProfile?.currentEducation || "",
    gpa: studentProfile?.gpa || "",
    intake: studentProfile?.intake || "",
    address: studentProfile?.address || "",
    englishTest: {
      exam: profileEnglishTest.exam || "",
      score: profileEnglishTest.score || "",
    },
  };
};

const getStudentId = (application) => {
  if (!application?.student) {
    return "";
  }

  if (typeof application.student === "string") {
    return application.student;
  }

  if (application.student._id) {
    return String(application.student._id);
  }

  return String(application.student);
};

const toPlainObject = (application) =>
  typeof application?.toObject === "function" ? application.toObject() : application;

const hydrateApplicationsWithStudentProfiles = async (applications) => {
  const list = Array.isArray(applications)
    ? applications.filter(Boolean)
    : applications
      ? [applications]
      : [];

  if (!list.length) {
    return Array.isArray(applications) ? [] : null;
  }

  const studentIds = [...new Set(list.map(getStudentId).filter(Boolean))];
  const studentProfiles = await StudentProfile.find({
    user: { $in: studentIds },
  }).lean();

  const profileByUserId = new Map(
    studentProfiles.map((profile) => [String(profile.user), profile])
  );

  const hydrated = list.map((application) => {
    const plainApplication = toPlainObject(application);
    const studentId = getStudentId(plainApplication);
    const studentProfile = profileByUserId.get(studentId);

    return {
      ...plainApplication,
      // Plain-language status copy for every screen (see constants/statusCatalog.js).
      statusInfo: applicationStatusInfo(plainApplication),
      ...(Array.isArray(plainApplication.documents) ? {
        // Internal review history (staff ids) stays on the admin documents page.
        documents: plainApplication.documents.map((document) => {
          if (!document || typeof document !== "object" || !document.type) return document;
          const { reviewHistory, reviewedBy, ...visible } = document;
          return { ...require('../models/Document').clientView(visible), statusInfo: documentStatusInfo(document) };
        }),
      } : {}),
      applicantProfile: buildApplicantProfile(plainApplication, studentProfile),
      studentProfile: buildCurrentStudentProfile(plainApplication, studentProfile),
    };
  });

  return Array.isArray(applications) ? hydrated : hydrated[0];
};

module.exports = {
  hydrateApplicationsWithStudentProfiles,
};
