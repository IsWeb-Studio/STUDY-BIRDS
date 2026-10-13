import {
  Award,
  Bell,
  BriefcaseBusiness,
  Building2,
  CalendarClock,
  CircleDollarSign,
  Compass,
  FileText,
  GraduationCap,
  HelpCircle,
  Layers3,
  LayoutDashboard,
  MessageSquare,
  NotebookText,
  ScrollText,
  Settings2,
  Share2,
  ShieldCheck,
  Users,
  Video,
} from "lucide-react";
import { Link, Navigate, useLocation, Outlet } from "react-router-dom";
import { useEffect, useState } from "react";
import { Navbar } from "../components/Navbar";
import { DashboardSidebar } from "../components/dashboard/DashboardSidebar";
import { Seo } from "../components/seo/Seo";
import { useAuth } from "../hooks/useAuth";
import { useLanguage } from "../hooks/useLanguage";
import { seoText } from "../seo/site";
import { dt } from "../utils/dashboardTranslations";

export const DashboardLayout = () => {
  const { user } = useAuth();
  const location = useLocation();
  const [mode, setMode] = useState(() => sessionStorage.getItem("studyBirdsAdminMode") || "site");
  const mobile = location.pathname.startsWith("/admin/mobile") || mode === "mobile";
  const chooseMode = (next: string) => { setMode(next); sessionStorage.setItem("studyBirdsAdminMode", next); };
  useEffect(() => {
    if (location.pathname.startsWith("/admin/mobile")) { setMode("mobile"); sessionStorage.setItem("studyBirdsAdminMode", "mobile"); }
  }, [location.pathname]);
  const { t, language } = useLanguage();
  const isPartner = user?.role === "partner";

  const studentLinks = [
    { label: language === "ar" ? "لوحة الطالب" : "Student Dashboard", href: "/student", icon: LayoutDashboard, description: language === "ar" ? "ملخص شامل لحالة القبول والمستندات والإشعارات." : "Executive overview of your admission progress, documents, and alerts." },
    { label: language === "ar" ? "طلباتي" : "My Applications", href: "/student/applications", icon: GraduationCap, description: language === "ar" ? "تابع الجامعات والتخصصات وحالة كل طلب." : "Track universities, programs, and each application status." },
    { label: language === "ar" ? "مستنداتي" : "My Documents", href: "/student/documents", icon: FileText, description: language === "ar" ? "ارفع مستنداتك وراجع حالتها وملاحظات المراجعة." : "Upload your documents and review their status and notes." },
    { label: language === "ar" ? "المالية والفواتير" : "Financials & Invoices", href: "/student/financials", icon: CircleDollarSign, description: language === "ar" ? "تابع الدفعات والمطالبات المالية." : "Track payments, invoices, and financial obligations." },
    { label: language === "ar" ? "الوصول والخدمات" : "Arrival & Services", href: "/student/arrival-services", icon: Compass, description: language === "ar" ? "خدمات الوصول والسكن والاستقبال." : "Arrival, housing, and airport-related services." },
    { label: language === "ar" ? "الدعم والمحادثة" : "Support & Chat", href: "/student/support", icon: HelpCircle, description: language === "ar" ? "افتح تذكرة جديدة وتابع الردود." : "Open support tickets and follow replies." },
    { label: language === "ar" ? "الإشعارات" : "Notifications", href: "/student/notifications", icon: Bell, description: language === "ar" ? "كل تحديثات الطلبات والمستندات والدعم." : "All updates about applications, documents, and support." },
    { label: language === "ar" ? "المفضلة والمقارنة" : "My Favorites & Compare", href: "/student/favorites", icon: Layers3, description: language === "ar" ? "حفظ الجامعات والبرامج ومقارنتها." : "Save universities and programs and compare them." },
    { label: language === "ar" ? "دليل الطالب" : "Student Guide / Resources", href: "/student/resources", icon: NotebookText, description: language === "ar" ? "مواد إرشادية وروابط وفيديوهات مهمة." : "Guides, links, and important student resources." },
    { label: language === "ar" ? "اختبار التوجيه" : "Orientation Test", href: "/student/orientation-test", icon: ScrollText, description: language === "ar" ? "استبيان يساعدك على تحديد التخصص الأنسب." : "A guided assessment to help identify suitable study paths." },
    { label: language === "ar" ? "الملف الشخصي" : "Profile", href: "/student/profile", icon: Settings2, description: language === "ar" ? "بياناتك الشخصية والأكاديمية الأساسية." : "Your personal and academic profile details." },
    { label: language === "ar" ? "الإعدادات" : "Settings", href: "/student/settings", icon: Settings2, description: language === "ar" ? "أمان الحساب وكلمة المرور." : "Account security and password settings." },
    { label: dt(language, "becomeAgentNav"), href: "/student/become-agent", icon: BriefcaseBusiness, description: dt(language, "becomeAgentNavDesc") },
  ];

  const partnerLinks = [
    { label: language === "ar" ? "لوحة التحكم" : "Dashboard", href: "/partner/dashboard", icon: LayoutDashboard, description: language === "ar" ? "ملخص شامل لحساب الوكيل." : "Executive overview of your agent workspace." },
    { label: language === "ar" ? "طلابي" : "My Students", href: "/partner/students", icon: Users, description: language === "ar" ? "إدارة الطلاب والطلبات الخاصة بك." : "Manage your students and submissions." },
    { label: language === "ar" ? "المحفظة والعمولات" : "Wallet & Financials", href: "/partner/wallet", icon: CircleDollarSign, description: language === "ar" ? "تابع الأرباح والسحوبات." : "Track earnings and payout requests." },
    { label: language === "ar" ? "رابط الإحالة" : "Affiliate & Referral Link", href: "/partner/referral", icon: Share2, description: language === "ar" ? "رابط الإحالة وإحصاءاته." : "Referral link and conversion metrics." },
    { label: language === "ar" ? "المواد التسويقية" : "Marketing Toolkit", href: "/partner/marketing-toolkit", icon: Layers3, description: language === "ar" ? "ملفات تسويقية جاهزة للتحميل." : "Downloadable marketing assets." },
    { label: language === "ar" ? "توثيق الحساب" : "Account Verification", href: "/partner/verification", icon: ShieldCheck, description: language === "ar" ? "رفع مستندات التوثيق ومتابعة الحالة." : "Upload verification documents and track review." },
    { label: language === "ar" ? "تذاكر الدعم" : "Support Tickets", href: "/partner/tickets", icon: HelpCircle, description: language === "ar" ? "تواصل مع الإدارة عبر التذاكر." : "Open and follow support conversations." },
    { label: language === "ar" ? "مركز الإشعارات" : "Notifications Center", href: "/partner/notifications", icon: Bell, description: language === "ar" ? "كل تحديثات الطلبات والعمولات." : "All account and student updates." },
    { label: language === "ar" ? "سجل النشاط" : "Activity Log", href: "/partner/activity-log", icon: NotebookText, description: language === "ar" ? "عمليات الحساب الأخيرة." : "Recent actions in your workspace." },
    { label: language === "ar" ? "قاعدة المعرفة" : "Knowledge Base", href: "/partner/knowledge-base", icon: FileText, description: language === "ar" ? "شروحات ومواد تدريبية." : "Tutorials, guides, and FAQs." },
    { label: language === "ar" ? "الملف الشخصي" : "Profile", href: "/partner/profile", icon: Settings2, description: language === "ar" ? "بيانات المكتب أو الشركة." : "Company and account profile details." },
    { label: language === "ar" ? "الإعدادات" : "Settings", href: "/partner/settings", icon: Settings2, description: language === "ar" ? "إعدادات الأمان وكلمة المرور." : "Password and account security settings." },
  ];

  const adminLinks = [
    { label: t("overview"), href: "/admin", icon: LayoutDashboard, description: dt(language, "executiveSummary") },
    { label: dt(language, "users"), href: "/admin/users", icon: Users, description: dt(language, "userAccessDesc") },
    { label: language === "ar" ? "ملفات الطلاب" : "Student Profiles", href: "/admin/students", icon: GraduationCap, description: language === "ar" ? "الملف الشخصي الكامل لكل طالب مع جميع الوحدات المرتبطة به." : "Each student profile with linked operational modules." },
    { label: language === "ar" ? "طلبات الطلاب" : "Student Applications", href: "/admin/applications", icon: FileText, description: language === "ar" ? "متابعة نفس قسم طلباتي الموجود في لوحة الطالب." : "Admin view for the same application flow used by students." },
    { label: language === "ar" ? "مستندات الطلاب" : "Student Documents", href: "/admin/student-documents", icon: FileText, description: language === "ar" ? "مراجعة ملفات ومستندات الطلاب المرفوعة." : "Review uploaded student documents." },
    { label: language === "ar" ? "مالية الطلاب" : "Student Financials", href: "/admin/student-financials", icon: CircleDollarSign, description: language === "ar" ? "إدارة الفواتير وإثباتات الدفع الخاصة بالطلاب." : "Manage student invoices and payment proofs." },
    { label: language === "ar" ? "وصول الطلاب" : "Student Arrivals", href: "/admin/student-arrivals", icon: Compass, description: language === "ar" ? "تنسيق الوصول والسكن والخدمات المساندة." : "Coordinate student arrival, housing, and support services." },
    { label: language === "ar" ? "دعم الطلاب" : "Student Support", href: "/admin/support-tickets", icon: HelpCircle, description: language === "ar" ? "الرد على تذاكر الدعم القادمة من الطلاب." : "Respond to student support conversations." },
    { label: language === "ar" ? "إشعارات الطلاب" : "Student Notifications", href: "/admin/student-notifications", icon: Bell, description: language === "ar" ? "متابعة التنبيهات والإشعارات المرسلة للطلاب." : "Track notifications sent to students." },
    { label: language === "ar" ? "مفضلة الطلاب" : "Student Favorites", href: "/admin/student-favorites", icon: Layers3, description: language === "ar" ? "تحليل اهتمامات الطلاب المحفوظة." : "Review saved universities and programs across students." },
    { label: language === "ar" ? "دليل الطالب" : "Student Resources", href: "/admin/knowledge-base", icon: NotebookText, description: language === "ar" ? "إدارة نفس مواد دليل الطالب والموارد." : "Manage the same student resources and guide content." },
    { label: language === "ar" ? "اختبار التوجيه" : "Student Orientation", href: "/admin/student-orientation-results", icon: ScrollText, description: language === "ar" ? "عرض نتائج اختبار التوجيه للطلاب." : "Review student orientation test outcomes." },
    { label: t("universities"), href: "/admin/universities", icon: Building2, description: dt(language, "institutionsDesc") },
    { label: t("programs"), href: "/admin/programs", icon: GraduationCap, description: dt(language, "programsDesc") },
    { label: dt(language, "content"), href: "/admin/content", icon: Layers3, description: dt(language, "contentDesc") },
    { label: dt(language, "testimonialsContent"), href: "/admin/testimonials", icon: MessageSquare, description: dt(language, "testimonialsHelp") },
    { label: dt(language, "contactLinksNav"), href: "/admin/site-settings", icon: Settings2, description: dt(language, "contactLinksNavDesc") },
    { label: dt(language, "recognitionsNav"), href: "/admin/recognitions", icon: Award, description: dt(language, "recognitionsNavDesc") },
    { label: dt(language, "servicesNav"), href: "/admin/services", icon: Award, description: dt(language, "servicesNavDesc") },
    { label: dt(language, "faqsNav"), href: "/admin/faqs", icon: MessageSquare, description: dt(language, "faqsNavDesc") },
    { label: dt(language, "agencyRequestsNav"), href: "/admin/agency-requests", icon: BriefcaseBusiness, description: dt(language, "agencyRequestsNavDesc") },
    { label: language === "ar" ? "كل الوكلاء" : "All Agents", href: "/admin/agents", icon: Users, description: language === "ar" ? "عرض ملف كل وكيل وطلابه وبياناته التشغيلية." : "View each agent profile, students, and operational details." },
    { label: language === "ar" ? "طلاب الوكلاء" : "Partner Students", href: "/admin/partner-students", icon: Users, description: language === "ar" ? "قراءة بيانات الطلاب الذين أضافهم الوكلاء وتغيير حالة ملفاتهم." : "Review agent-added students and update their file status." },
    { label: language === "ar" ? "المواد التسويقية" : "Marketing Assets", href: "/admin/marketing-assets", icon: Layers3, description: language === "ar" ? "رفع وإدارة ملفات التسويق الخاصة بالوكلاء." : "Manage files shown in the agent marketing toolkit." },
    { label: language === "ar" ? "توثيق الوكلاء" : "Verification Queue", href: "/admin/verification-queue", icon: ShieldCheck, description: language === "ar" ? "مراجعة مستندات توثيق الوكلاء." : "Review partner verification documents." },
    { label: language === "ar" ? "طلبات السحب" : "Payout Requests", href: "/admin/payout-requests", icon: CircleDollarSign, description: language === "ar" ? "اعتماد أو رفض طلبات سحب الأرباح." : "Review and update payout requests." },
    { label: language === "ar" ? "دعم الوكلاء" : "Agent Support", href: "/admin/support-tickets", icon: HelpCircle, description: language === "ar" ? "الرد على تذاكر دعم الوكلاء." : "Respond to agent support conversations." },
    { label: language === "ar" ? "قاعدة معرفة الوكلاء" : "Agent Knowledge Base", href: "/admin/knowledge-base", icon: NotebookText, description: language === "ar" ? "إدارة محتوى الشروحات والتدريب." : "Manage training and tutorial content." },
    {
      label: language === "ar" ? "فعاليتنا" : "Our Event",
      href: "/admin/events",
      icon: CalendarClock,
      description: language === "ar" ? "إدارة الفعالية القادمة والفعاليات السابقة وتسجيلات الطلاب." : "Manage the upcoming event, past events, and student registrations.",
    },
    {
      label: language === "ar" ? "قصتنا" : "Our Story",
      href: "/admin/our-story",
      icon: ScrollText,
      description: language === "ar" ? "إدارة صفحة قصتنا: الواجهة العلوية، القصة، المؤسسون، والتاريخ." : "Manage the story page hero, founders, timeline, and impact.",
    },
    {
      label: language === "ar" ? "محطة المعارض" : "Exhibitions Station",
      href: "/admin/exhibitions",
      icon: Video,
      description: language === "ar" ? "إدارة المقالات وروابط فيديو يوتيوب." : "Manage articles and YouTube video links.",
    },
  ];

  if (user?.role === "admin" && mobile && !location.pathname.startsWith("/admin/mobile")) {
    return <Navigate replace to={`${location.pathname === "/admin" ? "/admin/mobile" : location.pathname.replace("/admin/", "/admin/mobile/manage/")}${location.search}${location.hash}`} />;
  }
  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_#d8e1f1_0%,_#f6f8fc_40%,_#f8fafc_100%)]">
      <Seo
        title={
          user?.role === "admin"
            ? seoText(language, "Admin Dashboard", "لوحة الإدارة")
            : isPartner
              ? seoText(language, "Agent Dashboard", "لوحة وكيل Study Birds")
              : seoText(language, "Student Dashboard", "لوحة الطالب")
        }
        description={
          user?.role === "admin"
            ? seoText(language, "Private admin workspace for Study Birds.", "مساحة إدارية خاصة لمنصة Study Birds.")
            : isPartner
              ? seoText(language, "Private agent workspace for Study Birds.", "مساحة وكيل خاصة داخل Study Birds.")
              : seoText(language, "Private student workspace for Study Birds.", "مساحة خاصة للطالب داخل Study Birds.")
        }
        noIndex
      />
      <Navbar />
      {user?.role === "admin" && <nav aria-label="تبديل لوحة التحكم" className="container-shell flex flex-wrap gap-3 pt-6" dir="rtl">
        <Link to="/admin" onClick={() => chooseMode("site")} className={`rounded-xl border px-5 py-3 font-bold ${!mobile ? "bg-slate-900 text-white" : "bg-white"}`}>لوحة تحكم الموقع</Link>
        <Link to="/admin/mobile" onClick={() => chooseMode("mobile")} className={`rounded-xl border px-5 py-3 font-bold ${mobile ? "bg-slate-900 text-white" : "bg-white"}`}>لوحة تحكم التطبيق</Link>
      </nav>}
      <main className="container-shell grid gap-6 py-8 lg:grid-cols-[320px_1fr]">
        <DashboardSidebar
          links={user?.role === "admin" ? (mobile ? adminLinks.map((link) => ({ ...link, href: link.href === "/admin" ? "/admin/mobile" : link.href.replace("/admin/", "/admin/mobile/manage/") })) : adminLinks) : isPartner ? partnerLinks : studentLinks}
          sectionLabel={user?.role === "admin" ? dt(language, "controlCenter") : isPartner ? (language === "ar" ? "بوابة الوكيل" : "Agent Hub") : dt(language, "profileHub")}
          title={user?.role === "admin" ? dt(language, "adminTitle") : isPartner ? (language === "ar" ? "لوحة الوكيل" : "Agent Dashboard") : (language === "ar" ? "لوحة الطالب" : "Student Dashboard")}
          subtitle={user?.role === "admin" ? dt(language, "manageUsersContent") : isPartner ? (language === "ar" ? "إدارة الطلاب والعمولات والتوثيق من مكان واحد." : "Manage students, earnings, and verification from one workspace.") : (language === "ar" ? "تابع التقديم والمستندات والإشعارات والدعم من مساحة واحدة." : "Track applications, documents, notifications, and support from one workspace.")}
        />
        <Outlet />
      </main>
    </div>
  );
};
