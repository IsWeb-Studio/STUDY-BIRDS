/// Mirrors server/src/constants/employeeSections.json (and the identical
/// client/src/constants/employeeSections.json) EXACTLY. Keep these three in
/// sync manually — there's no shared package between Dart and JS here.
class EmployeeSection {
  final String key;
  final String labelAr;
  final String labelEn;
  const EmployeeSection({required this.key, required this.labelAr, required this.labelEn});
}

const List<EmployeeSection> kEmployeeSections = [
  EmployeeSection(key: 'students', labelAr: 'ملفات الطلاب الكاملة', labelEn: 'Student profiles (full records)'),
  EmployeeSection(key: 'applications', labelAr: 'طلبات الطلاب', labelEn: 'Applications'),
  EmployeeSection(key: 'student-documents', labelAr: 'مستندات الطلاب', labelEn: 'Student documents'),
  EmployeeSection(key: 'student-financials', labelAr: 'مالية الطلاب', labelEn: 'Student financials'),
  EmployeeSection(key: 'student-arrivals', labelAr: 'وصول الطلاب', labelEn: 'Student arrivals'),
  EmployeeSection(key: 'support', labelAr: 'دعم الطلاب والوكلاء', labelEn: 'Student and agent support'),
  EmployeeSection(key: 'student-notifications', labelAr: 'إشعارات الطلاب', labelEn: 'Student notifications'),
  EmployeeSection(key: 'student-favorites', labelAr: 'مفضلة الطلاب', labelEn: 'Student favorites'),
  EmployeeSection(key: 'knowledge-base', labelAr: 'دليل الطلاب والوكلاء', labelEn: 'Student and agent resources'),
  EmployeeSection(key: 'student-orientation', labelAr: 'اختبار التوجيه', labelEn: 'Student orientation'),
  EmployeeSection(key: 'universities', labelAr: 'الجامعات', labelEn: 'Universities'),
  EmployeeSection(key: 'programs', labelAr: 'التخصصات', labelEn: 'Programs'),
  EmployeeSection(key: 'content', labelAr: 'الدول والمجالات الدراسية', labelEn: 'Countries and study fields'),
  EmployeeSection(key: 'testimonials', labelAr: 'آراء الطلاب', labelEn: 'Testimonials'),
  EmployeeSection(key: 'site-settings', labelAr: 'بيانات التواصل وإعدادات الموقع', labelEn: 'Site settings'),
  EmployeeSection(key: 'recognitions', labelAr: 'الاعتمادات', labelEn: 'Recognitions'),
  EmployeeSection(key: 'services', labelAr: 'الخدمات', labelEn: 'Services'),
  EmployeeSection(key: 'faqs', labelAr: 'الأسئلة الشائعة', labelEn: 'FAQs'),
  EmployeeSection(key: 'agency-requests', labelAr: 'طلبات الوكالة', labelEn: 'Agency requests'),
  EmployeeSection(key: 'agents', labelAr: 'ملفات الوكلاء الكاملة', labelEn: 'Agent profiles (full records)'),
  EmployeeSection(key: 'partner-students', labelAr: 'طلاب الوكلاء', labelEn: 'Partner students'),
  EmployeeSection(key: 'marketing-assets', labelAr: 'المواد التسويقية', labelEn: 'Marketing assets'),
  EmployeeSection(key: 'verification', labelAr: 'توثيق الوكلاء', labelEn: 'Agent verification'),
  EmployeeSection(key: 'payouts', labelAr: 'طلبات السحب', labelEn: 'Payout requests'),
  EmployeeSection(key: 'events', labelAr: 'الفعاليات', labelEn: 'Events'),
  EmployeeSection(key: 'our-story', labelAr: 'قصتنا', labelEn: 'Our story'),
  EmployeeSection(key: 'exhibitions', labelAr: 'محطة المعارض', labelEn: 'Exhibitions'),
  EmployeeSection(key: 'parent-links', labelAr: 'ربط أولياء الأمور', labelEn: 'Parent links'),
  EmployeeSection(key: 'community', labelAr: 'مجتمع الطلاب', labelEn: 'Student community'),
  EmployeeSection(key: 'university-accounts', labelAr: 'حسابات الجامعات', labelEn: 'University accounts'),
  EmployeeSection(key: 'consultations', labelAr: 'الاستشارات والمواعيد', labelEn: 'Consultations'),
];

/// A conservative subset of sections that are actually reachable from
/// SOMETHING in the Flutter app today (most sections above only have a web
/// admin editor so far — the app doesn't have a "manage FAQs" screen etc).
/// Used to decide what to show on an employee's home screen.
const Map<String, String> kEmployeeSectionAppRoute = {
  'students': 'students',
  'applications': 'applications',
  'parent-links': 'parent-links',
  'university-accounts': 'university-accounts',
};

bool hasSection(Set<String> permissions, String key) => permissions.contains(key);
