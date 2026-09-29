import '../../core/api_client.dart';
import 'catalog_detail.dart' show catalogArticleSections, catalogAssetUrl;
import '../../core/auth_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/catalog_repository.dart';
import '../../core/analytics_service.dart';
import 'universities_screens.dart' show UniversitiesExplorerScreen;

class CountriesExplorerScreen extends StatefulWidget {
  const CountriesExplorerScreen({super.key});

  @override
  State<CountriesExplorerScreen> createState() =>
      _CountriesExplorerScreenState();
}

class _CountriesExplorerScreenState extends State<CountriesExplorerScreen> {
  List<dynamic> _countries = [];
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
      final data = await CatalogRepository.instance.getCountries();
      if (!mounted) return;
      setState(() {
        _countries = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل قائمة الدول.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'استكشاف الدول',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3),
                itemCount: 6,
                itemBuilder: (_, __) => const SkeletonBox(
                    width: double.infinity, height: double.infinity, borderRadius: 12))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _countries.isEmpty
                    ? const EmptyState(
                        icon: Icons.public_off_rounded,
                        title: 'لا توجد دول مضافة بعد',
                        message: 'سيتم إضافتها من لوحة التحكم قريبًا.')
                    : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _countries.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.15),
                      itemBuilder: (context, i) {
                        final c = _countries[i] as Map<String, dynamic>;
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CountryDetailScreen(country: c))),
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                                border: Border.all(color: AppColors.border)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                      color: AppColors.navy.withValues(alpha: 0.08),
                                      shape: BoxShape.circle),
                                  child: (c['heroImage'] as String?)
                                              ?.isNotEmpty ==
                                          true
                                      ? ClipOval(
                                          child: Image.network(
                                            c['heroImage'] as String,
                                            fit: BoxFit.cover,
                                            width: 52,
                                            height: 52,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.public_rounded,
                                                    color: AppColors.navy,
                                                    size: 24),
                                          ),
                                        )
                                      : const Icon(Icons.public_rounded,
                                          color: AppColors.navy, size: 24),
                                ),
                                const SizedBox(height: 10),
                                Text(c['name'] as String? ?? '—',
                                    style: AppTextStyles.cardTitle),
                                const SizedBox(height: 2),
                                Text('${c['universityCount'] ?? 0} جامعة',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}

class CountryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> country;
  const CountryDetailScreen({super.key, required this.country});
  @override
  State<CountryDetailScreen> createState() => _CountryDetailScreenState();
}

class _CountryDetailScreenState extends State<CountryDetailScreen> {
  late Map<String, dynamic> _country;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _country = widget.country;
    AnalyticsService.instance.screenView(
        'country_detail_${(_country['_id'] ?? _country['name'] ?? 'unknown')}');
  }

  Future<void> _load() async {
    if (_country['_id'] == null) return;
    setState(() => _loading = true);
    try {
      final list = await CatalogRepository.instance.getCountries();
      final updated = list.firstWhere(
              (c) => (c as Map)['_id'] == _country['_id'],
              orElse: () => _country) as Map<String, dynamic>;
      if (mounted) setState(() => _country = updated);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _infoSection(String title, String body) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        AppCard(child: Text(body, style: AppTextStyles.body)),
      ]);

  @override
  Widget build(BuildContext context) {
    final description = _country['description'] as String?;
    final visaNotes = _country['visaNotes'] as String?;
    final livingCostNotes = _country['livingCostNotes'] as String?;
    final housingNotes = _country['housingNotes'] as String?;
    final studentLifeNotes = _country['studentLifeNotes'] as String?;
    final transportNotes = _country['transportNotes'] as String?;
    final healthInsuranceNotes = _country['healthInsuranceNotes'] as String?;
    final language = _country['language'] as String?;
    final currency = _country['currency'] as String?;
    final faqs = _country['faqs'] is List ? _country['faqs'] as List : null;
    final heroImage = catalogAssetUrl(_country['heroImage']);

    return AppScaffold(
      title: _country['name'] as String? ?? 'دولة',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
            : ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.card)),
                    child: heroImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            child: Image.network(
                              heroImage,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.flag_rounded,
                                      size: 40, color: AppColors.navy)),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.flag_rounded,
                                size: 40, color: AppColors.navy)),
                  ),
                  const SizedBox(height: 16),
                  if (description != null && description.isNotEmpty) ...[
                    AppCard(child: Text(description, style: AppTextStyles.body)),
                    const SizedBox(height: 12),
                  ],
                  AppCard(
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: [
                        _Fact(
                            label: 'عدد الجامعات',
                            value: '${_country['universityCount'] ?? 0}'),
                        _Fact(
                            label: 'عدد التخصصات',
                            value: '${_country['specialtyCount'] ?? 0}'),
                        if (_country['averageTuition'] != null)
                          _Fact(
                              label: 'متوسط الرسوم السنوية',
                              value: '\$${_country['averageTuition']}'),
                        if (language != null && language.isNotEmpty)
                          _Fact(label: 'لغة الدراسة', value: language),
                        if (currency != null && currency.isNotEmpty)
                          _Fact(label: 'العملة', value: currency),
                      ],
                    ),
                  ),
                  if (visaNotes != null && visaNotes.isNotEmpty)
                    _infoSection('إجراءات التأشيرة', visaNotes),
                  if (livingCostNotes != null && livingCostNotes.isNotEmpty)
                    _infoSection('تكاليف المعيشة والدراسة', livingCostNotes),
                  if (housingNotes != null && housingNotes.isNotEmpty)
                    _infoSection('السكن الطلابي', housingNotes),
                  if (transportNotes != null && transportNotes.isNotEmpty)
                    _infoSection('وسائل النقل', transportNotes),
                  if (healthInsuranceNotes != null &&
                      healthInsuranceNotes.isNotEmpty)
                    _infoSection('التأمين الصحي', healthInsuranceNotes),
                  if (studentLifeNotes != null && studentLifeNotes.isNotEmpty)
                    _infoSection('الحياة الطلابية', studentLifeNotes),
                  if (faqs != null && faqs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('الأسئلة الشائعة',
                        style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 10),
                    for (final faq in faqs)
                      if (faq is Map)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                if ((faq['question'] as String?)?.isNotEmpty ==
                                    true)
                                  Text(faq['question'] as String,
                                      style: AppTextStyles.cardTitle),
                                if ((faq['answer'] as String?)?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 8),
                                  Text(faq['answer'] as String,
                                      style: AppTextStyles.body),
                                ],
                              ])),
                        ),
                  ],
                  ...catalogArticleSections(_country),
                  const SizedBox(height: 16),
                  AppCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => UniversitiesExplorerScreen(
                            countryId: _country['_id'] as String?))),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_rounded,
                            color: AppColors.navy, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Text('عرض جامعات هذه الدولة',
                                style: AppTextStyles.cardTitle)),
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ]),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact({required this.label, required this.value});
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

class ScholarshipsScreen extends StatefulWidget {
  const ScholarshipsScreen({super.key});
  @override
  State<ScholarshipsScreen> createState() => _ScholarshipsScreenState();
}

class _ScholarshipsScreenState extends State<ScholarshipsScreen> {
  List<dynamic> rows = [], entries = [];
  bool loading = true, sending = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        ApiClient.instance.get('/scholarships'),
        if (AuthSession.instance.currentUser?.role == UserRole.student)
          ApiClient.instance
              .get('/scholarships/mine', token: AuthSession.instance.token),
      ]);
      if (mounted)
        setState(() {
          rows = values[0] as List;
          entries = values.length > 1 ? values[1] as List : [];
        });
    } catch (e) {
      if (mounted)
        setState(() => error = e is ApiException && e.statusCode == 404
            ? 'لم تُنشر خدمة المنح بعد.'
            : 'تعذر تحميل المنح. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> apply(Map row) async {
    final yes = await showAppConfirmDialog(context,
        title: 'التقديم للمنحة',
        message:
            'إرسال طلبك لمنحة ${row['title']}؟ سيخضع الطلب لمراجعة الأهلية.',
        confirmLabel: 'إرسال الطلب');
    if (yes != true) return;
    setState(() => sending = true);
    try {
      await ApiClient.instance.post('/scholarships/${row['_id']}/apply',
          token: AuthSession.instance.token, body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل الطلب للمراجعة')));
        await load();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'تعذر إرسال الطلب')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'المنح الدراسية',
      actions: [
        IconButton(
            onPressed: sending ? null : load, icon: const Icon(Icons.refresh))
      ],
      body: loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
          : error != null
              ? ErrorState(message: error!, onRetry: load)
              : rows.isEmpty && entries.isEmpty
                  ? const EmptyState(
                      icon: Icons.school_outlined,
                      title: 'لا توجد منح منشورة حاليًا',
                      message: 'ستظهر المنح وشروطها عند نشرها من الإدارة.')
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      for (final item in rows)
                        AppCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('${item['title']}',
                                  style: AppTextStyles.cardTitle),
                              Text([
                                item['university'],
                                item['country'],
                                item['degree'],
                                item['funding']
                              ]
                                  .where((v) => v != null && '$v'.isNotEmpty)
                                  .join(' • ')),
                              if (item['eligibility'] != null)
                                Text('${item['eligibility']}'),
                              if (item['deadline'] != null)
                                Text(
                                    'آخر موعد: ${item['deadline'].toString().split('T').first}'),
                              const SizedBox(height: 12),
                              if (AuthSession.instance.currentUser?.role ==
                                  UserRole.student)
                                PrimaryButton(
                                    label: entries.any((e) =>
                                            e['scholarship']?['_id'] ==
                                            item['_id'])
                                        ? 'تم تقديم الطلب'
                                        : 'تقديم الطلب',
                                    onPressed: sending ||
                                            entries.any((e) =>
                                                e['scholarship']?['_id'] ==
                                                item['_id'])
                                        ? null
                                        : () => apply(item as Map)),
                            ])),
                      if (entries.isNotEmpty)
                        const Text('طلباتي السابقة',
                            style: AppTextStyles.sectionLabel),
                      for (final entry in entries)
                        ListTile(
                            title: Text(
                                '${entry['scholarship']?['title'] ?? 'منحة'}'),
                            subtitle: Text(const {
                                  'submitted': 'تم التقديم',
                                  'reviewing': 'قيد المراجعة',
                                  'accepted': 'مقبول',
                                  'rejected': 'غير مقبول'
                                }[entry['status']] ??
                                '${entry['status']}')),
                    ]));
}
