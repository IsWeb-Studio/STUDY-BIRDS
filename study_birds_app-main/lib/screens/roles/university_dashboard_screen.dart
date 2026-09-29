import '../services_support/messaging_and_emergency_screens.dart';
import '../profile_account/security_settings_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/university_repository.dart';
import '../applications_documents_payments/applications_screens.dart'
    show appStatusMeta;
import 'university_application_review_screen.dart';

/// University Mode Home — application-processing-first. Real data from
/// server/src/routes/universityPortalRoutes.js (built specifically for this
/// role — see backend-role-updates.zip). Every application shown here is
/// already scoped server-side to this account's own linkedUniversity.
class UniversityDashboardScreen extends StatefulWidget {
  const UniversityDashboardScreen({super.key});

  @override
  State<UniversityDashboardScreen> createState() =>
      _UniversityDashboardScreenState();
}

class _UniversityDashboardScreenState extends State<UniversityDashboardScreen> {
  List<dynamic> _applications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await UniversityRepository.instance.getApplications();
      if (!mounted) return;
      setState(() {
        _applications = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'تعذر تحميل الطلبات، حاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _applications.length;
    final pending = _applications.where((a) {
      final status = (a as Map<String, dynamic>)['status'] as String?;
      return status == 'submitted' || status == 'under-review';
    }).length;
    final accepted = _applications
        .where((a) => (a as Map<String, dynamic>)['status'] == 'accepted')
        .length;

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
      title: 'لوحة الجامعة',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري تحميل الطلبات...')
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _StatCard(
                                value: '$total', label: 'إجمالي الطلبات')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _StatCard(
                                value: '$pending', label: 'بانتظار قراري')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _StatCard(
                                value: '$accepted', label: 'مقبولين')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('الطلبات', style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 10),
                    if (_applications.isEmpty)
                      const EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'لا توجد طلبات بعد',
                          message: 'ستظهر هنا الطلبات المرسلة لجامعتكم.')
                    else
                      ..._applications.map((a) {
                        final app = a as Map<String, dynamic>;
                        final student = app['student'] as Map<String, dynamic>?;
                        final program = app['program'] as Map<String, dynamic>?;
                        final meta = appStatusMeta(app);
                        return AppCard(
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (_) =>
                                      UniversityApplicationReviewScreen(
                                          applicationId: app['_id'] as String,
                                          initialData: app)))
                              .then((_) => _load()),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                      child: Text(
                                          student?['name'] as String? ?? '—',
                                          style: AppTextStyles.cardTitle)),
                                  StatusBadge(
                                      label: meta.label, color: meta.color),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(program?['title'] as String? ?? '—',
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Text(value, style: AppTextStyles.screenTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
