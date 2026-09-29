import 'follow_up_reminders_screen.dart';
import 'admin_scholarships_screen.dart';
import '../services_support/messaging_and_emergency_screens.dart';
import '../profile_account/security_settings_screen.dart';
import 'package:flutter/material.dart';
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

/// Admin/Employee Home. HONESTY NOTE: the backend has no per-employee
/// "tasks assigned to me" concept — role="admin" sees the whole platform
/// unconditionally; role="employee" sees only the sections an admin
/// explicitly granted (server/src/constants/employeeSections.json), matching
/// the web's canAccessEmployeePage/employeeHome logic exactly.
///
/// [_sectionScreens] is the registry mapping a section key to its real
/// Flutter screen — all 30 sections in employeeSections.json now have one.
class EmployeeDashboardScreen extends StatefulWidget {
  final AuthUser user;
  const EmployeeDashboardScreen({super.key, required this.user});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _SectionEntry {
  final String key;
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  const _SectionEntry(this.key, this.icon, this.label, this.builder);
}

final List<_SectionEntry> _sectionScreens = [
  _SectionEntry('students', Icons.people_outline_rounded,
      'ملفات الطلاب الكاملة', (_) => const MyStudentsQueueScreen()),
  _SectionEntry('applications', Icons.description_outlined, 'طلبات الطلاب',
      (_) => const AdminApplicationsScreen()),
  _SectionEntry('student-documents', Icons.folder_open_outlined,
      'مستندات الطلاب', (_) => const AdminStudentDocumentsScreen()),
  _SectionEntry('student-financials', Icons.payments_outlined, 'مالية الطلاب',
      (_) => const AdminStudentFinancialsScreen()),
  _SectionEntry('student-financials', Icons.workspace_premium_outlined, 'قواعد مكافآت الطلاب',
      (_) => const AdminRewardRulesScreen()),
  _SectionEntry('student-arrivals', Icons.flight_land_rounded, 'وصول الطلاب',
      (_) => const AdminArrivalRequestsScreen()),
  _SectionEntry('support', Icons.support_agent_outlined, 'دعم الطلاب والوكلاء',
      (_) => const AdminSupportTicketsScreen()),
  _SectionEntry('student-notifications', Icons.notifications_outlined,
      'إشعارات الطلاب', (_) => const AdminStudentNotificationsScreen()),
  _SectionEntry('student-favorites', Icons.favorite_border_rounded,
      'مفضلة الطلاب', (_) => const AdminStudentFavoritesScreen()),
  _SectionEntry('knowledge-base', Icons.menu_book_outlined,
      'دليل الطلاب والوكلاء', (_) => const AdminKnowledgeBaseScreen()),
  _SectionEntry('student-orientation', Icons.quiz_outlined, 'اختبار التوجيه',
      (_) => const AdminOrientationResultsScreen()),
  _SectionEntry('agency-requests', Icons.how_to_reg_outlined, 'طلبات الوكالة',
      (_) => const AdminAgencyRequestsScreen()),
  _SectionEntry('agents', Icons.badge_outlined, 'ملفات الوكلاء الكاملة',
      (_) => const AdminAgentsScreen()),
  _SectionEntry('partner-students', Icons.group_outlined, 'طلاب الوكلاء',
      (_) => const AdminPartnerStudentsScreen()),
  _SectionEntry('marketing-assets', Icons.campaign_outlined, 'المواد التسويقية',
      (_) => const AdminMarketingAssetsScreen()),
  _SectionEntry('verification', Icons.verified_outlined, 'توثيق الوكلاء',
      (_) => const AdminVerificationScreen()),
  _SectionEntry('payouts', Icons.account_balance_wallet_outlined, 'طلبات السحب',
      (_) => const AdminPayoutRequestsScreen()),
  _SectionEntry('parent-links', Icons.family_restroom_outlined,
      'ربط أولياء الأمور', (_) => const AdminParentLinksScreen()),
  _SectionEntry('community', Icons.forum_outlined, 'مجتمع الطلاب',
      (_) => const EmployeeCommunityScreen()),
  _SectionEntry('community', Icons.local_offer_outlined, 'إدارة عروض الطلاب',
      (_) => const AdminStudentListingsScreen(kind: 'offer')),
  _SectionEntry('community', Icons.work_outline, 'إدارة فرص العمل والتدريب',
      (_) => const AdminStudentListingsScreen(kind: 'opportunity')),
  _SectionEntry('university-accounts', Icons.school_outlined, 'حسابات الجامعات',
      (_) => const AdminUniversityAccountsScreen()),
  _SectionEntry('consultations', Icons.event_available_outlined,
      'الاستشارات والمواعيد', (_) => const EmployeeConsultationsScreen()),
  _SectionEntry('universities', Icons.account_balance_outlined, 'الجامعات',
      (_) => const AdminUniversitiesCrudScreen()),
  _SectionEntry('programs', Icons.menu_book_outlined, 'التخصصات',
      (_) => const AdminProgramsCrudScreen()),
  _SectionEntry('content', Icons.public_rounded, 'الدول والمجالات الدراسية',
      (_) => const AdminContentHubScreen()),
  _SectionEntry('testimonials', Icons.rate_review_outlined, 'آراء الطلاب',
      (_) => const AdminTestimonialsScreen()),
  _SectionEntry('site-settings', Icons.settings_outlined,
      'بيانات التواصل وإعدادات الموقع', (_) => const AdminSiteSettingsScreen()),
  _SectionEntry('recognitions', Icons.workspace_premium_outlined, 'الاعتمادات',
      (_) => const AdminRecognitionsScreen()),
  _SectionEntry('services', Icons.design_services_outlined, 'الخدمات',
      (_) => const EmployeeServicesHubScreen()),
  _SectionEntry('faqs', Icons.help_outline_rounded, 'الأسئلة الشائعة',
      (_) => const AdminFaqsScreen()),
  _SectionEntry('our-story', Icons.auto_stories_outlined, 'قصتنا',
      (_) => const AdminOurStoryScreen()),
  _SectionEntry('exhibitions', Icons.museum_outlined, 'محطة المعارض',
      (_) => const AdminExhibitionsScreen()),
  _SectionEntry('events', Icons.event_outlined, 'الفعاليات',
      (_) => const AdminEventsHubScreen()),
];

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  Map<String, dynamic>? _overview;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _myKpis;

  int _overdueReminders = 0;
  bool _remindersLoading = false;

  bool get _isFullAdmin => widget.user.role == UserRole.admin;
  bool get _hasApplications =>
      widget.user.permissions.contains('applications');

  @override
  void initState() {
    super.initState();
    if (_isFullAdmin) {
      _load();
    } else if (_hasApplications) {
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
    } catch (_) {}
  }

  Future<void> _loadReminders() async {
    setState(() => _remindersLoading = true);
    try {
      final data = await ApiClient.instance.get(
          '/applications/follow-up-reminders',
          token: AuthSession.instance.token);
      if (!mounted) return;
      final list = data as List<dynamic>;
      final now = DateTime.now();
      final overdue = list.where((r) {
        final due =
            DateTime.tryParse('${(r as Map)['dueDate'] ?? ''}')?.toLocal();
        return due != null && due.isBefore(now.add(const Duration(hours: 24)));
      }).length;
      setState(() => _overdueReminders = overdue);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _remindersLoading = false);
    }
  }

  Future<void> _refresh() async {
    if (_isFullAdmin) {
      await _load();
    } else if (_hasApplications) {
      await _loadReminders();
    }
    _loadMyKpis();
  }

  @override
  Widget build(BuildContext context) {
    final granted = widget.user.permissions;
    final visibleSections = _isFullAdmin
        ? _sectionScreens
        : _sectionScreens.where((s) => granted.contains(s.key)).toList();

    return AppScaffold(
      actions: [
        if (_isFullAdmin || granted.contains('applications'))
          IconButton(
              tooltip: 'تذكيرات متابعتي',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FollowUpRemindersScreen()))),
        IconButton(
            tooltip: 'الرسائل',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConversationThreadScreen()))),
        IconButton(
            tooltip: 'أمان الحساب',
            icon: const Icon(Icons.security),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SecuritySettingsScreen()))),
      ],
      title: _isFullAdmin ? 'لوحة الأدمن' : 'لوحة الموظف',
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.navy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.badge_rounded, color: AppColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مرحباً ${widget.user.name}',
                          style: AppTextStyles.cardTitle),
                      Text(_isFullAdmin ? 'أدمن — صلاحية كاملة' : 'موظف',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_myKpis != null) ...[
            const SizedBox(height: 8),
            const Text('أدائي هذا الشهر', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            _KpiRow(kpis: _myKpis!),
            if (_isFullAdmin &&
                (_myKpis!['teamStats'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text('أداء الفريق — هذا الشهر',
                  style: AppTextStyles.sectionLabel),
              const SizedBox(height: 10),
              _TeamStatsTable(
                  rows: (_myKpis!['teamStats'] as List).cast()),
            ],
          ],
          if (!_isFullAdmin && _hasApplications) ...[
            const SizedBox(height: 8),
            const Text('ما يجب عليك اليوم', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            if (_remindersLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.navy)))
            else
              AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const FollowUpRemindersScreen())),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: (_overdueReminders > 0
                                ? AppColors.warning
                                : AppColors.success)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.notifications_active_outlined,
                        color: _overdueReminders > 0
                            ? AppColors.warning
                            : AppColors.success,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              _overdueReminders == 0
                                  ? 'لا توجد متابعات مستحقة'
                                  : '$_overdueReminders ${_overdueReminders == 1 ? 'متابعة مستحقة' : 'متابعات مستحقة'}',
                              style: AppTextStyles.cardTitle),
                          const Text('اضغط لعرض تذكيرات المتابعة',
                              style: AppTextStyles.caption),
                        ]),
                  ),
                  const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: AppColors.textSecondary),
                ]),
              ),
          ],
          if (_isFullAdmin) ...[
            const Text('أرقام المنصة الآن', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            if (_loading)
              const LoadingState()
            else if (_error != null)
              ErrorState(message: _error!, onRetry: _load)
            else
              _buildStatsGrid(
                  _overview?['stats'] as Map<String, dynamic>? ?? {}),
            const SizedBox(height: 8),
            _QuickLink(
                icon: Icons.school_outlined,
                label: 'إدارة المنح',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AdminScholarshipsScreen()))),
            _QuickLink(
                icon: Icons.assignment_outlined,
                label: 'طلبات المنح',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ScholarshipApplicationsScreen()))),
            _QuickLink(
                icon: Icons.admin_panel_settings_outlined,
                label: 'المستخدمون والصلاحيات',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AdminUsersAccessScreen()))),
            _QuickLink(
                icon: Icons.bar_chart_rounded,
                label: 'نظرة عامة على المنصة',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ManagerOverviewScreen()))),
          ],
          const SizedBox(height: 8),
          Text(_isFullAdmin ? 'كل الأقسام' : 'الأقسام المتاحة لك',
              style: AppTextStyles.sectionLabel),
          if (!_isFullAdmin) ...[
            const SizedBox(height: 4),
            const Text('حدّدها الأدمن من صفحة "المستخدمون والصلاحيات".',
                style: AppTextStyles.caption),
          ],
          const SizedBox(height: 10),
          ...visibleSections.map((s) => _QuickLink(
              icon: s.icon,
              label: s.label,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: s.builder)))),
          if (!_isFullAdmin && visibleSections.isEmpty)
            const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'لا توجد أقسام متاحة بعد',
              message: 'لسه معندكش أي صلاحية. تواصل مع الأدمن.',
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final metrics = [
      {'label': 'إجمالي الطلاب', 'value': '${stats['students'] ?? 0}'},
      {'label': 'إجمالي الطلبات', 'value': '${stats['applications'] ?? 0}'},
      {
        'label': 'قيد المراجعة',
        'value': '${stats['underReviewApplications'] ?? 0}'
      },
      {'label': 'حسابات غير نشطة', 'value': '${stats['inactiveUsers'] ?? 0}'},
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: metrics
          .map((m) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m['value']!,
                        style:
                            AppTextStyles.screenTitle.copyWith(fontSize: 22)),
                    Text(m['label']!, style: AppTextStyles.caption),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final Map<String, dynamic> kpis;
  const _KpiRow({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final thisMonth = kpis['processedThisMonth'] ?? 0;
    final total = kpis['totalProcessed'] ?? 0;
    final month = kpis['month'] ?? '';
    return Row(children: [
      Expanded(
        child: AppCard(
          margin: EdgeInsets.zero,
          child: Column(children: [
            Text('$thisMonth',
                style: AppTextStyles.screenTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 2),
            Text('معالج هذا الشهر', style: AppTextStyles.caption,
                textAlign: TextAlign.center),
            if (month.isNotEmpty)
              Text(month, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: AppCard(
          margin: EdgeInsets.zero,
          child: Column(children: [
            Text('$total',
                style: AppTextStyles.screenTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 2),
            const Text('إجمالي المعالجة', style: AppTextStyles.caption,
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    ]);
  }
}

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
                  radius: 14,
                  backgroundColor: AppColors.border,
                  child: Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.navy)),
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
                    borderRadius: BorderRadius.circular(AppRadius.chip)),
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

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.navy, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.cardTitle)),
          const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
