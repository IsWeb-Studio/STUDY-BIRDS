import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/parent_repository.dart';
import '../../core/auth_session.dart';
import '../applications_documents_payments/applications_screens.dart'
    show appStatusMeta;
import '../services_support/messaging_and_emergency_screens.dart';
import '../profile_account/security_settings_screen.dart'
    show SecuritySettingsScreen, ChangePasswordScreen;

const Map<String, String> _stageLabels = {
  'file-received': 'استلام الملف',
  'documents-review': 'مراجعة المستندات',
  'university-selection': 'اختيار الجامعة',
  'applying': 'التقديم',
  'university-review': 'مراجعة الجامعة',
  'preliminary-accepted': 'القبول المبدئي',
  'first-payment': 'الدفع الأول',
  'final-accepted': 'القبول النهائي',
  'visa': 'التأشيرة',
  'travel': 'السفر',
  'reception': 'الاستقبال',
  'accommodation': 'السكن',
  'university-registration': 'التسجيل في الجامعة',
  'studies-started': 'بدء الدراسة',
};

/// Parent Mode Home — "My Student" view. Real data from
/// server/src/routes/parentRoutes.js. Zero visibility into Study Birds
/// internal/employee data; a parent only ever sees an APPROVED linked
/// student's overview/applications/payments, read-only.
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _tab = 0; // 0 = overview, 1 = payments, 2 = account

  List<dynamic> _children = [];
  List<dynamic> _linkRequests = [];
  int _selectedIndex = 0;
  int _overviewRequest = 0;
  bool _loadingChildren = true;
  String? _loadError;

  Map<String, dynamic>? _overview;
  bool _loadingOverview = false;

  List<dynamic>? _payments;
  bool _loadingPayments = false;

  final _emailCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  bool _sendingRequest = false;
  String? _requestError;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loadingChildren = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ParentRepository.instance.getChildren(),
        ParentRepository.instance.getLinkRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _children = results[0] as List<dynamic>;
        _linkRequests = results[1] as List<dynamic>;
        _loadingChildren = false;
      });
      if (_children.isNotEmpty) {
        _loadOverview(0);
        _loadPayments(0);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'تعذر تحميل بياناتك. تحقق من الاتصال وحاول مجدداً.';
        _loadingChildren = false;
      });
    }
  }

  Future<void> _loadOverview(int index) async {
    final request = ++_overviewRequest;
    setState(() {
      _selectedIndex = index;
      _loadingOverview = true;
      _overview = null;
    });
    try {
      final studentId =
          (_children[index] as Map<String, dynamic>)['_id'] as String;
      final data =
          await ParentRepository.instance.getChildOverview(studentId);
      if (!mounted || request != _overviewRequest) return;
      setState(() {
        _overview = data;
        _loadingOverview = false;
      });
    } catch (_) {
      if (!mounted || request != _overviewRequest) return;
      setState(() => _loadingOverview = false);
    }
  }

  Future<void> _loadPayments(int index) async {
    setState(() {
      _loadingPayments = true;
      _payments = null;
    });
    try {
      final studentId =
          (_children[index] as Map<String, dynamic>)['_id'] as String;
      final data =
          await ParentRepository.instance.getChildPayments(studentId);
      if (!mounted) return;
      setState(() {
        _payments = data;
        _loadingPayments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPayments = false);
    }
  }

  void _selectChild(int index) {
    _loadOverview(index);
    _loadPayments(index);
  }

  Future<void> _sendLinkRequest() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _requestError = 'أدخل البريد الإلكتروني للطالب');
      return;
    }
    setState(() {
      _sendingRequest = true;
      _requestError = null;
    });
    try {
      await ParentRepository.instance.createLinkRequest(
        studentEmail: _emailCtrl.text.trim(),
        relationship: _relationshipCtrl.text.trim().isEmpty
            ? null
            : _relationshipCtrl.text.trim(),
      );
      _emailCtrl.clear();
      _relationshipCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('تم إرسال طلب الربط، بانتظار موافقة الإدارة'),
            backgroundColor: AppColors.success));
      }
      await _loadChildren();
    } catch (_) {
      if (mounted)
        setState(() => _requestError =
            'تعذر إرسال الطلب — تأكد من أن البريد صحيح ومسجّل كحساب طالب.');
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: const Text('حساب ولي الأمر',
              style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'الرسائل',
              icon: const Icon(Icons.forum_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ConversationThreadScreen())),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadChildren,
          color: AppColors.navy,
          child: _loadingChildren
              ? const LoadingState(message: 'جاري تحميل بياناتك...')
              : _loadError != null
                  ? ErrorState(message: _loadError!, onRetry: _loadChildren)
                  : _tab == 0
                      ? _buildOverviewTab()
                      : _tab == 1
                          ? _buildPaymentsTab()
                          : _buildAccountTab(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          selectedItemColor: AppColors.navy,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.school_outlined), label: 'رحلة ابني'),
            BottomNavigationBarItem(
                icon: Icon(Icons.payments_outlined), label: 'المدفوعات'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded), label: 'حسابي'),
          ],
        ),
      ),
    );
  }

  // ── Tab 0: Overview ──────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    // ── حالة: لا أطفال ولا طلبات → شاشة ترحيب + فورم ──────────────────────
    if (_children.isEmpty && _linkRequests.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEmptyState(),
          const SizedBox(height: 24),
          _buildLinkRequestForm(),
          const SizedBox(height: 24),
        ],
      );
    }

    // ── حالة: طلبات معلقة فقط (لم يُوافق بعد) ─────────────────────────────
    if (_children.isEmpty && _linkRequests.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // وضع مؤقت حتى الموافقة
          AppCard(
            child: Column(
              children: [
                const Icon(Icons.hourglass_top_rounded,
                    color: AppColors.warning, size: 36),
                const SizedBox(height: 10),
                const Text('بانتظار موافقة الإدارة',
                    style: AppTextStyles.cardTitle,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                const Text(
                    'سيظهر حساب ابنك/ابنتك بعد مراجعة طلب الربط وقبوله من قبل الفريق.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('طلبات الربط', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          ..._linkRequests.map(_buildLinkRequestRow),
          const SizedBox(height: 24),
        ],
      );
    }

    // ── حالة: عنده أطفال مقبولين → الاختيار أول شيء ──────────────────────
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // اختيار الطالب في أعلى الصفحة
        if (_children.length == 1) ...[
          _buildSingleChildHeader(),
        ] else ...[
          const Text('اختر الطالب', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          _buildChildrenChips(),
        ],
        const SizedBox(height: 16),

        // بيانات الطالب المختار
        if (_loadingOverview)
          const LoadingState()
        else if (_overview != null)
          _buildOverviewCards(_overview!)
        else
          const AppCard(
              child: Text('تعذر تحميل تفاصيل هذا الطالب.',
                  style: AppTextStyles.caption)),

        // طلبات الربط (مطوية في الأسفل)
        if (_linkRequests.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('طلبات الربط', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          ..._linkRequests.map(_buildLinkRequestRow),
        ],

        // فورم إضافة طالب جديد في الأسفل
        const SizedBox(height: 24),
        _buildLinkRequestForm(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSingleChildHeader() {
    final child = _children[0] as Map<String, dynamic>;
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.navy.withValues(alpha: 0.1),
            child: const Icon(Icons.person_rounded,
                color: AppColors.navy, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تتابع رحلة',
                    style: AppTextStyles.caption),
                Text(child['name'] as String? ?? '—',
                    style: AppTextStyles.cardTitle),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('مرتبط',
                style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRequestRow(dynamic r) {
    final req = r as Map<String, dynamic>;
    final student = req['student'] as Map<String, dynamic>?;
    final status = req['status'] as String?;
    final (label, color) = switch (status) {
      'approved' => ('مقبول', AppColors.success),
      'rejected' => ('مرفوض', AppColors.danger),
      _ => ('قيد المراجعة', AppColors.warning),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            const Icon(Icons.link_rounded,
                color: AppColors.navy, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    student?['name'] as String? ??
                        student?['email'] as String? ??
                        '—',
                    style: AppTextStyles.body)),
            StatusBadge(label: label, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildChildrenChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < _children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _ChildChip(
              name: (_children[i] as Map<String, dynamic>)['name'] as String? ?? '—',
              selected: i == _selectedIndex,
              onTap: () => _selectChild(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewCards(Map<String, dynamic> overview) {
    final applications = overview['applications'] as List<dynamic>? ?? [];
    final student = overview['student'] as Map<String, dynamic>?;
    final targetCountries =
        (overview['targetCountries'] as List<dynamic>? ?? []).join('، ');
    final stageKey = overview['journeyStage'] as String?;
    final stageName = (stageKey != null ? _stageLabels[stageKey] : null) ??
        stageKey ??
        '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student info card
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.navy, size: 26)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(student?['name'] as String? ?? '—',
                          style: AppTextStyles.cardTitle),
                      Text(student?['email'] as String? ?? '',
                          style: AppTextStyles.caption),
                    ])),
              ]),
              if (targetCountries.isNotEmpty ||
                  overview['intake'] != null) ...[
                const Divider(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (targetCountries.isNotEmpty)
                      _MiniFact(
                          label: 'الدول المستهدفة',
                          value: targetCountries),
                    if (overview['intake'] != null)
                      _MiniFact(
                          label: 'الفصل الدراسي',
                          value: '${overview['intake']}'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Journey stage card
        AppCard(
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.timeline_rounded,
                  color: AppColors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('مرحلة الرحلة الدراسية',
                      style: AppTextStyles.caption),
                  Text(stageName, style: AppTextStyles.cardTitle),
                ])),
          ]),
        ),
        const SizedBox(height: 16),
        // Applications
        const Text('الطلبات الجامعية', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        if (applications.isEmpty)
          const AppCard(
              child: Text('لا توجد طلبات مسجّلة بعد لهذا الطالب.',
                  style: AppTextStyles.caption))
        else
          ...applications.map((a) {
            final app = a as Map<String, dynamic>;
            final uni = app['university'] as Map<String, dynamic>?;
            final program = app['program'] as Map<String, dynamic>?;
            final meta = appStatusMeta(app);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(children: [
                  Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_outlined,
                          color: AppColors.navy, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(uni?['name'] as String? ?? '—',
                            style: AppTextStyles.cardTitle),
                        Text(program?['name'] as String? ?? '',
                            style: AppTextStyles.caption),
                      ])),
                  const SizedBox(width: 8),
                  StatusBadge(label: meta.label, color: meta.color),
                ]),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.family_restroom_rounded,
              size: 64, color: AppColors.navy.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          const Text('لا يوجد طلاب مرتبطون بحسابك بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
              'أرسل طلب ربط بإدخال البريد الإلكتروني لابنك/ابنتك أعلاه.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption),
        ],
      ),
    );
  }

  // ── Tab 1: Payments ──────────────────────────────────────────────────────

  Widget _buildPaymentsTab() {
    if (_children.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
            'لا يوجد طلاب مرتبطون بحسابك. أرسل طلب ربط من تبويب رحلة ابني.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_children.length > 1) ...[
          const Text('اختر الطالب', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          _buildChildrenChips(),
          const SizedBox(height: 16),
        ],
        const Text('سجل المدفوعات', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        if (_loadingPayments)
          const LoadingState()
        else if (_payments == null)
          const AppCard(
              child: Text('تعذر تحميل المدفوعات.',
                  style: AppTextStyles.caption))
        else if (_payments!.isEmpty)
          const AppCard(
              child: Text('لا توجد فواتير مسجّلة بعد لهذا الطالب.',
                  style: AppTextStyles.caption))
        else
          ..._payments!.map(_buildPaymentRow),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPaymentRow(dynamic p) {
    final payment = p as Map<String, dynamic>;
    final status = payment['status'] as String? ?? '';
    final amount = payment['amount'] ?? payment['total'];
    final desc = payment['description'] as String? ??
        payment['invoiceNumber'] as String? ??
        'فاتورة';
    final dueDate = payment['dueDate'] as String?;
    final (label, color) = switch (status) {
      'paid' => ('مدفوع', AppColors.success),
      'rejected' => ('مرفوض', AppColors.danger),
      'pending-review' => ('قيد المراجعة', AppColors.warning),
      _ => ('غير مدفوع', AppColors.orange),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                status == 'paid'
                    ? Icons.check_circle_outline_rounded
                    : Icons.payments_outlined,
                color: color,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(desc, style: AppTextStyles.cardTitle),
            if (dueDate != null)
              Text(
                  'الاستحقاق: ${_formatDate(dueDate)}',
                  style: AppTextStyles.caption),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (amount != null)
              Text('$amount \$',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
            StatusBadge(label: label, color: color),
          ]),
        ]),
      ),
    );
  }

  // ── Tab 2: Account ───────────────────────────────────────────────────────

  Widget _buildAccountTab() {
    final user = AuthSession.instance.currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile card
        AppCard(
          child: Row(children: [
            CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.navy, size: 28)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Text(user?.name ?? '—', style: AppTextStyles.cardTitle),
              Text(user?.email ?? '', style: AppTextStyles.caption),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('ولي أمر',
                    style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('الإعدادات', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ChangePasswordScreen())),
          child: const Row(children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.navy, size: 20),
            SizedBox(width: 12),
            Expanded(
                child: Text('تغيير كلمة المرور',
                    style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const SecuritySettingsScreen())),
          child: const Row(children: [
            Icon(Icons.security_rounded, color: AppColors.navy, size: 20),
            SizedBox(width: 12),
            Expanded(
                child: Text('أمان الحساب', style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          onTap: () => _confirmLogout(context),
          child: const Row(children: [
            Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
            SizedBox(width: 12),
            Expanded(
                child: Text('تسجيل الخروج',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger))),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildLinkRequestForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ربط حساب طالب جديد',
              style: AppTextStyles.sectionLabel),
          const SizedBox(height: 4),
          const Text(
              'أدخل البريد الإلكتروني المسجّل به حساب ابنك/ابنتك.',
              style: AppTextStyles.caption),
          const SizedBox(height: 12),
          _InputField(
              controller: _emailCtrl,
              hint: 'بريد الطالب الإلكتروني',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 8),
          _InputField(
              controller: _relationshipCtrl,
              hint: 'صلة القرابة (اختياري)'),
          if (_requestError != null) ...[
            const SizedBox(height: 8),
            Text(_requestError!,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
              label: _sendingRequest ? 'جاري الإرسال...' : 'إرسال طلب الربط',
              onPressed: _sendingRequest ? null : _sendLinkRequest,
              expand: false),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج',
            style: TextStyle(fontFamily: 'Tajawal')),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟',
            style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تسجيل الخروج',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AuthSession.instance.logout();
    }
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────

class _MiniFact extends StatelessWidget {
  final String label;
  final String value;
  const _MiniFact({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.caption),
      Text(value,
          style:
              AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ChildChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _ChildChip({required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navy : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
                color: selected ? AppColors.navy : AppColors.border),
          ),
          child: Text(
            name,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  const _InputField(
      {required this.controller, required this.hint, this.keyboardType});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.border)),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 12)),
      ),
    );
  }
}
