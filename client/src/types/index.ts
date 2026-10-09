import type { StatusInfo } from "../hooks/useStatusCatalog";

export type Role = "student" | "admin" | "partner" | "parent" | "university" | "employee";

export type EmployeeRole =
  | "educational_consultant"
  | "sales"
  | "admission"
  | "admission_manager"
  | "visa_officer"
  | "travel_coordinator"
  | "accommodation_officer"
  | "finance"
  | "customer_support"
  | "branch_manager"
  | "operations"
  | "marketing"
  | "university_relations"
  | "agent_manager"
  | "content_manager"
  | "super_admin";

export interface ArticleContent {
  articleTitle?: string;
  articleTitleColor?: string;
  articleHeadingColor?: string;
  articleBodyColor?: string;
  articleHeadings?: string[];
  articleBodies?: string[];
}

export interface User {
  _id: string;
  name: string;
  email: string;
  role: Role;
  avatar?: string;
  authProvider?: "local" | "google";
  emailVerified?: boolean;
  hasPassword?: boolean;
  isActive?: boolean;
  createdAt?: string;
  lastLoginAt?: string;
  // NEW — optional, only populated for the relevant role.
  employeeRole?: EmployeeRole | null;
  permissions?: string[];
  linkedUniversity?: (University & { _id: string }) | string | null;
}

// NEW — mirrors AgencyRequest, for parent-student linking.
export interface ParentLinkItem {
  _id: string;
  status: "pending" | "approved" | "rejected";
  parent?: User;
  student?: User;
  relationship?: string;
  parentNote?: string;
  adminNote?: string;
  submittedAt?: string;
  reviewedAt?: string;
  reviewedBy?: User;
  createdAt?: string;
  updatedAt?: string;
}

// NEW — read-only shape returned by /api/parents/children/:id/overview
export interface ParentChildOverview {
  student: User;
  journeyStage: string | null;
  applicationStage: string | null;
  targetCountries: string[];
  intake: string | null;
  applications: Array<{
    id: string;
    status: string;
    detailedStatus: string;
    university?: { _id: string; name: string; city?: string };
    program?: { _id: string; name: string };
    submittedAt?: string;
    timeline: Array<{ status: string; note?: string; changedAt?: string }>;
  }>;
}

export interface Country extends ArticleContent {
  _id: string;
  name: string;
  slug: string;
  code: string;
  description?: string;
  visaNotes?: string;
  heroImage?: string;
  universityCount?: number;
  specialtyCount?: number;
  averageTuition?: number;
  featured?: boolean;
  createdAt?: string;
  visaRequirements?: { docKey: string; label: string }[];
  processingDays?: number;
  visaFeeUsd?: number;
  languageRequirements?: string[];
  visaNotesList?: string[];
}

export interface SiteSettings {
  _id?: string;
  contactEmail?: string;
  whatsappUrl?: string;
  facebookUrl?: string;
  instagramUrl?: string;
  tiktokUrl?: string;
  britishMembershipUrl?: string;
  supportHours?: string;
  officeLocations?: string;
  leadCapturePromptEnabled?: boolean;
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
}

export interface PaginatedResponse<T> {
  items: T[];
  pagination: PaginationMeta;
}

export interface UpcomingEvent {
  _id?: string;
  title?: string;
  subtitle?: string;
  eventType?: string;
  eventDate?: string | null;
  ctaText?: string;
  backgroundImage?: string;
  isPublished?: boolean;
}

export interface PastEventMediaItem {
  _id?: string;
  type: "image" | "video";
  url: string;
}

export interface PastEvent {
  _id: string;
  title: string;
  slug?: string;
  category: "expos-fairs" | "our-community" | "webinars" | "partnerships";
  eventDate?: string | null;
  countryCode?: string;
  summary?: string;
  coverImage?: string;
  mediaItems?: PastEventMediaItem[];
  featured?: boolean;
  sortOrder?: number;
  createdAt?: string;
}

export interface EventRegistration {
  _id: string;
  name: string;
  phone: string;
  fieldOfInterest: string;
  currentCountry: string;
  desiredStudyCountry?: string;
  upcomingEvent?: {
    _id?: string;
    title?: string;
    eventDate?: string | null;
  } | null;
  createdAt?: string;
}

export interface StudyField {
  _id: string;
  name: string;
  slug?: string;
  titleColor?: string;
  description?: string;
  image?: string;
  featured?: boolean;
  sortOrder?: number;
  createdAt?: string;
}

export interface University extends ArticleContent {
  _id: string;
  name: string;
  slug: string;
  city?: string;
  language?: string;
  studentCount?: number;
  specialtyCount?: number;
  overview?: string;
  ranking?: number;
  featured?: boolean;
  isPartnerInstitution?: boolean;
  logo?: string;
  campusImages?: string[];
  tuitionRange?: {
    min?: number;
    max?: number;
  };
  country?: Country;
  createdAt?: string;
}

export interface FavoriteItem {
  _id: string;
  itemType: "university" | "program";
  student?: Pick<User, "_id" | "name" | "email">;
  university?: University | null;
  program?: Program | null;
  notes?: string;
  createdAt?: string;
}

export interface Program extends ArticleContent {
  requiredDocumentTypes?: string[];
  _id: string;
  title: string;
  slug: string;
  degreeLevel: string;
  fieldOfStudy: string;
  fieldsOfStudy?: string[];
  language?: string;
  duration?: string;
  tuition?: number;
  partnerTuition?: number;
  applicationDeadline?: string;
  intake?: string;
  requirements?: string[];
  careerOpportunities?: string[];
  // Returned by GET /programs/:id only (PRD 21).
  offeredAt?: Array<{ _id: string; title: string; university?: { name: string; city?: string; country?: { name: string } } }>;
  relatedPrograms?: Array<{ _id: string; title: string; university?: { name: string } }>;
  summary?: string;
  popularity?: number;
  coverImage?: string;
  university?: University;
  featured?: boolean;
  createdAt?: string;
}

export interface DocumentItem {
  _id: string;
  student?: Pick<User, "_id" | "name" | "email">;
  type: string;
  fileName: string;
  filePath: string;
  status: "pending" | "verified" | "rejected";
  detailedStatus?: string;
  statusInfo?: StatusInfo;
  expiresAt?: string | null;
  reviewedBy?: Pick<User, "name"> & { _id?: string };
  reviewedAt?: string;
  __v?: number;
  // Version history and translation (PRD 29), from GET /students/documents.
  isLatest?: boolean;
  replaces?: string;
  translationOf?: string;
  versions?: Array<{ _id: string; fileName: string; filePath: string; createdAt: string; statusInfo: StatusInfo }>;
  translation?: { status: "required" | "uploaded" | "approved" | "needs-attention" | "not-required"; documentId: string | null; statusInfo?: StatusInfo } | null;
  mimeType?: string;
  size?: number;
  reviewNote?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface ApplicantProfileSnapshot {
  name?: string;
  email?: string;
  phone?: string;
  dateOfBirth?: string;
  nationality?: string;
  currentEducation?: string;
  gpa?: string;
  intake?: string;
  address?: string;
  englishTest?: {
    exam?: string;
    score?: string;
  };
}

// Per-application summary from GET /students/applications (PRD 15/16).
export interface ApplicationStageSummary { status: string; labelAr: string; labelEn: string; tone: string }
export interface ApplicationCard {
  university: string; program: string; degreeLevel: string; language: string; duration: string;
  country: string; city: string; campus: string; intake: string;
  applicationStatus: StatusInfo;
  admissionStatus: ApplicationStageSummary | null; documentsStatus: ApplicationStageSummary | null; paymentStatus: ApplicationStageSummary | null;
  visaStatus: { status: string; labelAr: string; labelEn: string } | null;
  consultant: string | null; lastUpdate: string | null;
  nextAction: { code: string; titleAr: string; titleEn: string; descriptionAr: string; destination: string; waiting: boolean } | null;
  applicationId: string;
}

export interface Application {
  _id: string;
  card?: ApplicationCard;
  status: string;
  // NEW — already present in the API response; added here so the
  // university portal pages can read it with full type safety.
  detailedStatus?: string;
  statusInfo?: StatusInfo;
  university?: { _id: string; name: string; city?: string } | string;
  notes?: string;
  submittedAt?: string;
  createdAt?: string;
  reviewedBy?: string | User;
  program?: Program;
  student?: User;
  documents?: DocumentItem[];
  applicantProfile?: ApplicantProfileSnapshot;
  studentProfile?: ApplicantProfileSnapshot;
  statusTimeline?: Array<{
    status: string;
    note?: string;
    changedAt?: string;
    changedBy?: string | User;
  }>;
}

export interface StudentProfile {
  _id?: string;
  user?: User;
  phone?: string;
  englishFullName?: string;
  passportNumber?: string;
  dateOfBirth?: string;
  nationality?: string;
  currentEducation?: string;
  currentEducationLevel?: "high-school" | "bachelor" | "master" | "phd" | "";
  currentResidenceCountry?: string;
  currentResidenceRegion?: string;
  nativeLanguage?: string;
  otherLanguages?: string[];
  gpa?: string;
  intake?: string;
  bio?: string;
  address?: string;
  targetCountries?: string[];
  englishTest?: {
    exam?: string;
    score?: string;
  };
  parentInfo?: {
    name?: string;
    phone?: string;
    relationship?: string;
  };
  emergencyContact?: {
    name?: string;
    phone?: string;
    relationship?: string;
  };
  companyName?: string;
  website?: string;
  location?: string;
  taxId?: string;
  verificationStatus?: "pending" | "verified" | "rejected";
  verificationReason?: string;
  referralCode?: string;
  applicationStage?:
    | "file-received"
    | "applying"
    | "preliminary-accepted"
    | "first-payment"
    | "final-accepted"
    | "travel-and-settlement";
}

export interface AgentStudentDocument {
  _id?: string;
  label: string;
  fileName: string;
  filePath: string;
  mimeType?: string;
  size?: number;
  uploadedAt?: string;
}

export interface AgentStudentItem {
  _id: string;
  agent?: Pick<User, "_id" | "name" | "email">;
  name: string;
  email: string;
  phone: string;
  passportNumber?: string;
  studyPreferences?: string;
  desiredUniversity?: string;
  desiredProgram?: string;
  notes?: string;
  applicationStatus: "under-review" | "preliminary-accepted" | "final-accepted" | "rejected";
  documents?: AgentStudentDocument[];
  createdAt?: string;
  updatedAt?: string;
}

export interface AgentWalletEntry {
  _id: string;
  direction: "credit" | "debit";
  kind: "commission" | "payout" | "adjustment";
  amount: number;
  status: "pending" | "approved" | "rejected" | "paid";
  method?: string;
  details?: string;
  notes?: string;
  createdAt?: string;
  paidAt?: string;
}

export interface PayoutRequestItem {
  _id: string;
  amount: number;
  method: "bank-account" | "usdt" | "wise" | "other";
  payoutDetails: string;
  notes?: string;
  status: "pending" | "approved" | "rejected" | "paid";
  reviewNote?: string;
  reviewedAt?: string;
  createdAt?: string;
  agent?: Pick<User, "_id" | "name" | "email">;
  reviewedBy?: Pick<User, "_id" | "name" | "email">;
}

export interface ReferralSummary {
  referralCode: string;
  referralLink: string;
  summary: {
    clicks: number;
    signups: number;
    acceptedStudents: number;
    generatedCommissions: number;
  };
}

export interface MarketingAssetItem {
  _id: string;
  title: string;
  description?: string;
  type: string;
  fileName: string;
  fileUrl: string;
  published?: boolean;
  createdAt?: string;
}

export interface AdminPartnerItem extends User {
  profile?: StudentProfile | null;
}

export interface AdminStudentItem extends User {
  profile?: StudentProfile | null;
}

export interface VerificationDocumentItem {
  _id: string;
  type: "identity" | "commercial-license" | "supporting-document";
  fileName: string;
  filePath: string;
  mimeType?: string;
  size?: number;
  status: "pending" | "approved" | "rejected";
  reviewNote?: string;
  createdAt?: string;
  agent?: Pick<User, "_id" | "name" | "email">;
  reviewedBy?: Pick<User, "_id" | "name" | "email">;
}

export interface VerificationOverview {
  status: "pending" | "verified" | "rejected";
  reason?: string;
  documents: VerificationDocumentItem[];
}

export interface SupportTicketReply {
  _id?: string;
  message: string;
  fromRole: "student" | "partner" | "admin";
  user?: Pick<User, "_id" | "name" | "email" | "role">;
  createdAt?: string;
}

export interface SupportTicketItem {
  _id: string;
  subject: string;
  message: string;
  category: "documents" | "application-status" | "payment" | "arrival-services" | "student-application" | "commission" | "technical-issue" | "other";
  status: "open" | "in-progress" | "answered" | "closed";
  attachment?: {
    fileName?: string;
    filePath?: string;
  };
  replies?: SupportTicketReply[];
  requesterRole?: "student" | "partner";
  user?: Pick<User, "_id" | "name" | "email" | "role">;
  createdAt?: string;
  updatedAt?: string;
  agent?: Pick<User, "_id" | "name" | "email">;
}

export interface ActivityLogItem {
  _id: string;
  action: string;
  description?: string;
  ipAddress?: string;
  userAgent?: string;
  createdAt?: string;
}

export interface KnowledgeBaseItem {
  _id: string;
  title: string;
  body: string;
  summary?: string;
  category?: string;
  resourceType?: "article" | "pdf" | "video" | "link";
  fileUrl?: string;
  videoUrl?: string;
  targetRole?: "all" | "student" | "partner";
  sortOrder?: number;
  published?: boolean;
  createdAt?: string;
}

// Home screen payload built by server/src/utils/studentHome.js.
export interface StudentHomeDate {
  key: string; date: string; daysLeft: number; overdue: boolean; critical: boolean;
  titleAr: string; titleEn: string; destination: string; entityId: string;
}
export interface StudentHome {
  greeting: { name: string };
  context: { key: string; titleAr: string; titleEn: string; descriptionAr: string; descriptionEn: string; destination: string };
  statusCard: {
    statusInfo: StatusInfo | null; labelAr: string; labelEn: string; nextStepAr: string; nextStepEn: string;
    nextStepDescriptionAr: string; nextStepDescriptionEn: string; destination: string; waiting: boolean;
  };
  currentJourney: { applicationId: string; country: string; city: string; university: string; program: string } | null;
  progressPercent: number;
  importantDates: StudentHomeDate[];
  sections: {
    application: { applicationId: string; program: string; statusInfo: StatusInfo } | null;
    documents: { total: number; approved: number; needsAction: number; underReview: number };
    admission: { statusInfo: StatusInfo } | null;
    visa: { status: string; labelAr: string; labelEn: string; appointmentDate: string | null } | null;
    travel: { arrivalDate: string | null; arrivalStatus: string | null; pickupStatus: string | null; housingStatus: string | null; moveInDate: string | null } | null;
    payments: { unpaid: number; overdue: number; nextDueDate: string | null; nextDueAmount: number | null };
    support: { openTickets: number };
    notifications: { unread: number; latest: { title: string; message: string; createdAt: string } | null };
    recentActivity: Array<{ at: string; kind: string; titleAr: string; titleEn: string; destination: string; entityId: string }>;
  };
  quickActions: Array<{ key: string; labelAr: string; labelEn: string; destination: string }>;
}

export interface StudentDashboardOverview {
  home?: StudentHome;
  nextAction?: { code: string; destination: string; titleAr: string; titleEn: string; descriptionAr: string; descriptionEn: string; entityId: string; waiting: boolean; dueDate: string | null };
  profile: StudentProfile | null;
  progress: {
    currentStage: NonNullable<StudentProfile["applicationStage"]>;
    stages: Array<{
      key: NonNullable<StudentProfile["applicationStage"]>;
      titleAr: string;
      titleEn: string;
      descriptionAr: string;
      descriptionEn: string;
      status: "completed" | "current" | "upcoming";
    }>;
  };
  stats: {
    currentApplications: number;
    acceptedDocuments: number;
    rejectedDocuments: number;
    pendingPayments: number;
    unreadNotifications: number;
  };
  latestNotification: NotificationItem | null;
  recentApplications: Application[];
  recentDocuments: DocumentItem[];
}

export interface PartnerOverview {
  stats: {
    totalStudents: number;
    acceptedStudents: number;
    totalReceivedEarnings: number;
    pendingEarnings: number;
    verificationStatus: "pending" | "verified" | "rejected";
  };
  recent: {
    latestStudent: AgentStudentItem | null;
    latestStudentStatusUpdate: AgentStudentItem | null;
    latestPayoutRequest: PayoutRequestItem | null;
    latestNotification: NotificationItem | null;
  };
}

export interface AgencyRequest {
  _id: string;
  status: "pending" | "approved" | "rejected";
  student?: User;
  studentNote?: string;
  adminNote?: string;
  submittedAt?: string;
  reviewedAt?: string;
  reviewedBy?: User;
  createdAt?: string;
  updatedAt?: string;
}

export interface Testimonial {
  _id: string;
  studentName: string;
  destination?: string;
  quote: string;
  avatar?: string;
  rating?: number;
  featured?: boolean;
  createdAt?: string;
}

export interface Recognition {
  _id: string;
  slug?: string;
  title: string;
  image?: string;
  link?: string;
  detailTitle?: string;
  detailBody?: string;
  detailImage?: string;
  featured?: boolean;
  sortOrder?: number;
  createdAt?: string;
}

export interface OurService {
  _id: string;
  slug?: string;
  title: string;
  image?: string;
  detailTitle?: string;
  detailBody?: string;
  detailImage?: string;
  priceDescription?: string;
  estimatedDuration?: string;
  price?: number;
  durationDays?: number;
  journeyStage?: string;
  featured?: boolean;
  sortOrder?: number;
  country?: Country | string | null;
  createdAt?: string;
}

export interface OurStoryFounder {
  _id?: string;
  name: string;
  role?: string;
  bio?: string;
  image?: string;
}

export interface OurStoryTimelineItem {
  _id?: string;
  year?: string;
  dateLabel?: string;
  title?: string;
  body?: string;
  image?: string;
  sortOrder?: number;
}

export interface OurStoryImpactStat {
  _id?: string;
  value?: string;
  label?: string;
}

export interface OurStory {
  _id?: string;
  heroEyebrow?: string;
  heroTitle?: string;
  heroBody?: string;
  heroImage?: string;
  heroCtaText?: string;
  heroCtaLink?: string;
  storyEyebrow?: string;
  storyTitle?: string;
  storyBody?: string;
  storyImage?: string;
  missionTitle?: string;
  missionBody?: string;
  visionTitle?: string;
  visionBody?: string;
  foundersTitle?: string;
  foundersBody?: string;
  founders?: OurStoryFounder[];
  timelineTitle?: string;
  timelineBody?: string;
  timelineItems?: OurStoryTimelineItem[];
  impactTitle?: string;
  impactBody?: string;
  impactStats?: OurStoryImpactStat[];
  isPublished?: boolean;
}

export interface Faq {
  _id: string;
  question: string;
  answer: string;
  featured?: boolean;
  sortOrder?: number;
  country?: Country | string | null;
  createdAt?: string;
}

export interface ExhibitionArticle extends ArticleContent {
  _id: string;
  title: string;
  slug: string;
  customSlug?: string;
  image?: string;
  summary: string;
  body: string;
  titleColor?: string;
  ctaText?: string;
  ctaUrl?: string;
  youtubeUrl: string;
  featured?: boolean;
  published?: boolean;
  seoTitle?: string;
  metaDescription?: string;
  focusKeyword?: string;
  seoKeywords?: string[];
  canonicalUrl?: string;
  ogTitle?: string;
  ogDescription?: string;
  ogImage?: string;
  twitterTitle?: string;
  twitterDescription?: string;
  twitterImage?: string;
  imageAltText?: string;
  robotsIndex?: "index" | "noindex";
  robotsFollow?: "follow" | "nofollow";
  category?: string;
  country?: Country | string | null;
  authorName?: string;
  publishedAt?: string | null;
  seoUpdatedAt?: string | null;
  sections?: Array<{
    title: string;
    summary?: string;
    body: string;
    titleColor?: string;
    youtubeUrl: string;
  }>;
  createdAt?: string;
  updatedAt?: string;
  resolvedSeo?: {
    articleUrl: string;
    canonicalUrl: string;
    seoTitle: string;
    metaDescription: string;
    focusKeyword?: string;
    seoKeywords: string[];
    ogTitle: string;
    ogDescription: string;
    ogImage: string;
    twitterTitle: string;
    twitterDescription: string;
    twitterImage: string;
    imageAltText: string;
    robotsIndex: "index" | "noindex";
    robotsFollow: "follow" | "nofollow";
    category: string;
    categorySlug: string;
    authorName: string;
    publishedAt?: string | null;
    updatedAt?: string | null;
  };
  articleSchema?: Record<string, unknown>;
}

export interface NotificationItem {
  _id: string;
  user?: Pick<User, "_id" | "name" | "email" | "role">;
  title: string;
  message: string;
  type: string;
  isRead: boolean;
  createdAt?: string;
}

export interface InvoiceItem {
  _id: string;
  student?: Pick<User, "_id" | "name" | "email">;
  application?: Pick<Application, "_id" | "status"> | null;
  invoiceNumber: string;
  description: string;
  amount: number;
  dueDate?: string;
  status: "unpaid" | "pending-confirmation" | "paid" | "rejected";
  invoiceUrl?: string;
  category?: "application-fee" | "tuition" | "service" | "housing" | "other";
  walletCreditApplied?: number;
  adminNote?: string;
  reviewedAt?: string;
  reviewedBy?: Pick<User, "_id" | "name" | "email">;
  createdAt?: string;
}

export interface PaymentProofItem {
  _id: string;
  student?: Pick<User, "_id" | "name" | "email">;
  invoice?: InvoiceItem | null;
  fileName: string;
  filePath: string;
  mimeType?: string;
  size?: number;
  amount?: number;
  note?: string;
  status: "pending" | "approved" | "rejected";
  reviewNote?: string;
  reviewedAt?: string;
  reviewedBy?: Pick<User, "_id" | "name" | "email">;
  createdAt?: string;
}

export interface StudentFinancialsResponse {
  summary: {
    outstandingAmount: number;
    pendingConfirmationAmount: number;
    paidAmount: number;
    invoiceCount: number;
  };
  invoices: InvoiceItem[];
  paymentProofs: PaymentProofItem[];
}

export interface ArrivalServiceRequestItem {
  _id: string;
  student?: Pick<User, "_id" | "name" | "email">;
  arrivalDate?: string | null;
  arrivalTime?: string;
  flightNumber?: string;
  airport?: string;
  notes?: string;
  services: {
    airportPickup: boolean;
    studentHousing: boolean;
    residencePermitSupport: boolean;
    visaSupport: boolean;
  };
  status: "draft" | "submitted" | "in-progress" | "completed";
  adminNote?: string;
  travelAlert?: string;
  pickup?: {
    status?: "not-assigned" | "assigned" | "en-route" | "arrived" | "completed";
    driverName?: string;
    driverPhone?: string;
    confirmedAt?: string | null;
  };
  updatedBy?: Pick<User, "_id" | "name" | "email">;
  createdAt?: string;
  updatedAt?: string;
}

export interface OrientationTestResultItem {
  _id: string;
  student?: Pick<User, "_id" | "name" | "email">;
  answers: {
    favoriteSubjects: string[];
    interestedFields: string[];
    studyStyle?: string;
    preferredLanguage?: string;
    preferredCountry?: string;
    approximateBudget?: string;
    desiredDegreeLevel?: string;
    avoidFields: string[];
  };
  recommendationSummary?: string;
  suggestedFields?: string[];
  suggestedCountries?: string[];
  adminNote?: string;
  reviewedBy?: Pick<User, "_id" | "name" | "email">;
  createdAt?: string;
  updatedAt?: string;
}

export interface HomePageContent {
  countries: Country[];
  studyFields: StudyField[];
  universities: University[];
  testimonials: Testimonial[];
  recognitions: Recognition[];
  services: OurService[];
  faqs: Faq[];
}

export interface AuthResponse {
  token: string;
  user: User;
}

export interface AdminOverview {
  stats: {
    users: number;
    students: number;
    admins: number;
    partners: number;
    inactiveUsers: number;
    universities: number;
    programs: number;
    applications: number;
    submittedApplications: number;
    underReviewApplications: number;
  };
  recentApplications: Application[];
  recentUsers: User[];
  applicationsByStatus: Record<string, number>;
}

export interface AdminPartnerDetails {
  partner: AdminPartnerItem;
  students: AgentStudentItem[];
  payoutRequests: PayoutRequestItem[];
  supportTickets: SupportTicketItem[];
  verificationDocuments: VerificationDocumentItem[];
  walletEntries: AgentWalletEntry[];
  notifications: NotificationItem[];
}

export interface AdminStudentDetails {
  student: AdminStudentItem;
  applications: Application[];
  documents: DocumentItem[];
  invoices: InvoiceItem[];
  paymentProofs: PaymentProofItem[];
  arrivalRequest: ArrivalServiceRequestItem | null;
  favorites: FavoriteItem[];
  orientationResult: OrientationTestResultItem | null;
  supportTickets: SupportTicketItem[];
  notifications: NotificationItem[];
}
