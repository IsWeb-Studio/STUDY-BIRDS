import { createContext, useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { SITE_NAME } from "../seo/site";
import { repairMojibake } from "../utils/textCodec";

export type Language = "en" | "ar";

type TranslationKey =
  | "about"
  | "accepted"
  | "activeReviews"
  | "address"
  | "admin"
  | "allCountries"
  | "allDegreeLevels"
  | "allFields"
  | "allIntakes"
  | "allUniversities"
  | "applications"
  | "applyOnline"
  | "authFailed"
  | "contact"
  | "country"
  | "createAccount"
  | "creatingAccount"
  | "createProfile"
  | "currentEducation"
  | "dashboard"
  | "deadline"
  | "degreeBachelor"
  | "degreeDiploma"
  | "degreeMaster"
  | "degreeTechnicalInstitute"
  | "degreePostgraduateDiploma"
  | "degreeNonThesisMaster"
  | "degreeThesisMaster"
  | "degreeProfessionalDoctorate"
  | "degreePhD"
  | "degreePostdoctoral"
  | "destinations"
  | "documents"
  | "email"
  | "fieldBusiness"
  | "fieldEngineering"
  | "fieldSocialSciences"
  | "fieldTechnology"
  | "explore"
  | "exploreProgram"
  | "explorePrograms"
  | "featured"
  | "featuredDestinations"
  | "featuredUniversities"
  | "fieldOfStudy"
  | "findBestProgram"
  | "flyBeyondBorders"
  | "forgotPassword"
  | "gpa"
  | "heroSubtitle"
  | "heroTitle"
  | "heroStep1"
  | "heroStep2"
  | "heroStep3"
  | "heroStep4"
  | "heroStatAdmissionsTitle"
  | "heroStatAdmissionsBody"
  | "heroStatWorkspaceTitle"
  | "heroStatWorkspaceBody"
  | "heroPlanningCaption"
  | "heroDocumentsCaption"
  | "howItWorks"
  | "intake"
  | "intakeFall2026"
  | "intakeSpring2027"
  | "language"
  | "login"
  | "loginPrompt"
  | "logout"
  | "markStatus"
  | "maxTuition"
  | "minTuition"
  | "myApplications"
  | "name"
  | "nationality"
  | "noDocuments"
  | "noDocumentsDescription"
  | "noPrograms"
  | "noProgramsDescription"
  | "notifications"
  | "overview"
  | "partner"
  | "partnerPrice"
  | "password"
  | "phone"
  | "preferredIntake"
  | "programs"
  | "popularity"
  | "ranking"
  | "recentApplications"
  | "register"
  | "registerPrompt"
  | "requirements"
  | "role"
  | "saveProfile"
  | "searchKeyword"
  | "searchProgramsTitle"
  | "sortByFeatured"
  | "startJourney"
  | "statusAccepted"
  | "statusDraft"
  | "statusRejected"
  | "statusSubmitted"
  | "statusUnderReview"
  | "statusPreliminaryAccepted"
  | "statusPreliminaryAcceptedFirstPayment"
  | "statusFinalAccepted"
  | "statusFileCompletedAccepted"
  | "statusFileCompletedRejected"
  | "step"
  | "student"
  | "studentStories"
  | "studentProfile"
  | "students"
  | "studentsHelped"
  | "submitApplication"
  | "submitApplicationNote"
  | "submitApplicationSuccess"
  | "submitApplicationLoginRequired"
  | "submitting"
  | "submitYourApplication"
  | "testimonialsTitle"
  | "trackAdmission"
  | "tuition"
  | "university"
  | "universities"
  | "viewUniversity"
  | "uploadDocument"
  | "uploadedDocuments"
  | "yes"
  | "no"
  | "aboutBody"
  | "aboutTitle"
  | "city"
  | "contactBody"
  | "contactTitle"
  | "ctaDescription"
  | "destinationsTitle"
  | "forgotPasswordBody"
  | "guidedPath"
  | "homeJourneyIntro"
  | "homePlanningTitle"
  | "homePlanningBody"
  | "homeDocumentsTitle"
  | "homeDocumentsBody"
  | "homeExperienceEyebrow"
  | "homeExperienceTitle"
  | "homeExperienceBody"
  | "recognitionsEyebrow"
  | "recognitionsTitle"
  | "recognitionsBody"
  | "viewRecognition"
  | "servicesEyebrow"
  | "servicesTitle"
  | "servicesBody"
  | "faqEyebrow"
  | "faqTitle"
  | "faqBody"
  | "studyFieldsEyebrow"
  | "studyFieldsTitle"
  | "studyFieldsBody"
  | "studyFieldBadge"
  | "destinationBadge"
  | "destinationCta"
  | "universityBadge"
  | "exhibitions"
  | "notFoundBody"
  | "notFoundTitle"
  | "offices"
  | "officeLocationsLabel"
  | "partnerBody"
  | "partnerInstitutions"
  | "partnerStatus"
  | "partnerTitle"
  | "readyNextChapter"
  | "returnHome"
  | "signingIn"
  | "studyDestinations"
  | "supportHours"
  | "supportHoursLabel"
  | "universitiesTitle"
  | "footerBody"
  | "welcomeBack";

const translations: Record<Language, Record<TranslationKey, string>> = {
  en: {
    about: "About",
    accepted: "Accepted",
    activeReviews: "Active Reviews",
    address: "Address",
    admin: "Admin",
    allCountries: "All countries",
    allDegreeLevels: "All degree levels",
    allFields: "All fields",
    allIntakes: "All intakes",
    allUniversities: "All universities",
    applications: "Applications",
    applyOnline: "Apply online",
    authFailed: "Authentication failed. Please check your details and try again.",
    contact: "Contact",
    country: "Country",
    createAccount: "Create your account",
    creatingAccount: "Creating account...",
    createProfile: "Create your profile",
    currentEducation: "Current education",
    dashboard: "Dashboard",
    deadline: "Deadline",
    degreeBachelor: "Bachelor",
    degreeDiploma: "Diploma",
    degreeMaster: "Master",
    degreeTechnicalInstitute: "Technical institute",
    degreePostgraduateDiploma: "Postgraduate diploma",
    degreeNonThesisMaster: "Master without thesis",
    degreeThesisMaster: "Master with thesis",
    degreeProfessionalDoctorate: "Professional doctorate",
    degreePhD: "Academic doctorate (PhD)",
    degreePostdoctoral: "Postdoctoral studies",
    destinations: "Destinations",
    documents: "Documents",
    email: "Email",
    fieldBusiness: "Business",
    fieldEngineering: "Engineering",
    fieldSocialSciences: "Social Sciences",
    fieldTechnology: "Technology",
    explore: "Explore",
    exploreProgram: "Explore program",
    explorePrograms: "Find Your Major",
    featured: "Featured",
    featuredDestinations: "Countries our students explore most",
    featuredUniversities: "Universities recommended on Study Birds",
    fieldOfStudy: "Field of study",
    findBestProgram: "Find the program that fits your goals",
    flyBeyondBorders: "Study Abroad Starts Here",
    forgotPassword: "Forgot password",
    gpa: "GPA",
    heroSubtitle:
      "Study Birds helps you discover universities, compare tuition and programs, and move from inquiry to application in one clear place.",
    heroTitle: "Plan your study abroad journey with Study Birds",
    heroStep1: "Choose the right country and university",
    heroStep2: "Compare programs, tuition, and intakes",
    heroStep3: "Prepare your profile and required documents",
    heroStep4: "Apply and follow every update",
    heroStatAdmissionsTitle: "Clearer admissions",
    heroStatAdmissionsBody: "Structured guidance, easier follow-up, and a smoother path to applying.",
    heroStatWorkspaceTitle: "One student space",
    heroStatWorkspaceBody: "Programs, documents, applications, and updates organized together.",
    heroPlanningCaption: "A clearer planning stage",
    heroDocumentsCaption: "Documents prepared with ease",
    howItWorks: "How Study Birds works",
    intake: "Intake",
    intakeFall2026: "Fall 2026",
    intakeSpring2027: "Spring 2027",
    language: "العربية",
    login: "Log In",
    loginPrompt: "Already have an account?",
    logout: "Logout",
    markStatus: "Mark",
    maxTuition: "Max tuition",
    minTuition: "Min tuition",
    myApplications: "My applications",
    name: "Full name",
    nationality: "Nationality",
    noDocuments: "No documents yet",
    noDocumentsDescription: "Upload your study documents to prepare your applications.",
    noPrograms: "No programs matched",
    noProgramsDescription: "Try adjusting your search filters to explore more options.",
    notifications: "Notifications",
    overview: "Overview",
    partner: "Partner",
    partnerPrice: "Partner price",
    password: "Password",
    phone: "Phone",
    preferredIntake: "Preferred intake",
    programs: "Programs",
    popularity: "Popularity",
    ranking: "Ranking",
    recentApplications: "Recent applications",
    register: "Register",
    registerPrompt: "Do not have an account?",
    requirements: "Requirements",
    role: "Role",
    saveProfile: "Save profile",
    searchKeyword: "Search by keyword",
    searchProgramsTitle: "Search programs that match your goals",
    sortByFeatured: "Sort by featured",
    startJourney: "Start with Study Birds",
    statusAccepted: "Accepted",
    statusDraft: "Draft",
    statusRejected: "Rejected",
    statusSubmitted: "Submitted",
    statusUnderReview: "Under review",
    statusPreliminaryAccepted: "Preliminary acceptance completed",
    statusPreliminaryAcceptedFirstPayment: "Preliminary acceptance completed and first expenses payment received",
    statusFinalAccepted: "Final acceptance completed",
    statusFileCompletedAccepted: "File completed and status accepted",
    statusFileCompletedRejected: "File completed and status rejected",
    step: "Step",
    student: "Student",
    studentStories: "Student experiences",
    studentProfile: "Student profile",
    students: "Students",
    studentsHelped: "Students Helped",
    submitApplication: "Submit Application",
    submitApplicationNote:
      "Confirm your profile, upload your documents, add notes, and submit your application in a few steps.",
    submitApplicationSuccess: "Application submitted successfully.",
    submitApplicationLoginRequired: "Student login required to apply.",
    submitting: "Submitting...",
    submitYourApplication: "Submit your application",
    testimonialsTitle: "What students say about their journey",
    trackAdmission: "Track your admission status",
    tuition: "Tuition",
    university: "University",
    universities: "Universities",
    viewUniversity: "View university",
    uploadDocument: "Upload document",
    uploadedDocuments: "Uploaded documents",
    yes: "Yes",
    no: "No",
    aboutBody:
      "Study Birds brings together countries, universities, programs, and application guidance so students can plan each step clearly and make better decisions faster.",
    aboutTitle: "Your guide to studying abroad with confidence",
    city: "City",
    contactBody:
      "Reach the Study Birds team for help with choosing a destination, preparing documents, or following up on applications.",
    contactTitle: "Talk to the Study Birds team",
    ctaDescription:
      "Create your account, organize your documents, compare programs, and let Study Birds guide you from first search to final submission.",
    destinationsTitle: "Explore countries that fit your study plan",
    forgotPasswordBody:
      "Password reset delivery can be added next. For now, use seeded accounts or create a fresh student profile.",
    guidedPath: "How Study Birds moves you from search to application",
    homeJourneyIntro:
      "From the first search to the final application step, Study Birds keeps countries, universities, documents, and follow-up in one clear workflow.",
    homePlanningTitle: "University and program planning",
    homePlanningBody: "Compare destinations, universities, and tuition early before deciding where to apply.",
    homeDocumentsTitle: "Better document readiness",
    homeDocumentsBody: "Prepare your documents early so your application moves faster and with fewer delays.",
    homeExperienceEyebrow: "Inside the experience",
    homeExperienceTitle: "A clearer visual journey for every student",
    homeExperienceBody:
      "The homepage now highlights discovery, document preparation, and application follow-up with imagery that reflects the real student journey.",
    recognitionsEyebrow: "Credentials",
    recognitionsTitle: "Certificates and recognitions",
    recognitionsBody: "Highlight trusted certificates, official recognitions, and success badges with direct links for visitors to review.",
    viewRecognition: "View recognition",
    servicesEyebrow: "Our services",
    servicesTitle: "Services we deliver for students",
    servicesBody: "Show the most important services in visual cards that explain how Study Birds supports students through each step.",
    faqEyebrow: "FAQ",
    faqTitle: "Frequently asked questions",
    faqBody: "Answers to the most common questions students ask before choosing a destination and starting an application.",
    studyFieldsEyebrow: "Study fields",
    studyFieldsTitle: "Discover the study paths students ask about most",
    studyFieldsBody: "Showcase your most important study fields with images and direct links to the matching programs.",
    studyFieldBadge: "Explore field",
    destinationBadge: "Study destination",
    destinationCta: "Browse universities in this country",
    universityBadge: "University",
    exhibitions: "Exhibitions Station",
    notFoundBody: "The page you are looking for could not be found.",
    notFoundTitle: "This page could not be found",
    offices: "Offices and support points",
    officeLocationsLabel: "Office locations",
    partnerBody:
      "Study Birds helps universities and recruitment partners present programs clearly, receive qualified students, and manage communication in a more organized way.",
    partnerInstitutions: "Partner Institutions",
    partnerStatus: "Partner",
    partnerTitle: "Work with Study Birds to reach more students",
    readyNextChapter: "Ready to take the next step?",
    returnHome: "Return Home",
    signingIn: "Signing in...",
    studyDestinations: "Study Countries",
    supportHours: "Support hours: Sunday to Thursday, 10:00 to 18:00",
    supportHoursLabel: "Support hours",
    universitiesTitle: "Browse universities on Study Birds",
    footerBody:
      "Study Birds helps students explore countries, compare universities and programs, and stay organized through every step of the study abroad process.",
    welcomeBack: "Welcome back to Study Birds",
  },
  ar: {
    about: "من نحن",
    accepted: "مقبول",
    activeReviews: "طلبات قيد المراجعة",
    address: "العنوان",
    admin: "المدير",
    allCountries: "كل الدول",
    allDegreeLevels: "كل الدرجات",
    allFields: "كل المجالات",
    allIntakes: "كل مواعيد الدراسة",
    allUniversities: "كل الجامعات",
    applications: "الطلبات",
    applyOnline: "قدّم عبر الإنترنت",
    authFailed: "تعذر تسجيل الدخول أو إنشاء الحساب. راجع البيانات وحاول مرة أخرى.",
    contact: "تواصل معنا",
    country: "الدولة",
    createAccount: "أنشئ حسابك",
    creatingAccount: "جارٍ إنشاء الحساب...",
    createProfile: "أنشئ ملفك الشخصي",
    currentEducation: "المؤهل الحالي",
    dashboard: "لوحة التحكم",
    deadline: "آخر موعد",
    degreeBachelor: "بكالوريوس / ليسانس",
    degreeDiploma: "دبلوم",
    degreeMaster: "ماجستير",
    degreeTechnicalInstitute: "معهد فني",
    degreePostgraduateDiploma: "دبلوم عالي بعد البكالوريوس",
    degreeNonThesisMaster: "ماجستير بدون رسالة",
    degreeThesisMaster: "ماجستير برسالة",
    degreeProfessionalDoctorate: "دكتوراه مهنية",
    degreePhD: "دكتوراه أكاديمية (PhD)",
    degreePostdoctoral: "ما بعد الدكتوراه",
    destinations: "وجهات الدراسة",
    documents: "المستندات",
    email: "البريد الإلكتروني",
    fieldBusiness: "إدارة الأعمال",
    fieldEngineering: "الهندسة",
    fieldSocialSciences: "العلوم الاجتماعية",
    fieldTechnology: "التكنولوجيا",
    explore: "استكشف",
    exploreProgram: "استكشف البرنامج",
    explorePrograms: "ابحث عن تخصصك",
    featured: "مميز",
    featuredDestinations: "الدول الأكثر طلبًا بين طلابنا",
    featuredUniversities: "جامعات يرشحها لك Study Birds",
    fieldOfStudy: "مجال الدراسة",
    findBestProgram: "اعثر على البرنامج الأنسب لهدفك",
    flyBeyondBorders: "الدراسة بالخارج تبدأ من هنا",
    forgotPassword: "نسيت كلمة المرور",
    gpa: "المعدل الدراسي",
    heroSubtitle:
      "تساعدك Study Birds على اختيار الدولة المناسبة، ومقارنة الجامعات والبرامج، وتنظيم التقديم خطوة بخطوة من مكان واحد.",
    heroTitle: "ابدأ رحلتك الدراسية مع Study Birds",
    heroStep1: "اختر الدولة والجامعة المناسبة",
    heroStep2: "قارن بين البرامج والرسوم ومواعيد الدراسة",
    heroStep3: "جهّز ملفك ومستنداتك المطلوبة",
    heroStep4: "قدّم وتابع كل تحديث بسهولة",
    heroStatAdmissionsTitle: "قبول أوضح",
    heroStatAdmissionsBody: "خطوات مرتبة، متابعة أسهل، ومسار أكثر وضوحًا حتى التقديم.",
    heroStatWorkspaceTitle: "ملف واحد للطالب",
    heroStatWorkspaceBody: "البرامج والمستندات والطلبات والتحديثات كلها في مكان واحد.",
    heroPlanningCaption: "تخطيط أوضح قبل التقديم",
    heroDocumentsCaption: "تجهيز المستندات بسهولة",
    howItWorks: "كيف تعمل Study Birds",
    intake: "موعد الدراسة",
    intakeFall2026: "خريف 2026",
    intakeSpring2027: "ربيع 2027",
    language: "English",
    login: "تسجيل الدخول",
    loginPrompt: "لديك حساب بالفعل؟",
    logout: "تسجيل الخروج",
    markStatus: "تعيين الحالة",
    maxTuition: "أقصى رسوم",
    minTuition: "أقل رسوم",
    myApplications: "طلباتي",
    name: "الاسم الكامل",
    nationality: "الجنسية",
    noDocuments: "لا توجد مستندات بعد",
    noDocumentsDescription: "ارفع مستنداتك الدراسية لتجهيز طلباتك.",
    noPrograms: "لا توجد برامج مطابقة",
    noProgramsDescription: "جرّب تعديل فلاتر البحث لاستكشاف خيارات أكثر.",
    notifications: "الإشعارات",
    overview: "نظرة عامة",
    partner: "الشركاء",
    partnerPrice: "سعر الشريك",
    password: "كلمة المرور",
    phone: "الهاتف",
    preferredIntake: "موعد الدراسة المفضل",
    programs: "البرامج",
    popularity: "الأكثر طلبًا",
    ranking: "التصنيف",
    recentApplications: "أحدث الطلبات",
    register: "إنشاء حساب",
    registerPrompt: "ليس لديك حساب؟",
    requirements: "المتطلبات",
    role: "الدور",
    saveProfile: "حفظ الملف",
    searchKeyword: "ابحث بكلمة مفتاحية",
    searchProgramsTitle: "ابحث عن برامج تناسب خطتك الدراسية",
    sortByFeatured: "ترتيب حسب المميز",
    startJourney: "ابدأ مع Study Birds",
    statusAccepted: "مقبول",
    statusDraft: "مسودة",
    statusRejected: "مرفوض",
    statusSubmitted: "تم الإرسال",
    statusUnderReview: "قيد المراجعة",
    statusPreliminaryAccepted: "?? ?????? ????????",
    statusPreliminaryAcceptedFirstPayment: "?? ?????? ???????? ??????? ?????? ?????? ?? ?????????",
    statusFinalAccepted: "?? ?????? ???????",
    statusFileCompletedAccepted: "?? ???????? ?? ????? ??????? ?????",
    statusFileCompletedRejected: "?? ???????? ?? ????? ??????? ?????",
    step: "خطوة",
    student: "طالب",
    studentStories: "تجارب الطلاب",
    studentProfile: "ملف الطالب",
    students: "الطلاب",
    studentsHelped: "طالب تمت مساعدتهم",
    submitApplication: "إرسال الطلب",
    submitApplicationNote: "راجع ملفك، ارفع مستنداتك، أضف ملاحظاتك، ثم أرسل طلبك بخطوات بسيطة.",
    submitApplicationSuccess: "تم إرسال الطلب بنجاح.",
    submitApplicationLoginRequired: "يجب تسجيل الدخول كطالب للتقديم.",
    submitting: "جارٍ الإرسال...",
    submitYourApplication: "أرسل طلبك",
    testimonialsTitle: "ماذا يقول الطلاب عن رحلتهم معنا",
    trackAdmission: "تابع حالة القبول",
    tuition: "الرسوم الدراسية",
    university: "الجامعة",
    universities: "الجامعات",
    viewUniversity: "عرض الجامعة",
    uploadDocument: "رفع مستند",
    uploadedDocuments: "المستندات المرفوعة",
    yes: "نعم",
    no: "لا",
    aboutBody:
      "تجمع Study Birds بين الدول والجامعات والبرامج وإرشادات التقديم في مكان واحد، لتساعدك على التخطيط بوضوح واتخاذ القرار المناسب بسرعة أكبر.",
    aboutTitle: "دليلك للدراسة بالخارج بثقة",
    city: "المدينة",
    contactBody: "تواصل مع فريق Study Birds إذا كنت تحتاج مساعدة في اختيار الوجهة، تجهيز المستندات، أو متابعة التقديم.",
    contactTitle: "تواصل مع فريق Study Birds",
    ctaDescription:
      "أنشئ حسابك، نظّم مستنداتك، قارن بين البرامج، واترك لـ Study Birds مهمة إرشادك من أول بحث حتى إرسال الطلب.",
    destinationsTitle: "استكشف دولًا تناسب خطتك الدراسية",
    forgotPasswordBody:
      "يمكن إضافة إرسال رابط إعادة تعيين كلمة المرور لاحقًا. حاليًا استخدم الحسابات التجريبية أو أنشئ حساب طالب جديد.",
    guidedPath: "كيف تنقلك Study Birds من البحث إلى التقديم",
    homeJourneyIntro:
      "من أول بحث حتى آخر خطوة في التقديم، تجمع Study Birds الدول والجامعات والمستندات والمتابعة في مسار واحد واضح للطالب.",
    homePlanningTitle: "اختيار الجامعة والبرنامج",
    homePlanningBody: "قارن بين الوجهات والجامعات والرسوم مبكرًا قبل تحديد قرار التقديم الأنسب لك.",
    homeDocumentsTitle: "تجهيز أفضل للمستندات",
    homeDocumentsBody: "رتّب مستنداتك مبكرًا حتى تسير خطوات التقديم بسرعة وبأقل تأخير ممكن.",
    homeExperienceEyebrow: "داخل التجربة",
    homeExperienceTitle: "رحلة أوضح للطالب داخل المنصة",
    homeExperienceBody:
      "تعرض الواجهة الآن مراحل الاستكشاف وتجهيز الملف ومتابعة التقديم بصور أقرب لتجربة الطالب الحقيقية.",
    recognitionsEyebrow: "الاعتمادات",
    recognitionsTitle: "الشهادات والاعترافات",
    recognitionsBody: "اعرض الشهادات والاعترافات والاعتمادات المهمة مع روابط مباشرة ليتمكن الزائر من الاطلاع عليها بسهولة.",
    viewRecognition: "عرض الشهادة",
    servicesEyebrow: "خدماتنا",
    servicesTitle: "الخدمات التي نقدمها للطلاب",
    servicesBody: "اعرض أهم الخدمات في بطاقات مرئية توضح كيف تساعد Study Birds الطالب في كل مرحلة من رحلته.",
    faqEyebrow: "الأسئلة الشائعة",
    faqTitle: "الأسئلة الشائعة",
    faqBody: "إجابات واضحة على أكثر الأسئلة التي يطرحها الطلاب قبل اختيار الدولة وبدء التقديم.",
    studyFieldsEyebrow: "التخصصات",
    studyFieldsTitle: "اكتشف المسارات الدراسية الأكثر طلبًا",
    studyFieldsBody: "اعرض أهم مجالات الدراسة بالصور مع رابط مباشر للبرامج المرتبطة بكل تخصص.",
    studyFieldBadge: "استكشف التخصص",
    destinationBadge: "وجهة دراسية",
    destinationCta: "استعرض جامعات هذه الدولة",
    universityBadge: "جامعة",
    exhibitions: "محطة المعارض",
    notFoundBody: "لم نتمكن من العثور على الصفحة المطلوبة.",
    notFoundTitle: "الصفحة غير موجودة",
    offices: "مكاتبنا ونقاط الدعم",
    officeLocationsLabel: "مواقع المكاتب",
    partnerBody:
      "تساعد Study Birds الجامعات والشركاء على عرض البرامج بوضوح، والوصول إلى طلاب مؤهلين، وتنظيم التواصل وخطوات القبول بشكل أفضل.",
    partnerInstitutions: "مؤسسة شريكة",
    partnerStatus: "شريك",
    partnerTitle: "تعاون مع Study Birds للوصول إلى طلاب أكثر",
    readyNextChapter: "جاهز لخطوتك التالية؟",
    returnHome: "العودة للرئيسية",
    signingIn: "جارٍ تسجيل الدخول...",
    studyDestinations: "دول الدراسة",
    supportHours: "ساعات الدعم: من الأحد إلى الخميس، 10:00 صباحًا إلى 6:00 مساءً",
    supportHoursLabel: "مواعيد العمل",
    universitiesTitle: "تصفح الجامعات على Study Birds",
    footerBody:
      "تساعد Study Birds الطلاب على استكشاف الدول، ومقارنة الجامعات والبرامج، وتنظيم رحلة الدراسة بالخارج من البداية حتى التقديم.",
    welcomeBack: "مرحبًا بعودتك إلى Study Birds",
  },
};

interface LanguageContextValue {
  language: Language;
  isRtl: boolean;
  toggleLanguage: () => void;
  setLanguage: (language: Language) => void;
  t: (key: TranslationKey) => string;
  tv: (value?: string) => string;
}

const valueTranslations: Record<string, string> = {
  "Academic transcripts": "السجلات الأكاديمية",
  Australia: "أستراليا",
  Bachelor: "بكالوريوس",
  Business: "إدارة الأعمال",
  Canada: "كندا",
  Diploma: "دبلوم",
  Engineering: "الهندسة",
  "English proficiency": "إثبات إجادة اللغة الإنجليزية",
  "Fall 2026": "خريف 2026",
  Germany: "ألمانيا",
  Ireland: "أيرلندا",
  Master: "ماجستير",
  Passport: "جواز السفر",
  "Social Sciences": "العلوم الاجتماعية",
  "Spring 2027": "ربيع 2027",
  Technology: "التكنولوجيا",
  Turkey: "تركيا",
  "United Kingdom": "المملكة المتحدة",
  "United States": "الولايات المتحدة",
};

const replaceBrandName = (value: string) => value.replace(/Study Birds/g, SITE_NAME);
const normalizeUiText = (value: string) => replaceBrandName(repairMojibake(value));

export const LanguageContext = createContext<LanguageContextValue | undefined>(undefined);

export const LanguageProvider = ({ children }: { children: ReactNode }) => {
  const [language, setLanguageState] = useState<Language>(() => {
    if (typeof window !== "undefined") {
      const urlLanguage = new URLSearchParams(window.location.search).get("lang");
      if (urlLanguage === "ar" || urlLanguage === "en") {
        return urlLanguage;
      }
    }

    return (localStorage.getItem("studyBirdsLanguage") as Language) || "en";
  });

  useEffect(() => {
    localStorage.setItem("studyBirdsLanguage", language);
    document.documentElement.lang = language;
    document.documentElement.dir = language === "ar" ? "rtl" : "ltr";
  }, [language]);

  const setLanguage = useCallback((nextLanguage: Language) => {
    setLanguageState(nextLanguage);
  }, []);

  const toggleLanguage = useCallback(() => {
    setLanguageState((current) => (current === "en" ? "ar" : "en"));
  }, []);

  const value = useMemo<LanguageContextValue>(
    () => ({
      language,
      isRtl: language === "ar",
      toggleLanguage,
      setLanguage,
      t: (key) => normalizeUiText(translations[language][key]),
      tv: (value) => {
        const nextValue = language === "ar" && value ? valueTranslations[value] || value : value || "";
        return normalizeUiText(nextValue);
      },
    }),
    [language, setLanguage, toggleLanguage]
  );

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
};
