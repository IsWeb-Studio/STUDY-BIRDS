import 'follow_up_reminders_screen.dart';
import 'admin_scholarships_screen.dart';
import '../services_support/messaging_and_emergency_screens.dart';
import '../profile_account/security_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/employee_repository.dart';
import 'employee_extra_screens.dart';
import 'admin_users_access_screen.dart';
import 'admin_parent_links_screen.dart';
import 'admin_university_accounts_screen.dart';
import 'employee_community_screen.dart';
import 'admin_approval_screens.dart';
import 'admin_applications_documents_screens.dart';
import 'admin_simple_lists_screens.dart';
import 'admin_support_knowledge_screens.dart';
import 'admin_financials_marketing_screens.dart';
import 'admin_content_crud_screens.dart';
import 'admin_singleton_hub_screens.dart';
import 'employee_consultations_screen.dart';
import 'admin_reward_rules_screen.dart';
import '../services_support/student_listings_screen.dart';
import '../../main.dart' show RootChooserScreen;

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
  const _TabDef(this.icon, this.label, this.keys);
}

const _studentKeys = [
  'students', 'applications', 'student-documents', 'student-financials',
  'student-arrivals', 'student-notifications', 'student-favorites',
  'student-orientation', 'parent-links', 'support',
];
const _partnerKeys = [
  'agency-requests', 'agents', 'partner-students',
  'marketing-assets', 'verification', 'payouts',
];
const _managementKeys = [
  'university-accounts', 'universities', 'programs', 'content',
  'consultations', 'community', 'knowledge-base', 'testimonials',
  'recognitions', 'services', 'faqs', 'site-settings',
  'our-story', 'exhibitions', 'events',
];

const _allTabDefs = [
  _TabDef(Icons.home_rounded, 'الرئيسية', []),
  _TabDef(Icons.people_rounded, 'الطلاب', _studentKeys),
  _TabDef(Icons.handshake_rounded, 'الشركاء', _partnerKeys),
  _TabDef(Icons.admin_panel_settings_rounded, 'الإدارة', _managementKeys),
];

// ─── Section registry ─────────────────────────────────────────────────────────
final List<_SectionEntry> _allSections = [
  _SectionEntry('students', Icons.person_search_rounded, AppColors.navy,
      'ملفات الطلاب', 'استعراض وإدارة ملفات الطلاب الكاملة',
      (_) => const MyStudentsQueueScreen()),
  _SectionEntry('applications', Icons.description_rounded, const Color(0xFF3B82F6),
      'طلبات القبول', 'متابعة الطلبات وتحديث حالاتها',
      (_) => const AdminApplicationsScreen()),
  _SectionEntry('student-documents', Icons.folder_open_rounded, const Color(0xFFF59E0B),
      'مستندات الطلاب', 'مراجعة المستندات والتحقق منها',
      (_) => const AdminStudentDocumentsScreen()),
  _SectionEntry('student-financials', Icons.payments_rounded, const Color(0xFF10B981),
      'مالية الطلاب', 'متابعة الرسوم والمدفوعات',
      (_) => const AdminStudentFinancialsScreen()),
  _SectionEntry('student-financials', Icons.workspace_premium_rounded, const Color(0xFF8B5CF6),
      'قواعد المكافآت', 'تحديد قواعد وشروط مكافآت الطلاب',
      (_) => const AdminRewardRulesScreen()),
  _SectionEntry('student-arrivals', Icons.flight_land_rounded, const Color(0xFF06B6D4),
      'وصول الطلاب', 'تنسيق رحلات الوصول والاستقبال',
      (_) => const AdminArrivalRequestsScreen()),
  _SectionEntry('support', Icons.support_agent_rounded, const Color(0xFFEF4444),
      'الدعم الفني', 'متابعة ورد تذاكر الدعم الواردة',
      (_) => const AdminSupportTicketsScreen()),
  _SectionEntry('student-notifications', Icons.notifications_rounded, const Color(0xFFF97316),
      'إشعارات الطلاب', 'إرسال إشعارات مخصصة للطلاب',
      (_) => const AdminStudentNotificationsScreen()),
  _SectionEntry('student-favorites', Icons.favorite_rounded, const Color(0xFFEC4899),
      'المفضلة', 'استعراض تفضيلات الطلاب وجامعاتهم المفضلة',
      (_) => const AdminStudentFavoritesScreen()),
  _SectionEntry('knowledge-base', Icons.menu_book_rounded, const Color(0xFF84CC16),
      'دليل المعرفة', 'إدارة دليل المعلومات للطلاب والوكلاء',
      (_) => const AdminKnowledgeBaseScreen()),
  _SectionEntry('student-orientation', Icons.quiz_rounded, const Color(0xFF6366F1),
      'اختبار التوجيه', 'عرض نتائج اختبار توجيه الطلاب',
      (_) => const AdminOrientationResultsScreen()),
  _SectionEntry('parent-links', Icons.family_restroom_rounded, const Color(0xFFD97706),
      'ربط أولياء الأمور', 'ربط أولياء الأمور بحسابات أبنائهم',
      (_) => const AdminParentLinksScreen()),
  _SectionEntry('agency-requests', Icons.how_to_reg_rounded, AppColors.navy,
      'طلبات الوكالة', 'مراجعة وقبول طلبات شراكة الوكلاء',
      (_) => const AdminAgencyRequestsScreen()),
  _SectionEntry('agents', Icons.badge_rounded, const Color(0xFF3B82F6),
      'ملفات الوكلاء', 'استعراض وإدارة ملفات الوكلاء',
      (_) => const AdminAgentsScreen()),
  _SectionEntry('partner-students', Icons.group_rounded, const Color(0xFF10B981),
      'طلاب الوكلاء', 'الطلاب المسجّلون عبر الوكلاء',
      (_) => const AdminPartnerStudentsScreen()),
  _SectionEntry('marketing-assets', Icons.campaign_rounded, const Color(0xFFF59E0B),
      'المواد التسويقية', 'إدارة المواد التسويقية للوكلاء',
      (_) => const AdminMarketingAssetsScreen()),
  _SectionEntry('verification', Icons.verified_rounded, const Color(0xFF06B6D4),
      'توثيق الوكلاء', 'مراجعة مستندات توثيق الوكلاء',
      (_) => const AdminVerificationScreen()),
  _SectionEntry('payouts', Icons.account_balance_wallet_rounded, const Color(0xFF8B5CF6),
      'طلبات السحب', 'اعتماد وإدارة طلبات سحب الوكلاء',
      (_) => const AdminPayoutRequestsScreen()),
  _SectionEntry('university-accounts', Icons.school_rounded, AppColors.navy,
      'حسابات الجامعات', 'إنشاء وإدارة حسابات بوابات الجامعات',
      (_) => const AdminUniversityAccountsScreen()),
  _SectionEntry('consultations', Icons.event_available_rounded, const Color(0xFF3B82F6),
      'الاستشارات', 'إدارة الاستشارات والمواعيد المحجوزة',
      (_) => const EmployeeConsultationsScreen()),
  _SectionEntry('universities', Icons.account_balance_rounded, const Color(0xFF10B981),
      'الجامعات', 'إضافة وتعديل بيانات الجامعات',
      (_) => const AdminUniversitiesCrudScreen()),
  _SectionEntry('programs', Icons.auto_stories_rounded, const Color(0xFFF59E0B),
      'التخصصات', 'إدارة التخصصات والبرامج الدراسية',
      (_) => const AdminProgramsCrudScreen()),
  _SectionEntry('content', Icons.public_rounded, const Color(0xFF06B6D4),
      'الدول والمجالات', 'إدارة الدول والمجالات الدراسية',
      (_) => const AdminContentHubScreen()),
  _SectionEntry('community', Icons.forum_rounded, const Color(0xFF8B5CF6),
      'مجتمع الطلاب', 'مراقبة وإدارة منشورات المجتمع',
      (_) => const EmployeeCommunityScreen()),
  _SectionEntry('community', Icons.local_offer_rounded, const Color(0xFFEC4899),
      'عروض الطلاب', 'إدارة العروض المنشورة في المجتمع',
      (_) => const AdminStudentListingsScreen(kind: 'offer')),
  _SectionEntry('community', Icons.work_rounded, const Color(0xFFEF4444),
      'فرص العمل', 'إدارة فرص العمل والتدريب للطلاب',
      (_) => const AdminStudentListingsScreen(kind: 'opportunity')),
  _SectionEntry('testimonials', Icons.rate_review_rounded, const Color(0xFFF97316),
      'آراء الطلاب', 'إضافة وإدارة شهادات الطلاب',
      (_) => const AdminTestimonialsScreen()),
  _SectionEntry('recognitions', Icons.workspace_premium_rounded, const Color(0xFFD97706),
      'الاعتمادات', 'إدارة الاعتمادات الأكاديمية',
      (_) => const AdminRecognitionsScreen()),
  _SectionEntry('services', Icons.design_services_rounded, const Color(0xFF6366F1),
      'الخدمات', 'إدارة الخدمات المقدمة للطلاب',
      (_) => const EmployeeServicesHubScreen()),
  _SectionEntry('faqs', Icons.help_rounded, const Color(0xFF84CC16),
      'الأسئلة الشائعة', 'إدارة الأسئلة الشائعة وإجاباتها',
      (_) => const AdminFaqsScreen()),
  _SectionEntry('site-settings', Icons.settings_rounded, AppColors.navy,
      'إعدادات الموقع', 'تعديل بيانات التواصل وإعدادات الموقع',
      (_) => const AdminSiteSettingsScreen()),
  _SectionEntry('our-story', Icons.auto_stories_rounded, const Color(0xFF3B82F6),
      'قصتنا', 'تعديل محتوى صفحة قصة Study Birds',
      (_) => const AdminOurStoryScreen()),
  _SectionEntry('exhibitions', Icons.museum_rounded, const Color(0xFF10B981),
      'المعارض', 'إدارة محطات المعارض الدراسية',
      (_) => const AdminExhibitionsScreen()),
  _SectionEntry('events', Icons.event_rounded, const Color(0xFFF59E0B),
      'الفعاليات', 'إدارة الفعاليات القادمة والسابقة',
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

  List<_TabDef> get _visibleTabs {
    final perms = widget.user.permissions;
    return _allTabDefs.where((t) {
      if (t.keys.isEmpty) return true; // home tab always shown
      if (_isAdmin) return true;
      return t.keys.any(perms.contains);
    }).toList();
  }

  List<_SectionEntry> _sectionsInTab(_TabDef tab) {
    if (_isAdmin) {
      return _allSections.where((s) => tab.keys.contains(s.key)).toList();
    }
    return _allSections
        .where((s) =>
            tab.keys.contains(s.key) &&
            widget.user.permissions.contains(s.key))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.user.avatar;
    if (_isAdmin) _load();
    else if (widget.user.permissions.contains('applications')) _loadReminders();
    _loadMyKpis();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await EmployeeRepository.instance.getOverview();
      if (!mounted) return;
      setState(() { _overview = data; _loading = false; });
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
    } catch (_) {}
  }

  Future<void> _loadReminders() async {
    setState(() => _remindersLoading = true);
    try {
      final data = await ApiClient.instance.get(
          '/applications/follow-up-reminders',
          token: AuthSession.instance.token);
      if (!mounted) return;
      final now = DateTime.now();
      final overdue = (data as List<dynamic>).where((r) {
        final due = DateTime.tryParse('${(r as Map)['dueDate'] ?? ''}')?.toLocal();
        return due != null && due.isBefore(now.add(const Duration(hours: 24)));
      }).length;
      setState(() => _overdueReminders = overdue);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _remindersLoading = false);
    }
  }

  Future<void> _refresh() async {
    if (_isAdmin) await _load();
    else if (widget.user.permissions.contains('applications')) await _loadReminders();
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
      final url = (data as Map<String, dynamic>)['avatar'] as String;
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر رفع الصورة'),
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
      title: _isAdmin ? 'لوحة الأدمن' : 'لوحة الموظف',
      actions: [
        if (_isAdmin || widget.user.permissions.contains('applications'))
          IconButton(
              tooltip: 'تذكيرات متابعتي',
              icon: Badge(
                isLabelVisible: _overdueReminders > 0,
                label: Text('$_overdueReminders'),
                child: const Icon(Icons.notifications_active_outlined),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FollowUpRemindersScreen()))),
        IconButton(
            tooltip: 'الرسائل',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConversationThreadScreen()))),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) async {
            if (value == 'security') {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SecuritySettingsScreen()));
            } else if (value == 'avatar') {
              await _pickAvatar();
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
                Text('تسجيل الخروج',
                    style: TextStyle(color: AppColors.danger)),
              ]),
            ),
          ],
        ),
      ],
      bottomBar: tabs.length > 1
          ? BottomNavigationBar(
              currentIndex: safeTab,
              onTap: (i) => setState(() => _tab = i),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.navy,
              unselectedItemColor: AppColors.textSecondary,
              selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              backgroundColor: Colors.white,
              elevation: 8,
              items: tabs
                  .map((t) => BottomNavigationBarItem(
                        icon: Icon(t.icon),
                        label: t.label,
                      ))
                  .toList(),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.navy,
        child: IndexedStack(
          index: safeTab,
          children: tabs.map((t) => t.keys.isEmpty
              ? _buildHomeTab()
              : _buildSectionTab(t)).toList(),
        ),
      ),
    );
  }

  // ── Home tab ──────────────────────────────────────────────────────────────
  Widget _buildHomeTab() {
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
        if (_myKpis != null) ...[
          const Text('أدائي هذا الشهر', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          _KpiRow(kpis: _myKpis!),
          if (_isAdmin &&
              (_myKpis!['teamStats'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            const Text('أداء الفريق — هذا الشهر',
                style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            _TeamStatsTable(rows: (_myKpis!['teamStats'] as List).cast()),
          ],
          const SizedBox(height: 16),
        ],
        if (!_isAdmin && widget.user.permissions.contains('applications')) ...[
          const Text('ما يجب عليك اليوم', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          _RemindersCard(
            overdue: _overdueReminders,
            loading: _remindersLoading,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FollowUpRemindersScreen())),
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
            _StatsGrid(stats: _overview?['stats'] as Map<String, dynamic>? ?? {}),
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
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: s.builder)),
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
                                  errorWidget: const Icon(
                                      Icons.badge_rounded,
                                      color: Colors.white,
                                      size: 26)))
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
                  child: Text(_roleLabel,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      {'label': 'إجمالي الطلاب', 'value': '${stats['students'] ?? 0}', 'color': AppColors.navy},
      {'label': 'إجمالي الطلبات', 'value': '${stats['applications'] ?? 0}', 'color': const Color(0xFF3B82F6)},
      {'label': 'قيد المراجعة', 'value': '${stats['underReviewApplications'] ?? 0}', 'color': const Color(0xFFF59E0B)},
      {'label': 'حسابات غير نشطة', 'value': '${stats['inactiveUsers'] ?? 0}', 'color': const Color(0xFFEF4444)},
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
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
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
              border: Border.all(color: AppColors.navy.withValues(alpha: 0.15))),
          child: Column(children: [
            Text('$thisMonth',
                style: TextStyle(
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
                  size: 13,
                  color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
