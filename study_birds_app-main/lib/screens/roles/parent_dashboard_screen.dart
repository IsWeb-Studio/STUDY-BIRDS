import '../services_support/messaging_and_emergency_screens.dart';
import '../profile_account/security_settings_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/parent_repository.dart';
import '../applications_documents_payments/applications_screens.dart'
    show appStatusMeta;

/// Parent Mode Home — "My Student" view. Real data from
/// server/src/routes/parentRoutes.js (a module built specifically for this
/// role — see backend-role-updates.zip). Zero visibility into Study Birds
/// internal/employee data; a parent only ever sees an APPROVED linked
/// student's overview/applications/payments, read-only.
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  List<dynamic> _children = [];
  List<dynamic> _linkRequests = [];
  int _selectedIndex = 0;
  // Incremented per overview request; a response is shown only if it is
  // still the latest, so a slow answer for a previously selected child never
  // appears under the newly selected one.
  int _overviewRequest = 0;
  bool _loadingChildren = true;
  String? _loadError;

  Map<String, dynamic>? _overview;
  bool _loadingOverview = false;

  final _emailController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _sendingRequest = false;
  String? _requestError;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _relationshipController.dispose();
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
      if (_children.isNotEmpty) _loadOverview(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'تعذر تحميل بياناتك.';
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
      final data = await ParentRepository.instance.getChildOverview(studentId);
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

  Future<void> _sendLinkRequest() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _requestError = 'أدخل البريد الإلكتروني للطالب');
      return;
    }
    setState(() {
      _sendingRequest = true;
      _requestError = null;
    });
    try {
      await ParentRepository.instance.createLinkRequest(
        studentEmail: _emailController.text.trim(),
        relationship: _relationshipController.text.trim().isEmpty
            ? null
            : _relationshipController.text.trim(),
      );
      _emailController.clear();
      _relationshipController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم إرسال طلب الربط، بانتظار موافقة الإدارة'),
            backgroundColor: AppColors.success));
      }
      await _loadChildren();
    } catch (_) {
      if (mounted)
        setState(() => _requestError =
            'تعذر إرسال الطلب — تأكد إن البريد صحيح ومسجّل كحساب طالب.');
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      actions: [
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
      title: 'حساب ولي الأمر',
      body: RefreshIndicator(
        onRefresh: _loadChildren,
        color: AppColors.navy,
        child: _loadingChildren
            ? const LoadingState(message: 'جاري تحميل بياناتك...')
            : _loadError != null
                ? ErrorState(message: _loadError!, onRetry: _loadChildren)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                    _buildLinkRequestForm(),
                    if (_linkRequests.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('طلبات الربط',
                          style: AppTextStyles.sectionLabel),
                      const SizedBox(height: 10),
                      ..._linkRequests.map((r) {
                        final req = r as Map<String, dynamic>;
                        final student = req['student'] as Map<String, dynamic>?;
                        final status = req['status'] as String?;
                        final meta = status == 'approved'
                            ? const _SimpleMeta('مقبول', AppColors.success)
                            : status == 'rejected'
                                ? const _SimpleMeta('مرفوض', AppColors.danger)
                                : const _SimpleMeta(
                                    'قيد المراجعة', AppColors.warning);
                        return AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      student?['email'] as String? ??
                                          student?['name'] as String? ??
                                          '—',
                                      style: AppTextStyles.body)),
                              StatusBadge(label: meta.label, color: meta.color),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (_children.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('ابني/ابنتي',
                          style: AppTextStyles.sectionLabel),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _children.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final child = _children[i] as Map<String, dynamic>;
                            final selected = i == _selectedIndex;
                            return GestureDetector(
                              onTap: () => _loadOverview(i),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                      selected ? AppColors.navy : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.chip),
                                  border: Border.all(
                                      color: selected
                                          ? AppColors.navy
                                          : AppColors.border),
                                ),
                                child: Text(child['name'] as String? ?? '—',
                                    style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_loadingOverview)
                        const LoadingState()
                      else if (_overview != null)
                        _buildOverview(_overview!)
                      else
                        const AppCard(
                            child: Text('تعذر تحميل تفاصيل هذا الطالب.',
                                style: AppTextStyles.caption)),
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _buildLinkRequestForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ربط حساب طالب جديد', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 4),
          const Text('أدخل البريد الإلكتروني المسجّل به حساب ابنك/ابنتك.',
              style: AppTextStyles.caption),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.border)),
            child: TextField(
              controller: _emailController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                  hintText: 'بريد الطالب الإلكتروني',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.border)),
            child: TextField(
              controller: _relationshipController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                  hintText: 'صلة القرابة (اختياري)',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
            ),
          ),
          if (_requestError != null) ...[
            const SizedBox(height: 8),
            Text(_requestError!,
                style:
                    const TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ],
          const SizedBox(height: 10),
          PrimaryButton(
              label: _sendingRequest ? 'جاري الإرسال...' : 'إرسال طلب الربط',
              onPressed: _sendingRequest ? null : _sendLinkRequest,
              expand: false),
        ],
      ),
    );
  }

  Widget _buildOverview(Map<String, dynamic> overview) {
    final applications = overview['applications'] as List<dynamic>? ?? [];
    final student = overview['student'] as Map<String, dynamic>?;
    final targetCountries =
        (overview['targetCountries'] as List<dynamic>? ?? []).join('، ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.border,
                      child: Icon(Icons.person_rounded, color: AppColors.navy)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student?['name'] as String? ?? '—',
                            style: AppTextStyles.cardTitle),
                        Text(student?['email'] as String? ?? '',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
              if (targetCountries.isNotEmpty || overview['intake'] != null) ...[
                const Divider(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (targetCountries.isNotEmpty)
                      _MiniFact(
                          label: 'الدول المستهدفة', value: targetCountries),
                    if (overview['intake'] != null)
                      _MiniFact(
                          label: 'الفصل الدراسي',
                          value: overview['intake'] as String),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.timeline_rounded, color: AppColors.navy),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'مرحلة الرحلة: ${overview['journeyStage'] ?? '—'}',
                      style: AppTextStyles.cardTitle)),
            ],
          ),
        ),
        const Text('الطلبات', style: AppTextStyles.sectionLabel),
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
            return AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(uni?['name'] as String? ?? '—',
                            style: AppTextStyles.cardTitle),
                        Text(program?['name'] as String? ?? '',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  StatusBadge(label: meta.label, color: meta.color),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _SimpleMeta {
  final String label;
  final Color color;
  const _SimpleMeta(this.label, this.color);
}

class _MiniFact extends StatelessWidget {
  final String label;
  final String value;
  const _MiniFact({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
