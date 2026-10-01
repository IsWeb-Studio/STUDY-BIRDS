import '../services_support/messaging_and_emergency_screens.dart';
import '../profile_account/security_settings_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/university_repository.dart';
import '../applications_documents_payments/applications_screens.dart'
    show appStatusMeta;
import 'university_application_review_screen.dart';

class UniversityDashboardScreen extends StatefulWidget {
  const UniversityDashboardScreen({super.key});
  @override
  State<UniversityDashboardScreen> createState() =>
      _UniversityDashboardScreenState();
}

class _UniversityDashboardScreenState
    extends State<UniversityDashboardScreen> {
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();

  static const _statusOptions = [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'under-review', 'label': 'قيد المراجعة'},
    {'key': 'additional-documents-required', 'label': 'مستندات مطلوبة'},
    {'key': 'conditional-admission', 'label': 'قبول مبدئي'},
    {'key': 'final-admission', 'label': 'قبول نهائي'},
    {'key': 'accepted', 'label': 'مقبول'},
    {'key': 'rejected', 'label': 'مرفوض'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        _all = data;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e is ApiException ? e.message : 'تعذر تحميل الطلبات، حاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((a) {
        final app = a as Map<String, dynamic>;
        final status = app['detailedStatus'] as String? ?? app['status'] as String? ?? '';
        final student = app['student'] as Map<String, dynamic>?;
        final name = (student?['name'] as String? ?? '').toLowerCase();
        final matchStatus =
            _statusFilter == 'all' || status == _statusFilter;
        final matchSearch = q.isEmpty || name.contains(q);
        return matchStatus && matchSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uniName = AuthSession.instance.currentUser?.name ?? 'الجامعة';
    final total = _all.length;
    final pending = _all.where((a) {
      final m = a as Map;
      final s = m['detailedStatus'] ?? m['status'];
      return s == 'submitted' || s == 'under-review';
    }).length;
    final accepted = _all.where((a) {
      final m = a as Map;
      final s = m['detailedStatus'] ?? m['status'];
      return s == 'accepted' || s == 'final-admission';
    }).length;
    final rejected = _all.where((a) {
      final m = a as Map;
      return (m['detailedStatus'] ?? m['status']) == 'rejected';
    }).length;

    return AppScaffold(
      actions: [
        IconButton(
            tooltip: 'الرسائل',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConversationThreadScreen()))),
        IconButton(
            tooltip: 'أمان الحساب',
            icon: const Icon(Icons.security_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SecuritySettingsScreen()))),
      ],
      title: 'بوابة الجامعة',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري تحميل الطلبات...')
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _buildContent(
                    uniName, total, pending, accepted, rejected),
      ),
    );
  }

  Widget _buildContent(
      String uniName, int total, int pending, int accepted, int rejected) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _HeroBanner(uniName: uniName)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                    child: _StatCard(
                        value: '$total',
                        label: 'إجمالي\nالطلبات',
                        color: AppColors.navy)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatCard(
                        value: '$pending',
                        label: 'بانتظار\nالمراجعة',
                        color: AppColors.info)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatCard(
                        value: '$accepted',
                        label: 'مقبولون',
                        color: AppColors.success)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatCard(
                        value: '$rejected',
                        label: 'مرفوضون',
                        color: AppColors.danger)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن طالب...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter();
                        })
                    : null,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final opt = _statusOptions[i];
                final selected = _statusFilter == opt['key'];
                return ChoiceChip(
                  label: Text(opt['label']!),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _statusFilter = opt['key']!);
                    _applyFilter();
                  },
                  selectedColor: AppColors.navy,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontSize: 13),
                  backgroundColor: AppColors.card,
                  side: BorderSide(
                      color:
                          selected ? AppColors.navy : AppColors.border),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (_filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
                icon: Icons.inbox_outlined,
                title: _all.isEmpty
                    ? 'لا توجد طلبات بعد'
                    : 'لا توجد نتائج',
                message: _all.isEmpty
                    ? 'ستظهر هنا الطلبات المرسلة إلى جامعتكم.'
                    : 'جرّب تعديل فلتر البحث.'),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final app = _filtered[i] as Map<String, dynamic>;
                return _AppCard(
                  app: app,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                          builder: (_) =>
                              UniversityApplicationReviewScreen(
                                  applicationId: app['_id'] as String,
                                  initialData: app)))
                      .then((_) => _load()),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─── Hero Banner ─────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String uniName;
  const _HeroBanner({required this.uniName});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(uniName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                const Text('بوابة استعراض وإدارة طلبات القبول',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Application Card ─────────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final VoidCallback onTap;
  const _AppCard({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final student = app['student'] as Map<String, dynamic>?;
    final program = app['program'] as Map<String, dynamic>?;
    final name = student?['name'] as String? ?? '—';
    final email = student?['email'] as String? ?? '';
    final programName = program?['title'] as String? ?? program?['name'] as String? ?? '—';
    final meta = appStatusMeta(app);
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(initials,
                  style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(programName,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(email,
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: meta.label, color: meta.color),
                const SizedBox(height: 6),
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 12, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
