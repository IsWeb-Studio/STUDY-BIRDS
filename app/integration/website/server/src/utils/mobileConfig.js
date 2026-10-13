const modules = [
  ["overview", "الرئيسية"], ["universities", "الجامعات"], ["programs", "التخصصات"],
  ["countries", "الدول"], ["applications", "طلباتي"], ["documents", "مستنداتي"],
  ["financials", "المدفوعات"], ["arrival-services", "الوصول والسكن"],
  ["support-tickets", "الدعم والمحادثات"], ["notifications", "الإشعارات"],
  ["favorites", "المفضلة"], ["knowledge-base", "دليل الطالب"],
  ["orientation-test", "التوجيه الدراسي"], ["profile", "الملف الشخصي"],
  ["scholarships", "المنح الدراسية"], ["visa", "التأشيرة"], ["travel", "السفر"],
  ["accommodation", "السكن"], ["services", "الخدمات"], ["consultations", "الاستشارات"],
  ["calendar", "المواعيد المهمة"], ["team", "فريق الدعم"], ["insurance", "التأمين"],
  ["equivalency", "المعادلة"], ["registration", "التسجيل الجامعي"],
];
const contentModules = modules.slice(14).map(([key]) => key);
modules.push(
  ['search', 'البحث الشامل'], ['program-finder', 'مكتشف البرامج'], ['messages', 'المحادثات'],
  ['activity', 'سجل النشاط'], ['settings', 'الإعدادات والأمان'], ['referral', 'برنامج الإحالة'],
  ['student-wallet', 'محفظتي'], ['emergency', 'دعم الطوارئ'], ['bird-ai', 'Bird AI'],
  ['parent-students', 'متابعة الأبناء'], ['parent-applications', 'طلبات الأبناء'],
  ['university-applications', 'طلبات القبول'], ['employee-students', 'قائمة الطلاب'],
  ['employee-applications', 'طلبات الطلاب'], ['employee-tasks', 'مهام الموظف'], ['employee-manager', 'نظرة المدير'],
);
modules.push(
  ["partner-overview", "لوحة الوكيل"], ["partner-agent-students", "طلابي"],
  ["partner-wallet", "المحفظة والعمولات"], ["partner-referral", "الإحالات"],
  ["partner-marketing", "المواد التسويقية"], ["partner-verification", "توثيق الحساب"],
  ["partner-support-tickets", "دعم الوكيل"], ["partner-notifications", "إشعارات الوكيل"],
  ["partner-activity", "سجل نشاط الوكيل"], ["partner-knowledge-base", "دليل الوكيل"],
  ["partner-profile", "حساب الوكيل"],
);
const defaults = () => ({
  title: "Study Birds", welcome: "رحلتك الدراسية تبدأ هنا", primaryColor: "#102B4E",
  maintenance: false, maintenanceMessage: "التطبيق تحت الصيانة، يرجى المحاولة لاحقاً.",
  supportEmail: "", supportPhone: "", banners: [],
  modules: modules.map(([key, title], order) => ({ key, title, enabled: true, order })),
});
const fail = (message) => { const error = new Error(message); error.statusCode = 400; throw error; };
const string = (value, max = 500) => typeof value === "string" && value.length <= max;
const safeUrl = (value) => !value || (string(value, 2000) && /^https:\/\//i.test(value));
function validateSettings(input) {
  if (!input || !string(input.title, 80) || !input.title.trim() || !string(input.welcome) ||
      !/^#[0-9a-f]{6}$/i.test(input.primaryColor) || typeof input.maintenance !== "boolean" ||
      !string(input.maintenanceMessage) || !string(input.supportEmail, 150) || !string(input.supportPhone, 50)) fail("Invalid application settings");
  if (!Array.isArray(input.modules) || input.modules.length !== modules.length) fail("All modules are required");
  const keys = new Set();
  const cleanModules = input.modules.map((item) => {
    if (!item || !modules.some(([key]) => key === item.key) || keys.has(item.key) || !string(item.title, 80) || !item.title.trim() || typeof item.enabled !== "boolean" || !Number.isInteger(item.order) || item.order < 0 || item.order > 1000) fail("Invalid module");
    keys.add(item.key);
    return { key: item.key, title: item.title.trim(), enabled: item.enabled, order: item.order };
  });
  if (!Array.isArray(input.banners) || input.banners.length > 20) fail("Maximum 20 banners");
  const banners = input.banners.map((item) => {
    if (!item || !string(item.title, 150) || !safeUrl(item.imageUrl) || !safeUrl(item.linkUrl)) fail("Invalid banner; use HTTPS links");
    return { title: item.title, imageUrl: item.imageUrl || "", linkUrl: item.linkUrl || "" };
  });
  return { title: input.title.trim(), welcome: input.welcome, primaryColor: input.primaryColor,
    maintenance: input.maintenance, maintenanceMessage: input.maintenanceMessage,
    supportEmail: input.supportEmail, supportPhone: input.supportPhone, modules: cleanModules, banners };
}
function validateContent(input) {
  if (!input || !contentModules.includes(input.section) || !string(input.title, 150) || !input.title.trim() ||
      !string(input.body, 20000) || !safeUrl(input.imageUrl) || !safeUrl(input.linkUrl) ||
      typeof input.published !== "boolean" || typeof input.requestable !== "boolean" ||
      !Number.isInteger(input.order) || Math.abs(input.order) > 10000 ||
      (input.date && !Number.isFinite(Date.parse(input.date)))) fail("Invalid content");
  return { section: input.section, title: input.title.trim(), body: input.body, imageUrl: input.imageUrl || "",
    linkUrl: input.linkUrl || "", published: input.published, requestable: input.requestable, order: input.order, date: input.date || null };
}
module.exports = { modules, contentModules, defaults, validateSettings, validateContent };
