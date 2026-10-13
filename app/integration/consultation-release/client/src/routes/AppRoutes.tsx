import { Suspense, lazy } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { MainLayout } from "../layouts/MainLayout";
import { DashboardLayout } from "../layouts/DashboardLayout";
import { ProtectedRoute } from "../components/ProtectedRoute";
import { useLanguage } from "../hooks/useLanguage";

const ConsultationsPage = lazy(() => import("../pages/ConsultationsPage").then(m => ({ default: m.ConsultationsPage })));
const AccountSecurityPage = lazy(() => import("../pages/auth/AccountSecurityPage").then(module => ({ default: module.AccountSecurityPage })));
const HomePage = lazy(() => import("../pages/HomePage").then((module) => ({ default: module.HomePage })));
const ProgramsPage = lazy(() => import("../pages/ProgramsPage").then((module) => ({ default: module.ProgramsPage })));
const ProgramDetailsPage = lazy(() => import("../pages/ProgramDetailsPage").then((module) => ({ default: module.ProgramDetailsPage })));
const UniversitiesPage = lazy(() => import("../pages/UniversitiesPage").then((module) => ({ default: module.UniversitiesPage })));
const UniversityDetailsPage = lazy(() => import("../pages/UniversityDetailsPage").then((module) => ({ default: module.UniversityDetailsPage })));
const StudyDestinationsPage = lazy(() => import("../pages/StudyDestinationsPage").then((module) => ({ default: module.StudyDestinationsPage })));
const ServicesPage = lazy(() => import("../pages/ServicesPage").then((module) => ({ default: module.ServicesPage })));
const ServiceDetailsPage = lazy(() => import("../pages/ServiceDetailsPage").then((module) => ({ default: module.ServiceDetailsPage })));
const RecognitionDetailsPage = lazy(() => import("../pages/RecognitionDetailsPage").then((module) => ({ default: module.RecognitionDetailsPage })));
const ExhibitionsPage = lazy(() => import("../pages/ExhibitionsPage").then((module) => ({ default: module.ExhibitionsPage })));
const ExhibitionDetailsPage = lazy(() => import("../pages/ExhibitionDetailsPage").then((module) => ({ default: module.ExhibitionDetailsPage })));
const BlogCategoryPage = lazy(() => import("../pages/BlogCategoryPage").then((module) => ({ default: module.BlogCategoryPage })));
const AboutPage = lazy(() => import("../pages/AboutPage").then((module) => ({ default: module.AboutPage })));
const OurEventPage = lazy(() => import("../pages/OurEventPage").then((module) => ({ default: module.OurEventPage })));
const OurStoryPage = lazy(() => import("../pages/OurStoryPage").then((module) => ({ default: module.OurStoryPage })));
const ContactPage = lazy(() => import("../pages/ContactPage").then((module) => ({ default: module.ContactPage })));
const PrivacyPolicyPage = lazy(() => import("../pages/PrivacyPolicyPage").then((module) => ({ default: module.PrivacyPolicyPage })));
const FaqPage = lazy(() => import("../pages/FaqPage").then((module) => ({ default: module.FaqPage })));
const PartnerPage = lazy(() => import("../pages/PartnerPage").then((module) => ({ default: module.PartnerPage })));
const BecomeAgentPage = lazy(() => import("../pages/BecomeAgentPage").then((module) => ({ default: module.BecomeAgentPage })));
const NotFoundPage = lazy(() => import("../pages/NotFoundPage").then((module) => ({ default: module.NotFoundPage })));
const MobileSignInPage = lazy(() => import("../pages/auth/MobileSignInPage").then(module => ({default:module.MobileSignInPage})));
const LoginPage = lazy(() => import("../pages/auth/LoginPage").then((module) => ({ default: module.LoginPage })));
const RegisterPage = lazy(() => import("../pages/auth/RegisterPage").then((module) => ({ default: module.RegisterPage })));
const ForgotPasswordPage = lazy(() => import("../pages/auth/ForgotPasswordPage").then((module) => ({ default: module.ForgotPasswordPage })));
const StudentProfilePage = lazy(() => import("../pages/student/StudentProfilePage").then((module) => ({ default: module.StudentProfilePage })));
const StudentDocumentsPage = lazy(() => import("../pages/student/StudentDocumentsPage").then((module) => ({ default: module.StudentDocumentsPage })));
const StudentApplicationsPage = lazy(() => import("../pages/student/StudentApplicationsPage").then((module) => ({ default: module.StudentApplicationsPage })));
const StudentDashboardPage = lazy(() => import("../pages/student/StudentDashboardPage").then((module) => ({ default: module.StudentDashboardPage })));
const StudentNotificationsPage = lazy(() => import("../pages/student/StudentNotificationsPage").then((module) => ({ default: module.StudentNotificationsPage })));
const StudentSupportPage = lazy(() => import("../pages/student/StudentSupportPage").then((module) => ({ default: module.StudentSupportPage })));
const StudentResourcesPage = lazy(() => import("../pages/student/StudentResourcesPage").then((module) => ({ default: module.StudentResourcesPage })));
const StudentFinancialsPage = lazy(() => import("../pages/student/StudentFinancialsEnhancedPage").then((module) => ({ default: module.StudentFinancialsEnhancedPage })));
const StudentArrivalServicesPage = lazy(() => import("../pages/student/StudentArrivalServicesEnhancedPage").then((module) => ({ default: module.StudentArrivalServicesEnhancedPage })));
const StudentFavoritesPage = lazy(() => import("../pages/student/StudentFavoritesEnhancedPage").then((module) => ({ default: module.StudentFavoritesEnhancedPage })));
const StudentOrientationTestPage = lazy(() => import("../pages/student/StudentOrientationTestEnhancedPage").then((module) => ({ default: module.StudentOrientationTestEnhancedPage })));
const StudentBecomeAgentPage = lazy(() => import("../pages/student/StudentBecomeAgentPage").then((module) => ({ default: module.StudentBecomeAgentPage })));
const PartnerDashboardPage = lazy(() => import("../pages/partner/PartnerDashboardPage").then((module) => ({ default: module.PartnerDashboardPage })));
const PartnerStudentsPage = lazy(() => import("../pages/partner/PartnerStudentsManagePage").then((module) => ({ default: module.PartnerStudentsManagePage })));
const PartnerWalletPage = lazy(() => import("../pages/partner/PartnerWalletPage").then((module) => ({ default: module.PartnerWalletPage })));
const PartnerReferralPage = lazy(() => import("../pages/partner/PartnerReferralPage").then((module) => ({ default: module.PartnerReferralPage })));
const PartnerMarketingToolkitPage = lazy(() => import("../pages/partner/PartnerMarketingToolkitPage").then((module) => ({ default: module.PartnerMarketingToolkitPage })));
const PartnerVerificationPage = lazy(() => import("../pages/partner/PartnerVerificationPage").then((module) => ({ default: module.PartnerVerificationPage })));
const PartnerSupportTicketsPage = lazy(() => import("../pages/partner/PartnerSupportTicketsPage").then((module) => ({ default: module.PartnerSupportTicketsPage })));
const PartnerNotificationsPage = lazy(() => import("../pages/partner/PartnerNotificationsPage").then((module) => ({ default: module.PartnerNotificationsPage })));
const PartnerActivityLogPage = lazy(() => import("../pages/partner/PartnerActivityLogPage").then((module) => ({ default: module.PartnerActivityLogPage })));
const PartnerKnowledgeBasePage = lazy(() => import("../pages/partner/PartnerKnowledgeBasePage").then((module) => ({ default: module.PartnerKnowledgeBasePage })));
const PartnerSettingsPage = lazy(() => import("../pages/partner/PartnerSettingsPage").then((module) => ({ default: module.PartnerSettingsPage })));
const AdminDashboardPage = lazy(() => import("../pages/admin/AdminDashboardPage").then((module) => ({ default: module.AdminDashboardPage })));
const AdminUsersPage = lazy(() => import("../pages/admin/AdminUsersPage").then((module) => ({ default: module.AdminUsersPage })));
const AdminStudentsPage = lazy(() => import("../pages/admin/AdminStudentsResponsivePage").then((module) => ({ default: module.AdminStudentsResponsivePage })));
const AdminStudentDocumentsPage = lazy(() => import("../pages/admin/AdminStudentDocumentsPage").then((module) => ({ default: module.AdminStudentDocumentsPage })));
const AdminStudentNotificationsPage = lazy(() => import("../pages/admin/AdminStudentNotificationsPage").then((module) => ({ default: module.AdminStudentNotificationsPage })));
const AdminUniversitiesPage = lazy(() => import("../pages/admin/AdminUniversitiesPage").then((module) => ({ default: module.AdminUniversitiesPage })));
const AdminProgramsPage = lazy(() => import("../pages/admin/AdminProgramsPage").then((module) => ({ default: module.AdminProgramsPage })));
const AdminApplicationsPage = lazy(() => import("../pages/admin/AdminApplicationsPage").then((module) => ({ default: module.AdminApplicationsPage })));
const AdminContentPage = lazy(() => import("../pages/admin/AdminContentPage").then((module) => ({ default: module.AdminContentPage })));
const AdminRecognitionsPage = lazy(() => import("../pages/admin/AdminRecognitionsPage").then((module) => ({ default: module.AdminRecognitionsPage })));
const AdminServicesPage = lazy(() => import("../pages/admin/AdminServicesPage").then((module) => ({ default: module.AdminServicesPage })));
const AdminFaqsPage = lazy(() => import("../pages/admin/AdminFaqsPage").then((module) => ({ default: module.AdminFaqsPage })));
const AdminTestimonialsPage = lazy(() => import("../pages/admin/AdminTestimonialsPage").then((module) => ({ default: module.AdminTestimonialsPage })));
const AdminSiteSettingsPage = lazy(() => import("../pages/admin/AdminSiteSettingsPage").then((module) => ({ default: module.AdminSiteSettingsPage })));
const AdminAgencyRequestsPage = lazy(() => import("../pages/admin/AdminAgencyRequestsPage").then((module) => ({ default: module.AdminAgencyRequestsPage })));
const AdminAgentsPage = lazy(() => import("../pages/admin/AdminAgentsResponsivePage").then((module) => ({ default: module.AdminAgentsResponsivePage })));
const AdminPartnerStudentsPage = lazy(() => import("../pages/admin/AdminPartnerStudentsPage").then((module) => ({ default: module.AdminPartnerStudentsPage })));
const AdminMarketingAssetsPage = lazy(() => import("../pages/admin/AdminMarketingAssetsEnhancedPage").then((module) => ({ default: module.AdminMarketingAssetsEnhancedPage })));
const AdminVerificationQueuePage = lazy(() => import("../pages/admin/AdminVerificationQueueTablePage").then((module) => ({ default: module.AdminVerificationQueueTablePage })));
const AdminPayoutRequestsPage = lazy(() => import("../pages/admin/AdminPayoutRequestsTablePage").then((module) => ({ default: module.AdminPayoutRequestsTablePage })));
const AdminSupportTicketsPage = lazy(() => import("../pages/admin/AdminSupportTicketsEnhancedPage").then((module) => ({ default: module.AdminSupportTicketsEnhancedPage })));
const AdminKnowledgeBasePage = lazy(() => import("../pages/admin/AdminKnowledgeBaseEnhancedPage").then((module) => ({ default: module.AdminKnowledgeBaseEnhancedPage })));
const AdminStudentFinancialsPage = lazy(() => import("../pages/admin/AdminStudentFinancialsEnhancedPage").then((module) => ({ default: module.AdminStudentFinancialsEnhancedPage })));
const AdminStudentArrivalRequestsPage = lazy(() => import("../pages/admin/AdminStudentArrivalRequestsEnhancedPage").then((module) => ({ default: module.AdminStudentArrivalRequestsEnhancedPage })));
const AdminStudentFavoritesPage = lazy(() => import("../pages/admin/AdminStudentFavoritesEnhancedPage").then((module) => ({ default: module.AdminStudentFavoritesEnhancedPage })));
const AdminStudentOrientationResultsPage = lazy(() => import("../pages/admin/AdminStudentOrientationResultsEnhancedPage").then((module) => ({ default: module.AdminStudentOrientationResultsEnhancedPage })));
const AdminExhibitionsPage = lazy(() => import("../pages/admin/AdminExhibitionsPage").then((module) => ({ default: module.AdminExhibitionsPage })));
const AdminEventsPage = lazy(() => import("../pages/admin/AdminEventsPage").then((module) => ({ default: module.AdminEventsPage })));
const AdminOurStoryPage = lazy(() => import("../pages/admin/AdminOurStoryPage").then((module) => ({ default: module.AdminOurStoryPage })));
// NEW — parent/university portals + admin role-management pages
const AdminParentLinksPage = lazy(() => import("../pages/admin/AdminParentLinksPage").then((module) => ({ default: module.AdminParentLinksPage })));
const AdminUniversityAccountsPage = lazy(() => import("../pages/admin/AdminUniversityAccountsPage").then((module) => ({ default: module.AdminUniversityAccountsPage })));
const AdminEmployeesPage = lazy(() => import("../pages/admin/AdminEmployeesPage").then((module) => ({ default: module.AdminEmployeesPage })));
const ParentDashboardPage = lazy(() => import("../pages/parent/ParentDashboardPage").then((module) => ({ default: module.ParentDashboardPage })));
const ParentChildOverviewPage = lazy(() => import("../pages/parent/ParentChildOverviewPage").then((module) => ({ default: module.ParentChildOverviewPage })));
const UniversityApplicationsPage = lazy(() => import("../pages/university/UniversityApplicationsPage").then((module) => ({ default: module.UniversityApplicationsPage })));
const UniversityApplicationDetailPage = lazy(() => import("../pages/university/UniversityApplicationDetailPage").then((module) => ({ default: module.UniversityApplicationDetailPage })));

const RouteFallback = () => {
  const { language } = useLanguage();
  return <div className="panel p-8 text-sm text-slate-500">{language === "ar" ? "جارٍ التحميل..." : "Loading..."}</div>;
};

export const AppRoutes = () => (
  <Suspense fallback={<RouteFallback />}>
    <Routes>
      <Route element={<MainLayout />}>
        <Route path="/" element={<HomePage />} />
        <Route path="/privacy-policy" element={<PrivacyPolicyPage />} />
        <Route path="/mobile-sign-in" element={<MobileSignInPage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="/forgot-password" element={<ForgotPasswordPage />} />
        <Route path="/programs" element={<ProgramsPage />} />
        <Route path="/programs/:id" element={<ProgramDetailsPage />} />
        <Route path="/universities" element={<UniversitiesPage />} />
        <Route path="/universities/:id" element={<UniversityDetailsPage />} />
        <Route path="/destinations" element={<StudyDestinationsPage />} />
        <Route path="/services" element={<ServicesPage />} />
        <Route path="/services/:slug" element={<ServiceDetailsPage />} />
        <Route path="/recognitions/:slug" element={<RecognitionDetailsPage />} />
        <Route path="/blog" element={<ExhibitionsPage />} />
        <Route path="/blog/category/:categorySlug" element={<BlogCategoryPage />} />
        <Route path="/blog/:slug" element={<ExhibitionDetailsPage />} />
        <Route path="/exhibitions" element={<Navigate replace to="/blog" />} />
        <Route path="/exhibitions/:slug" element={<ExhibitionDetailsPage />} />
        <Route path="/about" element={<AboutPage />} />
        <Route path="/our-event" element={<OurEventPage />} />
        <Route path="/our-story" element={<OurStoryPage />} />
        <Route path="/contact" element={<ContactPage />} />
        <Route path="/faqs" element={<FaqPage />} />
        <Route path="/partner" element={<PartnerPage />} />
        <Route path="/become-agent" element={<BecomeAgentPage />} />
      </Route>

      <Route element={<ProtectedRoute />}><Route element={<MainLayout />}><Route path="/account/security" element={<AccountSecurityPage />} /></Route></Route>
      <Route element={<ProtectedRoute roles={["student"]} />}>
        <Route element={<DashboardLayout />}>
          <Route path="/student" element={<StudentDashboardPage />} />
          <Route path="/student/overview" element={<Navigate replace to="/student" />} />
          <Route path="/student/profile" element={<StudentProfilePage />} />
          <Route path="/student/documents" element={<StudentDocumentsPage />} />
          <Route path="/student/applications" element={<StudentApplicationsPage />} />
          <Route path="/student/notifications" element={<StudentNotificationsPage />} />
          <Route path="/student/consultations" element={<ConsultationsPage />} />
          <Route path="/student/support" element={<StudentSupportPage />} />
          <Route path="/student/resources" element={<StudentResourcesPage />} />
          <Route path="/student/financials" element={<StudentFinancialsPage />} />
          <Route path="/student/arrival-services" element={<StudentArrivalServicesPage />} />
          <Route path="/student/favorites" element={<StudentFavoritesPage />} />
          <Route path="/student/orientation-test" element={<StudentOrientationTestPage />} />
          <Route path="/student/settings" element={<StudentProfilePage />} />
          <Route path="/student/become-agent" element={<StudentBecomeAgentPage />} />
        </Route>
      </Route>

      <Route element={<ProtectedRoute roles={["partner"]} />}>
        <Route element={<DashboardLayout />}>
          <Route path="/partner/dashboard" element={<PartnerDashboardPage />} />
          <Route path="/partner/students" element={<PartnerStudentsPage />} />
          <Route path="/partner/wallet" element={<PartnerWalletPage />} />
          <Route path="/partner/referral" element={<PartnerReferralPage />} />
          <Route path="/partner/marketing-toolkit" element={<PartnerMarketingToolkitPage />} />
          <Route path="/partner/verification" element={<PartnerVerificationPage />} />
          <Route path="/partner/tickets" element={<PartnerSupportTicketsPage />} />
          <Route path="/partner/notifications" element={<PartnerNotificationsPage />} />
          <Route path="/partner/activity-log" element={<PartnerActivityLogPage />} />
          <Route path="/partner/knowledge-base" element={<PartnerKnowledgeBasePage />} />
          <Route path="/partner/profile" element={<StudentProfilePage />} />
          <Route path="/partner/settings" element={<PartnerSettingsPage />} />
        </Route>
      </Route>

      <Route element={<ProtectedRoute roles={["admin", "employee"]} />}>
        <Route element={<DashboardLayout />}>
          <Route path="/admin" element={<AdminDashboardPage />} />
          <Route path="/employee" element={<Navigate replace to="/admin" />} />
          <Route path="/admin/users" element={<AdminUsersPage />} />
          <Route path="/admin/students" element={<AdminStudentsPage />} />
          <Route path="/admin/students/:id" element={<AdminStudentsPage />} />
          <Route path="/admin/student-documents" element={<AdminStudentDocumentsPage />} />
          <Route path="/admin/student-notifications" element={<AdminStudentNotificationsPage />} />
          <Route path="/admin/universities" element={<AdminUniversitiesPage />} />
          <Route path="/admin/programs" element={<AdminProgramsPage />} />
          <Route path="/admin/applications" element={<AdminApplicationsPage />} />
          <Route path="/admin/content" element={<AdminContentPage />} />
          <Route path="/admin/recognitions" element={<AdminRecognitionsPage />} />
          <Route path="/admin/services" element={<AdminServicesPage />} />
          <Route path="/admin/faqs" element={<AdminFaqsPage />} />
          <Route path="/admin/testimonials" element={<AdminTestimonialsPage />} />
          <Route path="/admin/site-settings" element={<AdminSiteSettingsPage />} />
          <Route path="/admin/agency-requests" element={<AdminAgencyRequestsPage />} />
          <Route path="/admin/agents" element={<AdminAgentsPage />} />
          <Route path="/admin/agents/:id" element={<AdminAgentsPage />} />
          <Route path="/admin/partner-students" element={<AdminPartnerStudentsPage />} />
          <Route path="/admin/marketing-assets" element={<AdminMarketingAssetsPage />} />
          <Route path="/admin/verification-queue" element={<AdminVerificationQueuePage />} />
          <Route path="/admin/payout-requests" element={<AdminPayoutRequestsPage />} />
          <Route path="/admin/consultations" element={<ConsultationsPage staff />} />
          <Route path="/admin/support-tickets" element={<AdminSupportTicketsPage />} />
          <Route path="/admin/knowledge-base" element={<AdminKnowledgeBasePage />} />
          <Route path="/admin/student-financials" element={<AdminStudentFinancialsPage />} />
          <Route path="/admin/student-arrivals" element={<AdminStudentArrivalRequestsPage />} />
          <Route path="/admin/student-favorites" element={<AdminStudentFavoritesPage />} />
          <Route path="/admin/student-orientation-results" element={<AdminStudentOrientationResultsPage />} />
          <Route path="/admin/exhibitions" element={<AdminExhibitionsPage />} />
          <Route path="/admin/events" element={<AdminEventsPage />} />
          <Route path="/admin/our-story" element={<AdminOurStoryPage />} />
          {/* NEW */}
          <Route path="/admin/parent-links" element={<AdminParentLinksPage />} />
          <Route path="/admin/university-accounts" element={<AdminUniversityAccountsPage />} />
          <Route path="/admin/employees" element={<AdminEmployeesPage />} />
        </Route>
      </Route>

      {/* NEW — Parent portal */}
      <Route element={<ProtectedRoute roles={["parent"]} />}>
        <Route element={<DashboardLayout />}>
          <Route path="/parent" element={<ParentDashboardPage />} />
          <Route path="/parent/children/:id" element={<ParentChildOverviewPage />} />
        </Route>
      </Route>

      {/* NEW — University portal */}
      <Route element={<ProtectedRoute roles={["university"]} />}>
        <Route element={<DashboardLayout />}>
          <Route path="/university" element={<UniversityApplicationsPage />} />
          <Route path="/university/applications/:id" element={<UniversityApplicationDetailPage />} />
        </Route>
      </Route>

      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  </Suspense>
);
