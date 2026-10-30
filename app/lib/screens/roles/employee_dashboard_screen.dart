import '../../core/utils/json_safe.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/app_notice.dart';
import 'follow_up_reminders_screen.dart';
import 'admin_scholarships_screen.dart';
import '../profile_account/security_settings_screen.dart';
import '../home_journey/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/repositories/employee_repository.dart';
import 'employee_extra_screens.dart';
import 'admin_users_access_screen.dart';
import 'admin_parent_links_screen.dart';
import 'admin_university_accounts_screen.dart';
import 'employee_community_screen.dart';
import 'admin_approval_screens.dart';
import 'admin_applications_documents_screens.dart';
import 'admin_simple_lists_screens.dart';
import 'admin_app_notification_screen.dart';

import 'admin_support_knowledge_screens.dart';
import 'admin_financials_marketing_screens.dart';
import 'admin_content_crud_screens.dart';
import 'admin_singleton_hub_screens.dart';
import 'employee_consultations_screen.dart';
import 'admin_reward_rules_screen.dart';
import 'admin_visa_center_screen.dart';
import 'admin_housing_screen.dart';
import 'admin_wallet_screen.dart';
import '../services_support/student_listings_screen.dart';
import '../profile_account/role_account_tab.dart';
import '../profile_account/my_streak.dart';
import '../../core/widgets/verified_admin_badge.dart';
import '../../main.dart' show RootChooserScreen;
import '../community/student_community_hub.dart';

// ─── Section entry ────────────────────────────────────────────────────────────
class _SectionEntry {
  final String key;
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final WidgetBuilder builder;
  const _SectionEntry(
      this.key, this.icon, this.color, this.label, this.subtitle, this.builder);
}

// ─── Tab definition ───────────────────────────────────────────────────────────
class _TabDef {
  final IconData icon;
  final String label;
  final List<String> keys;
  final bool account;
  final bool community;
  const _TabDef(this.icon, this.label, this.keys,
      {this.account = false, this.community = false});
}

const _studentKeys = [
  'students',
  'applications',
  'student-documents',
  'student-financials',
  'student-arrivals',
  'student-notifications',
  'student-favorites',
  'student-orientation',
  'parent-links',
  'support',
  'service-requests',
];
const _partnerKeys = [
  'agency-requests',
  'agents',
  'partner-students',
  'marketing-assets',
  'verification',
  'payouts',
];
const _managementKeys = [
  'app-notifications', 'university-accounts', 'universities', 'programs', 'content',
  'consultations', 'community', 'knowledge-base', 'testimonials',
  'recognitions', 'services', 'faqs', 'site-settings',
  'our-story', 'exhibitions', 'events',
];

const _allTabDefs = [
  _TabDef(Icons.home_rounded, 'الرئيسية', []),
  _TabDef(Icons.people_rounded, 'الطلاب', _studentKeys),
  _TabDef(Icons.handshake_rounded, 'الشركاء', _partnerKeys),
  _TabDef(Icons.admin_panel_settings_rounded, 'الإدارة', _managementKeys),
  _TabDef(Icons.forum_rounded,
      '\u0645\u062c\u062a\u0645\u0639 \u0627\u0644\u0637\u0644\u0627\u0628', [],
      community: true),
  _TabDef(Icons.person_outline_rounded, 'حسابي', [], account: true),
];

// ─── Section registry ─────────────────────────────────────────────────────────
final List<_SectionEntry> _allSections = [
  _SectionEntry('app-notifications', Icons.campaign_rounded, const Color(0xFFF97316),
      'إشعارات التطبيق', 'إرسال إعلان إلى جميع الحسابات النشطة',
      (_) => const AdminAppNotificationScreen()),
  _SectionEntry('students', Icons.person_search_rounded, AppColors.navy,
      'ملفات الطلاب', 'استعراض وإدارة ملفات الطلاب الكاملة',
      (_) => const MyStudentsQueueScreen()),
  _SectionEntry(
      'applications',
      Icons.description_rounded,
      AppColors.greenInk,
      'طلبات القبول',
      'متابعة الطلبات وتحديث حالاتها',
      (_) => const AdminApplicationsScreen()),
  _SectionEntry(
      'student-documents',
      Icons.folder_open_rounded,
      AppColors.greenInk,
      'مستندات الطلاب',
      'مراجعة المستندات والتحقق منها',
      (_) => const AdminStudentDocumentsScreen()),
  _SectionEntry(
      'student-financials',
      Icons.payments_rounded,
      AppColors.greenInk,
      'مالية الطلاب',
      'متابعة الرسوم والمدفوعات',
      (_) => const AdminStudentFinancialsScreen()),
  _SectionEntry(
      'student-financials',
      Icons.account_balance_wallet_rounded,
      AppColors.greenInk,
      'محافظ الطلاب',
      'تسجيل ومراجعة معاملات أرصدة الطلاب',
      (_) => const AdminWalletScreen()),
  _SectionEntry(
      'student-financials',
      Icons.workspace_premium_rounded,
      AppColors.greenInk,
      'قواعد المكافآت',
      'تحديد قواعد وشروط مكافآت الطلاب',
      (_) => const AdminRewardRulesScreen()),
  _SectionEntry(
      'student-arrivals',
      Icons.flight_land_rounded,
      AppColors.greenInk,
      'وصول الطلاب',
      'تنسيق رحلات الوصول والاستقبال',
      (_) => const AdminArrivalRequestsScreen()),
  _SectionEntry(
      'support',
      Icons.support_agent_rounded,
      AppColors.greenInk,
      'الدعم الفني',
      'متابعة ورد تذاكر الدعم الواردة',
      (_) => const AdminSupportTicketsScreen()),
  _SectionEntry(
      'service-requests',
      Icons.home_repair_service_rounded,
      AppColors.greenInk,
      'طلبات الخدمات',
      'متابعة الطلبات وتحديث حالتها وتعيين المسؤول',
      (_) => const EmployeeServiceRequestsScreen()),
  _SectionEntry(
      'student-notifications',
      Icons.notifications_rounded,
      AppColors.greenInk,
      'إشعارات الطلاب',
      'إرسال إشعارات مخصصة للطلاب',
      (_) => const AdminStudentNotificationsScreen()),
  _SectionEntry(
      'student-favorites',
      Icons.favorite_rounded,
      AppColors.greenInk,
      'المفضلة',
      'استعراض تفضيلات الطلاب وجامعاتهم المفضلة',
      (_) => const AdminStudentFavoritesScreen()),
  _SectionEntry(
      'knowledge-base',
      Icons.menu_book_rounded,
      AppColors.green,
      'دليل المعرفة',
      'إدارة دليل المعلومات للطلاب والوكلاء',
      (_) => const AdminKnowledgeBaseScreen()),
  _SectionEntry(
      'student-orientation',
      Icons.quiz_rounded,
      AppColors.greenInk,
      'اختبار التوجيه',
      'عرض نتائج اختبار توجيه الطلاب',
      (_) => const AdminOrientationResultsScreen()),
  _SectionEntry(
      'parent-links',
      Icons.family_restroom_rounded,
      AppColors.greenInk,
      'ربط أولياء الأمور',
      'ربط أولياء الأمور بحسابات أبنائهم',
      (_) => const AdminParentLinksScreen()),
  _SectionEntry(
      'agency-requests',
      Icons.how_to_reg_rounded,
      AppColors.navy,
      'طلبات الوكالة',
      'مراجعة وقبول طلبات شراكة الوكلاء',
      (_) => const AdminAgencyRequestsScreen()),
  _SectionEntry(
      'agents',
      Icons.badge_rounded,
      AppColors.greenInk,
      'ملفات الوكلاء',
      'استعراض وإدارة ملفات الوكلاء',
      (_) => const AdminAgentsScreen()),
  _SectionEntry(
      'partner-students',
      Icons.group_rounded,
      AppColors.greenInk,
      'طلاب الوكلاء',
      'الطلاب المسجّلون عبر الوكلاء',
      (_) => const AdminPartnerStudentsScreen()),
  _SectionEntry(
      'marketing-assets',
      Icons.campaign_rounded,
      AppColors.greenInk,
      'المواد التسويقية',
      'إدارة المواد التسويقية للوكلاء',
      (_) => const AdminMarketingAssetsScreen()),
  _SectionEntry(
      'verification',
      Icons.verified_rounded,
      AppColors.greenInk,
      'توثيق الوكلاء',
      'مراجعة مستندات توثيق الوكلاء',
      (_) => const AdminVerificationScreen()),
  _SectionEntry(
      'payouts',
      Icons.account_balance_wallet_rounded,
      AppColors.greenInk,
      'طلبات السحب',
      'اعتماد وإدارة طلبات سحب الوكلاء',
      (_) => const AdminPayoutRequestsScreen()),
  _SectionEntry(
      'university-accounts',
      Icons.school_rounded,
      AppColors.navy,
      'حسابات الجامعات',
      'إنشاء وإدارة حسابات بوابات الجامعات',
      (_) => const AdminUniversityAccountsScreen()),
  _SectionEntry(
      'consultations',
      Icons.event_available_rounded,
      AppColors.greenInk,
      'الاستشارات',
      'إدارة الاستشارات والمواعيد المحجوزة',
      (_) => const EmployeeConsultationsScreen()),
  _SectionEntry(
      'visa',
      Icons.flight_takeoff_rounded,
      AppColors.greenInk,
      'مركز التأشيرات',
      'إدارة حالة التأشيرة والمتطلبات والمواعيد والتأمين',
      (_) => const AdminVisaCenterScreen()),
  _SectionEntry(
      'housing',
      Icons.home_work_rounded,
      AppColors.greenInk,
      'السكن الطلابي',
      'إدارة خيارات السكن والحجوزات وطلبات السكن عند الوصول',
      (_) => const AdminHousingScreen()),
  _SectionEntry(
      'universities',
      Icons.account_balance_rounded,
      AppColors.greenInk,
      'الجامعات',
      'إضافة وتعديل بيانات الجامعات',
      (_) => const AdminUniversitiesCrudScreen()),
  _SectionEntry(
      'programs',
      Icons.auto_stories_rounded,
      AppColors.greenInk,
      'التخصصات',
      'إدارة التخصصات والبرامج الدراسية',
      (_) => const AdminProgramsCrudScreen()),
  _SectionEntry(
      'content',
      Icons.public_rounded,
      AppColors.greenInk,
      'الدول والمجالات',
      'إدارة الدول والمجالات الدراسية',
      (_) => const AdminContentHubScreen()),
  _SectionEntry(
      'community',
      Icons.forum_rounded,
      AppColors.greenInk,
      'مجتمع الطلاب',
      'مراقبة وإدارة منشورات المجتمع',
      (_) => const EmployeeCommunityScreen()),
  _SectionEntry(
      'community',
      Icons.local_offer_rounded,
      AppColors.greenInk,
      'عروض الطلاب',
      'إدارة العروض المنشورة في المجتمع',
      (_) => const AdminStudentListingsScreen(kind: 'offer')),
  _SectionEntry(
      'community',
      Icons.work_rounded,
      AppColors.greenInk,
      'فرص العمل',
      'إدارة فرص العمل والتدريب للطلاب',
      (_) => const AdminStudentListingsScreen(kind: 'opportunity')),
  _SectionEntry(
      'testimonials',
      Icons.rate_review_rounded,
      AppColors.greenInk,
      'آراء الطلاب',
      'إضافة وإدارة شهادات الطلاب',
      (_) => const AdminTestimonialsScreen()),
  _SectionEntry(
      'banners',
      Icons.view_carousel_rounded,
      AppColors.navy,
      'البنرات',
      'إدارة بنرات الكاروسيل في التطبيق',
      (_) => const AdminBannersScreen()),
  _SectionEntry(
      'recognitions',
      Icons.workspace_premium_rounded,
      AppColors.greenInk,
      'الاعتمادات',
      'إدارة الاعتمادات الأكاديمية',
      (_) => const AdminRecognitionsScreen()),
  _SectionEntry(
      'services',
      Icons.design_services_rounded,
      AppColors.greenInk,
      'الخدمات',
      'إدارة الخدمات المقدمة للطلاب',
      (_) => const EmployeeServicesHubScreen()),
  _SectionEntry(
      'faqs',
      Icons.help_rounded,
      AppColors.green,
      'الأسئلة الشائعة',
      'إدارة الأسئلة الشائعة وإجاباتها',
      (_) => const AdminFaqsScreen()),
  _SectionEntry(
      'site-settings',
      Icons.settings_rounded,
      AppColors.navy,
      'إعدادات الموقع',
      'تعديل بيانات التواصل وإعدادات الموقع',
      (_) => const AdminSiteSettingsScreen()),
  _SectionEntry(
      'our-story',
      Icons.auto_stories_rounded,
      AppColors.greenInk,
      'قصتنا',
      'تعديل محتوى صفحة قصة COVEY',
      (_) => const AdminOurStoryScreen()),
  _SectionEntry(
      'exhibitions',
      Icons.museum_rounded,
      AppColors.greenInk,
      'المعارض',
      'إدارة محطات المعارض الدراسية',
      (_) => const AdminExhibitionsScreen()),
  _SectionEntry(
      'events',
      Icons.event_rounded,
      AppColors.greenInk,
      'الفعاليات',
      'إدارة الفعاليات القادمة والسابقة',
      (_) => const AdminEventsHubScreen()),
];

// ─── Main widget ──────────────────────────────────────────────────────────────
class EmployeeDashboardScreen extends StatefulWidget {
  final AuthUser user;
  const EmployeeDashboardScreen({super.key, required this.user});
  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  Map<String, dynamic>? _overview;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _myKpis;
  int _overdueReminders = 0;
  bool _remindersLoading = false;
  String? _avatarUrl;
  bool _avatarUploading = false;
  int _tab = 0;

  bool get _isAdmin => widget.user.role == UserRole.admin;

  bool _hasSectionAccess(String key) {
    if (_isAdmin) return true;
    final permissions = widget.user.permissions;
    if (key == 'service-requests') {
      return permissions.contains('services') ||
          permissions.contains('support');
    }
    return permissions.contains(key);
  }

  List<_TabDef> get _visibleTabs {
    return _allTabDefs.where((t) {
      if (t.account || t.community) return true;
      if (t.keys.isEmpty) return true; // home tab always shown
      return t.keys.any(_hasSectionAccess);
    }).toList();
  }

  List<_SectionEntry> _sectionsInTab(_TabDef tab) {
    return _allSections
        .where((s) =>
            tab.keys.contains(s.key) &&
            s.key != 'app-notifications' &&
            widget.user.permissions.contains(s.key))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.user.avatar;
    if (_isAdmin) {
      _load();
    } else if (widget.user.permissions.contains('applications')) {
      _loadReminders();
    }
    _loadMyKpis();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await EmployeeRepository.instance.getOverview();
      if (!mounted) return;
      setState(() {
        _overview = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل بيانات المنصة.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMyKpis() async {
    try {
      final data = await EmployeeRepository.instance.getMyKpis();
      if (!mounted) return;
      setState(() => _myKpis = data);
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/roles/employee_dashboard_screen.dart:252');
    }
  }

  Future<void> _loadReminders() async {
    setState(() => _remindersLoading = true);
    try {
      final data = await ApiClient.instance.get(
          '/applications/follow-up-reminders',
          token: AuthSession.instance.token);
      if (!mounted) return;
      final now = DateTime.now();
      final overdue = (Json.list(data)).where((r) {
        final due = DateTime.tryParse('${(Json.rawMap(r))['dueDate'] ?? ''}')
            ?.toLocal();
        return due != null && due.isBefore(now.add(const Duration(hours: 24)));
      }).length;
      setState(() => _overdueReminders = overdue);
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/roles/employee_dashboard_screen.dart:268');
    } finally {
      if (mounted) setState(() => _remindersLoading = false);
    }
  }

  Future<void> _refresh() async {
    if (_isAdmin) {
      await _load();
    } else if (widget.user.permissions.contains('applications')) {
      await _loadReminders();
    }
    _loadMyKpis();
  }

  Future<void> _pickAvatar() async {
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (img == null || !mounted) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() => _avatarUploading = true);
    try {
      final data = await ApiClient.instance.postMultipart(
        '/admin/me/avatar',
        fileBytes: bytes,
        fileName: img.name,
        fields: {},
        token: AuthSession.instance.token!,
      );
      final url = (Json.map(data))['avatar'] as String;
      if (mounted) setState(() => _avatarUrl = url);
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/roles/employee_dashboard_screen.dart:297');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
            content: const Text('تعذر رفع الصورة'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد تسجيل الخروج من حسابك؟',
      confirmLabel: 'تسجيل الخروج',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await AuthSession.instance.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RootChooserScreen()),
          (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs;
    // Clamp _tab if tabs changed (e.g. permissions refresh)
    final safeTab = _tab.clamp(0, tabs.length - 1);

    return AppScaffold(
      showBackButton: false,
      title: _isAdmin ? 'لوحة الأدمن' : 'لوحة الموظف',
      actions: [
        IconButton(
            tooltip: 'إشعارات حسابي',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const NotificationsScreen()))),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) async {
            if (value == 'security') {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SecuritySettingsScreen()));
            } else if (value == 'avatar') {
              await _pickAvatar();
            } else if (value == 'reminders') {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FollowUpRemindersScreen()));
            } else if (value == 'logout') {
              await _logout();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'security',
              child: Row(children: [
                Icon(Icons.security_outlined, size: 18),
                SizedBox(width: 10),
                Text('أمان الحساب'),
              ]),
            ),
            PopupMenuItem(
              value: 'reminders',
              child: Row(children: [
                Icon(Icons.notifications_active_outlined, size: 18),
                SizedBox(width: 10),
                Text('\u0645\u062a\u0627\u0628\u0639\u0627\u062a'),
              ]),
            ),
            PopupMenuItem(
              value: 'avatar',
              child: Row(children: [
                Icon(Icons.photo_camera_outlined, size: 18),
                SizedBox(width: 10),
                Text('تغيير الصورة'),
              ]),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(children: [
                Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
                SizedBox(width: 10),
                Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger)),
              ]),
            ),
          ],
        ),
      ],
      bottomBar: tabs.length > 1
          ? AdaptiveBottomBar(
              child: BottomNavigationBar(
              key: const ValueKey('employee-bottom-navigation'),
              currentIndex: safeTab,
              onTap: (i) => setState(() => _tab = i),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.greenInk,
              unselectedItemColor: AppColors.textSecondary,
              selectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              backgroundColor: Colors.white,
              elevation: 8,
              items: tabs
                  .map((t) => BottomNavigationBarItem(
                        icon: Icon(t.icon),
                        label: t.label,
                      ))
                  .toList(),
            ))
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.navy,
        child: IndexedStack(
          index: safeTab,
          children: tabs
              .asMap()
              .entries
              .map((entry) => entry.value.account
                  ? RoleAccountTab(onLogout: _logout)
                  : entry.value.community
                      ? StudentCommunityHub(isActive: entry.key == safeTab)
                      : entry.value.keys.isEmpty
                          ? _buildHomeTab(isActive: entry.key == safeTab)
                          : _buildSectionTab(entry.value))
              .toList(),
        ),
      ),
    );
  }

  // ── Home tab ──────────────────────────────────────────────────────────────
  Widget _buildHomeTab({required bool isActive}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _EmployeeHero(
          name: widget.user.name,
          isAdmin: _isAdmin,
          employeeRole: widget.user.employeeRole,
          avatarUrl: _avatarUrl,
          avatarUploading: _avatarUploading,
          onPickAvatar: _pickAvatar,
        ),
        MyStreakCard(
            key: ValueKey('employee-my-streak-${widget.user.id}'),
            isActive: isActive),
        if (_myKpis != null) ...[
          const Text('أدائي هذا الشهر', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          _KpiRow(kpis: _myKpis!),
          if (_isAdmin &&
              (Json.listOrNull(_myKpis!['teamStats']))?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            const Text('أداء الفريق — هذا الشهر',
                style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            _TeamStatsTable(rows: (Json.list(_myKpis!['teamStats'])).cast()),
          ],
          const SizedBox(height: 16),
        ],
        if (!_isAdmin && widget.user.permissions.contains('applications')) ...[
          const Text('ما يجب عليك اليوم', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          _RemindersCard(
            overdue: _overdueReminders,
            loading: _remindersLoading,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FollowUpRemindersScreen())),
          ),
          const SizedBox(height: 16),
        ],
        if (_isAdmin) ...[
          const Text('أرقام المنصة الآن', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          if (_loading)
            const LoadingState()
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else
            _StatsGrid(stats: Json.mapOrNull(_overview?['stats']) ?? {}),
          const SizedBox(height: 16),
          const Text('روابط سريعة', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          _SectionCard(
            icon: Icons.school_outlined,
            color: AppColors.navy,
            label: 'إدارة المنح',
            subtitle: 'استعراض وإدارة المنح الدراسية',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AdminScholarshipsScreen())),
          ),
          _SectionCard(
            icon: Icons.assignment_outlined,
            color: const Color(0xFF3B82F6),
            label: 'طلبات المنح',
            subtitle: 'مراجعة طلبات المنح المقدّمة',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ScholarshipApplicationsScreen())),
          ),
          _SectionCard(
            icon: Icons.admin_panel_settings_outlined,
            color: const Color(0xFFEF4444),
            label: 'المستخدمون والصلاحيات',
            subtitle: 'إدارة الموظفين وتحديد صلاحياتهم',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AdminUsersAccessScreen())),
          ),
          _SectionCard(
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF10B981),
            label: 'نظرة عامة على المنصة',
            subtitle: 'تقارير وإحصائيات شاملة',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ManagerOverviewScreen())),
          ),
        ],
      ],
    );
  }

  // ── Section tab ───────────────────────────────────────────────────────────
  Widget _buildSectionTab(_TabDef tab) {
    final sections = _sectionsInTab(tab);
    if (sections.isEmpty) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'لا توجد أقسام متاحة',
        message: 'لسه معندكش صلاحية لهذه الأقسام. تواصل مع الأدمن.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = sections[i];
        return _SectionCard(
          icon: s.icon,
          color: s.color,
          label: s.label,
          subtitle: s.subtitle,
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: s.builder)),
        );
      },
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────
class _EmployeeHero extends StatelessWidget {
  final String name;
  final bool isAdmin;
  final String? employeeRole;
  final String? avatarUrl;
  final bool avatarUploading;
  final VoidCallback onPickAvatar;

  const _EmployeeHero({
    required this.name,
    required this.isAdmin,
    required this.onPickAvatar,
    this.employeeRole,
    this.avatarUrl,
    this.avatarUploading = false,
  });

  String get _roleLabel {
    if (isAdmin) return 'أدمن — صلاحية كاملة';
    const labels = {
      'educational_consultant': 'مستشار تعليمي',
      'sales': 'مبيعات',
      'admission': 'مسؤول قبول',
      'admission_manager': 'مدير قبول',
      'visa_officer': 'مسؤول تأشيرات',
      'travel_coordinator': 'منسق سفر',
      'finance': 'مالية',
      'marketing': 'تسويق',
      'it': 'تقنية المعلومات',
      'support': 'دعم',
      'hr': 'موارد بشرية',
      'super_admin': 'مدير النظام',
    };
    return labels[employeeRole] ?? (employeeRole ?? 'موظف');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          GestureDetector(
            onTap: avatarUploading ? null : onPickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: avatarUploading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : avatarUrl != null
                          ? ClipOval(
                              child: AppNetworkImage(avatarUrl!,
                                  fit: BoxFit.cover,
                                  width: 58,
                                  height: 58,
                                  errorWidget: const Icon(Icons.badge_rounded,
                                      color: Colors.white, size: 26)))
                          : const Icon(Icons.badge_rounded,
                              color: Colors.white, size: 26),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.edit_rounded,
                        size: 12, color: AppColors.navy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً $name',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_roleLabel,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      const VerifiedAdminBadge(role: 'admin', size: 15),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reminders Card ───────────────────────────────────────────────────────────
class _RemindersCard extends StatelessWidget {
  final int overdue;
  final bool loading;
  final VoidCallback onTap;
  const _RemindersCard(
      {required this.overdue, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.navy)));
    }
    final hasOverdue = overdue > 0;
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: (hasOverdue ? AppColors.warning : AppColors.success)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.notifications_active_rounded,
              color: hasOverdue ? AppColors.warning : AppColors.success,
              size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                hasOverdue
                    ? '$overdue ${overdue == 1 ? 'متابعة مستحقة' : 'متابعات مستحقة'}'
                    : 'لا توجد متابعات مستحقة',
                style: AppTextStyles.cardTitle),
            const Text('اضغط لعرض تذكيرات المتابعة',
                style: AppTextStyles.caption),
          ]),
        ),
        const Icon(Icons.arrow_back_ios_new_rounded,
            size: 14, color: AppColors.textSecondary),
      ]),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      {
        'label': 'إجمالي الطلاب',
        'value': '${stats['students'] ?? 0}',
        'color': AppColors.navy
      },
      {
        'label': 'إجمالي الطلبات',
        'value': '${stats['applications'] ?? 0}',
        'color': const Color(0xFF3B82F6)
      },
      {
        'label': 'قيد المراجعة',
        'value': '${stats['underReviewApplications'] ?? 0}',
        'color': const Color(0xFFF59E0B)
      },
      {
        'label': 'حسابات غير نشطة',
        'value': '${stats['inactiveUsers'] ?? 0}',
        'color': const Color(0xFFEF4444)
      },
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: metrics.map((m) {
        final color = m['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m['value'] as String,
                  style: TextStyle(
                      color: color, fontSize: 24, fontWeight: FontWeight.w800)),
              Text(m['label'] as String, style: AppTextStyles.caption),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── KPI Row ──────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final Map<String, dynamic> kpis;
  const _KpiRow({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final thisMonth = kpis['processedThisMonth'] ?? 0;
    final total = kpis['totalProcessed'] ?? 0;
    final month = kpis['month'] as String? ?? '';
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.navy.withValues(alpha: 0.15))),
          child: Column(children: [
            Text('$thisMonth',
                style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('معالج هذا الشهر',
                style: AppTextStyles.caption, textAlign: TextAlign.center),
            if (month.isNotEmpty)
              Text(month,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2))),
          child: Column(children: [
            Text('$total',
                style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('إجمالي المعالجة',
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ]),
        ),
      ),
    ]);
  }
}

// ─── Team Stats ───────────────────────────────────────────────────────────────
class _TeamStatsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _TeamStatsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: rows.map((r) {
          final name = r['name'] as String? ?? '—';
          final count = r['count'] ?? 0;
          final role = r['employeeRole'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.border,
                  child: Icon(Icons.person_outline_rounded,
                      size: 16, color: AppColors.navy)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.cardTitle),
                      if (role.isNotEmpty)
                        Text(role, style: AppTextStyles.caption),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$count طلب',
                    style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_back_ios_new_rounded,
                  size: 13, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
