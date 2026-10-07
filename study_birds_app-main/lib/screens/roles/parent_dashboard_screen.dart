import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/config/app_theme.dart';
import '../../core/repositories/parent_repository.dart';
import '../../core/services/auth_session.dart';
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
          _buildLinkRequestForm(),
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
    final notifications = overview['notifications'] as List<dynamic>? ?? [];
    final student = overview['student'] as Map<String, dynamic>?;
    final targetCountries =
        (overview['targetCountries'] as List<dynamic>? ?? []).join('، ');
    final stageKey = overview['journeyStage'] as String?;
    final stageName = (stageKey != null ? _stageLabels[stageKey] : null) ??
        stageKey ??
        '—';

    // Ordered journey milestones to display as a mini-roadmap
    const milestones = [
      ('applying', 'التقديم', Icons.edit_document),
      ('preliminary-accepted', 'القبول المبدئي', Icons.check_circle_outline_rounded),
      ('first-payment', 'الدفعة الأولى', Icons.payments_outlined),
      ('final-accepted', 'القبول النهائي', Icons.verified_rounded),
      ('visa', 'التأشيرة', Icons.card_travel_rounded),
      ('travel', 'السفر', Icons.flight_takeoff_rounded),
      ('accommodation', 'السكن', Icons.home_work_outlined),
    ];

    final stageKeys = _stageLabels.keys.toList();
    final currentIdx = stageKey != null ? stageKeys.indexOf(stageKey) : -1;

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

        // Journey stage card — current stage highlighted
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
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
                      const Text('المرحلة الحالية',
                          style: AppTextStyles.caption),
                      Text(stageName, style: AppTextStyles.cardTitle),
                    ])),
              ]),
              if (stageKey != null) ...[
                const SizedBox(height: 14),
                // Mini roadmap for key milestones
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: milestones.map((m) {
                    final mIdx = stageKeys.indexOf(m.$1);
                    final isDone = mIdx != -1 && currentIdx >= mIdx;
                    final isCurrent = m.$1 == stageKey;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.orange.withValues(alpha: 0.12)
                            : isDone
                                ? AppColors.success.withValues(alpha: 0.08)
                                : AppColors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.orange
                              : isDone
                                  ? AppColors.success.withValues(alpha: 0.4)
                                  : AppColors.border,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : m.$3,
                          size: 13,
                          color: isCurrent
                              ? AppColors.orange
                              : isDone
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          m.$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isCurrent
                                ? AppColors.orange
                                : isDone
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
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

        // Important Notifications
        if (notifications.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('الإشعارات المهمة', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          ...notifications.map((n) {
            final notif = n as Map<String, dynamic>;
            final type = notif['type'] as String? ?? 'info';
            final isRead = notif['isRead'] as bool? ?? true;
            final notifColor = switch (type) {
              'success' => AppColors.success,
              'warning' => AppColors.warning,
              _ => AppColors.info,
            };
            final notifIcon = switch (type) {
              'success' => Icons.check_circle_outline_rounded,
              'warning' => Icons.warning_amber_rounded,
              _ => Icons.notifications_none_rounded,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: notifColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(notifIcon, color: notifColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(notif['title'] as String? ?? '',
                                    style: AppTextStyles.cardTitle
                                        .copyWith(fontSize: 13))),
                            if (!isRead)
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    color: AppColors.orange,
                                    shape: BoxShape.circle),
                              ),
                          ]),
                          const SizedBox(height: 2),
                          Text(notif['message'] as String? ?? '',
                              style: AppTextStyles.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
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
        const Text('فواتير الطالب', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        if (_loadingPayments)
          const LoadingState()
        else if (_payments == null)
          const AppCard(
              child: Text('تعذر تحميل الفواتير.',
                  style: AppTextStyles.caption))
        else if (_payments!.isEmpty)
          const AppCard(
              child: Text('لا توجد فواتير مسجّلة بعد لهذا الطالب.',
                  style: AppTextStyles.caption))
        else
          ..._payments!.map(_buildInvoiceRow),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInvoiceRow(dynamic p) {
    final inv = p as Map<String, dynamic>;
    final status = inv['status'] as String? ?? 'unpaid';
    final amount = inv['amount'];
    final currency = inv['currency'] as String? ?? 'USD';
    final desc = inv['description'] as String? ?? inv['invoiceNumber'] as String? ?? 'فاتورة';
    final invNum = inv['invoiceNumber'] as String? ?? '';
    final dueDate = inv['dueDate'] as String?;
    final proofs = inv['proofs'] as List<dynamic>? ?? [];
    final canPay = status == 'unpaid' || status == 'rejected';

    final (label, color) = switch (status) {
      'paid' => ('مدفوع', AppColors.success),
      'pending-confirmation' => ('قيد المراجعة', AppColors.warning),
      'rejected' => ('مرفوض', AppColors.danger),
      _ => ('غير مدفوع', AppColors.orange),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    status == 'paid' ? Icons.check_circle_outline_rounded : Icons.receipt_long_outlined,
                    color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(desc, style: AppTextStyles.cardTitle),
                if (invNum.isNotEmpty) Text(invNum, style: AppTextStyles.caption),
                if (dueDate != null) Text('الاستحقاق: ${_formatDate(dueDate)}', style: AppTextStyles.caption),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (amount != null)
                  Text('$amount $currency',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                StatusBadge(label: label, color: color),
              ]),
            ]),

            // Previous proofs
            if (proofs.isNotEmpty) ...[
              const Divider(height: 16),
              ...proofs.map((pr) {
                final proof = pr as Map<String, dynamic>;
                final paidBy = proof['paidBy'] as Map<String, dynamic>?;
                final paidByName = paidBy?['name'] as String?;
                final paidByRole = paidBy?['role'] as String?;
                final pStatus = proof['status'] as String? ?? 'pending';
                final (pLabel, pColor) = switch (pStatus) {
                  'approved' => ('مقبول', AppColors.success),
                  'rejected' => ('مرفوض', AppColors.danger),
                  _ => ('قيد المراجعة', AppColors.warning),
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.attach_file_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      paidByName != null
                          ? (paidByRole == 'parent' ? 'دفعها الوالد/الوالدة ($paidByName)' : 'دفعها الطالب')
                          : 'إثبات دفع',
                      style: AppTextStyles.caption)),
                    StatusBadge(label: pLabel, color: pColor),
                  ]),
                );
              }),
            ],

            // Pay button
            if (canPay) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _PayInvoiceButton(
                  studentId: (_children[_selectedIndex] as Map<String, dynamic>)['_id'] as String,
                  invoiceId: inv['_id'] as String,
                  invoiceDesc: desc,
                  onPaid: () {
                    _loadPayments(_selectedIndex);
                  },
                ),
              ),
            ],
          ],
        ),
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

class _PayInvoiceButton extends StatefulWidget {
  final String studentId;
  final String invoiceId;
  final String invoiceDesc;
  final VoidCallback onPaid;
  const _PayInvoiceButton({
    required this.studentId,
    required this.invoiceId,
    required this.invoiceDesc,
    required this.onPaid,
  });

  @override
  State<_PayInvoiceButton> createState() => _PayInvoiceButtonState();
}

class _PayInvoiceButtonState extends State<_PayInvoiceButton> {
  bool _uploading = false;

  Future<void> _pay() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      await ParentRepository.instance.uploadPaymentProof(
        studentId: widget.studentId,
        invoiceId: widget.invoiceId,
        fileBytes: file.bytes!,
        fileName: file.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم إرسال إثبات الدفع، بانتظار مراجعة الفريق'),
            backgroundColor: AppColors.success));
        widget.onPaid();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر رفع الملف، حاول مرة أخرى'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _uploading ? null : _pay,
      icon: _uploading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.upload_file_rounded, size: 16),
      label: Text(_uploading ? 'جاري الرفع...' : 'رفع إثبات الدفع'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
