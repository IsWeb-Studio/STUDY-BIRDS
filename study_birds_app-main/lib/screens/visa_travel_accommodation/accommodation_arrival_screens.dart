import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/student_repository.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';

// ─── بند 40: السكن الطلابي ────────────────────────────────────────────────────

class AccommodationScreen extends StatefulWidget {
  const AccommodationScreen({super.key});
  @override
  State<AccommodationScreen> createState() => _AccommodationScreenState();
}

class _AccommodationScreenState extends State<AccommodationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<dynamic> _listings = [];
  List<dynamic> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = AuthSession.instance.token;
      final results = await Future.wait([
        ApiClient.instance.get('/students/accommodations', token: token),
        ApiClient.instance.get('/students/accommodation-bookings', token: token),
      ]);
      if (!mounted) return;
      setState(() {
        _listings = results[0] as List? ?? [];
        _bookings = results[1] as List? ?? [];
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل السكن. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.navy,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'السكن الطلابي',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17),
            ),
            bottom: TabBar(
              controller: _tabs,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [Tab(text: 'الوحدات المتاحة'), Tab(text: 'طلباتي')],
            ),
          ),
          body: SafeArea(
            child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 4,
                    itemBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.navy,
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _ListingsTab(
                              listings: _listings,
                              bookings: _bookings,
                              onBooked: _load,
                            ),
                            _BookingsTab(
                                bookings: _bookings, onCancelled: _load),
                          ],
                        ),
                      ),
          ),
        ),
      );
}

class _ListingsTab extends StatelessWidget {
  final List listings;
  final List bookings;
  final VoidCallback onBooked;
  const _ListingsTab(
      {required this.listings,
      required this.bookings,
      required this.onBooked});

  bool get _hasActive => bookings
      .any((b) => b is Map && ['pending', 'confirmed'].contains(b['status']));

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.apartment_rounded,
          title: 'لا توجد وحدات متاحة حاليًا',
          message: 'تواصل مع الفريق للاستفسار عن خيارات السكن.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: listings.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ListingCard(
          listing: listings[i] as Map,
          canBook: !_hasActive,
          onBooked: onBooked,
        ),
      ),
    );
  }
}

class _ListingCard extends StatefulWidget {
  final Map listing;
  final bool canBook;
  final VoidCallback onBooked;
  const _ListingCard(
      {required this.listing,
      required this.canBook,
      required this.onBooked});

  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  bool _booking = false;

  static const _typeLabels = {
    'single': 'غرفة منفردة',
    'shared': 'غرفة مشتركة',
    'apartment': 'شقة',
  };

  Future<void> _book() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحجز'),
        content: Text('هل تريد تقديم طلب حجز لـ "${widget.listing['title']}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _booking = true);
    try {
      await ApiClient.instance.post(
        '/students/accommodation-bookings',
        token: AuthSession.instance.token,
        body: {'listingId': '${widget.listing['_id']}'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تقديم طلب الحجز بنجاح')),
        );
        widget.onBooked();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ. أعد المحاولة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final typeLabel =
        _typeLabels['${l['type']}'] ?? '${l['type']}';
    final uniName = (l['university'] is Map)
        ? '${(l['university'] as Map)['name'] ?? ''}'
        : '';
    final amenities = (l['amenities'] as List?) ?? [];
    final price = (l['price'] as num?)?.toDouble() ?? 0;
    final currency = '${l['currency'] ?? 'USD'}';
    final capacity = (l['capacity'] as num?)?.toInt() ?? 0;

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('${l['title']}', style: AppTextStyles.cardTitle)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(typeLabel,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy)),
          ),
        ]),
        if (uniName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.school_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(uniName, style: AppTextStyles.caption),
          ]),
        ],
        if (l['distanceFromCampusKm'] != null) ...[
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.directions_walk_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('${l['distanceFromCampusKm']} كم من الحرم',
                style: AppTextStyles.caption),
          ]),
        ],
        if (amenities.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: amenities
                .take(4)
                .map((a) => Chip(
                      label: Text('$a',
                          style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          AppColors.background,
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$price $currency / شهر',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy)),
              if (capacity > 0)
                Text('السعة: $capacity',
                    style: AppTextStyles.caption),
            ]),
            if (widget.canBook)
              _booking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.navy))
                  : ElevatedButton(
                      onPressed: _book,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text('احجز الآن'),
                    )
            else
              Text('لديك حجز نشط', style: AppTextStyles.caption),
          ],
        ),
      ]),
    );
  }
}

class _BookingsTab extends StatelessWidget {
  final List bookings;
  final VoidCallback onCancelled;
  const _BookingsTab({required this.bookings, required this.onCancelled});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.apartment_outlined,
          title: 'لا توجد طلبات حجز',
          message: 'تصفّح الوحدات المتاحة وقدّم طلب حجزك.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: bookings.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _BookingCard(
          booking: bookings[i] as Map,
          onCancelled: onCancelled,
        ),
      ),
    );
  }
}

class _BookingCard extends StatefulWidget {
  final Map booking;
  final VoidCallback onCancelled;
  const _BookingCard({required this.booking, required this.onCancelled});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  bool _cancelling = false;

  static const _statusLabels = {
    'pending': 'قيد المراجعة',
    'confirmed': 'مؤكّد',
    'rejected': 'مرفوض',
    'cancelled': 'ملغى',
  };
  static const _statusColors = {
    'pending': AppColors.warning,
    'confirmed': AppColors.success,
    'rejected': AppColors.danger,
    'cancelled': AppColors.neutral,
  };

  Future<void> _cancel() async {
    final version = (widget.booking['__v'] as num?)?.toInt() ?? 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لا')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('نعم، ألغِ')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ApiClient.instance.post(
        '/students/accommodation-bookings/${widget.booking['_id']}/cancel',
        token: AuthSession.instance.token,
        body: {'version': version},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الحجز')),
        );
        widget.onCancelled();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ. أعد المحاولة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final status = '${b['status'] ?? 'pending'}';
    final statusLabel = _statusLabels[status] ?? status;
    final statusColor = _statusColors[status] ?? AppColors.neutral;
    final listing = b['listing'] is Map ? b['listing'] as Map : null;
    final title = listing != null ? '${listing['title'] ?? ''}' : 'وحدة سكنية';
    final uniName = listing != null && listing['university'] is Map
        ? '${(listing['university'] as Map)['name'] ?? ''}'
        : '';
    final canCancel = ['pending', 'confirmed'].contains(status);
    final date = _fmtDate(b['createdAt']);

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(title,
                    style: AppTextStyles.cardTitle,
                    overflow: TextOverflow.ellipsis)),
            StatusBadge(label: statusLabel, color: statusColor),
          ],
        ),
        if (uniName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.school_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(uniName, style: AppTextStyles.caption),
          ]),
        ],
        if (date.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('تاريخ الطلب: $date', style: AppTextStyles.caption),
        ],
        if (b['staffNote'] != null &&
            '${b['staffNote']}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('ملاحظة الفريق: ${b['staffNote']}',
                style: AppTextStyles.caption),
          ),
        ],
        if (canCancel) ...[
          const SizedBox(height: 10),
          _cancelling
              ? const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.navy)))
              : OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    side: const BorderSide(color: AppColors.danger),
                    foregroundColor: AppColors.danger,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.button)),
                  ),
                  child: const Text('إلغاء الحجز'),
                ),
        ],
      ]),
    );
  }

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// Required documents the student should prepare for the registration day.
/// Only the first three have matching upload keys in the Study Birds system.
const List<({String docKey, String label})> kUniversityRegistrationDocs = [
  (docKey: 'passport', label: 'جواز السفر الأصلي'),
  (docKey: 'biometric-photo', label: 'صور شخصية'),
  (docKey: 'latest-qualification', label: 'آخر مؤهل دراسي'),
  (docKey: 'transcript', label: 'كشف الدرجات'),
];

({String label, Color color}) uniRegBadgeFromJourneyStage(String stage) {
  const order = [
    'file-received',
    'documents-review',
    'university-selection',
    'applying',
    'university-review',
    'preliminary-accepted',
    'first-payment',
    'final-accepted',
    'visa',
    'travel',
    'reception',
    'accommodation',
    'university-registration',
    'studies-started',
  ];
  final idx = order.indexOf(stage);
  if (idx < 0 || idx < 12) {
    return (label: 'لم يحن الوقت بعد', color: AppColors.neutral);
  }
  if (idx == 12) {
    return (label: 'بانتظار الموعد', color: AppColors.warning);
  }
  return (label: 'مكتمل', color: AppColors.success);
}

class UniversityRegistrationScreen extends StatefulWidget {
  const UniversityRegistrationScreen({super.key});
  @override
  State<UniversityRegistrationScreen> createState() =>
      _UniversityRegistrationScreenState();
}

class _UniversityRegistrationScreenState
    extends State<UniversityRegistrationScreen> {
  final _repo = StudentRepository.instance;
  bool _loading = true;
  String? _error;
  String _stage = '';
  Set<String> _uploadedKeys = {};

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
      final results =
          await Future.wait([_repo.getOverview(), _repo.getDocuments()]);
      if (!mounted) return;
      final overview = results[0] as Map<String, dynamic>?;
      final docs = results[1] as List<dynamic>;
      setState(() {
        _stage = '${overview?['journeyStage'] ?? ''}';
        _uploadedKeys = docs
            .whereType<Map>()
            .map((d) => '${d['type']}')
            .toSet();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException
            ? e.message
            : 'تعذر تحميل البيانات. أعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = uniRegBadgeFromJourneyStage(_stage);
    return AppScaffold(
      title: 'تسجيل الجامعة',
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.navy,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: StatusBadge(label: badge.label, color: badge.color)),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 16),
                const Text('المستندات المطلوبة',
                    style: AppTextStyles.sectionLabel),
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    children: [
                      for (int i = 0;
                          i < kUniversityRegistrationDocs.length;
                          i++) ...[
                        if (i > 0) const Divider(height: 16),
                        _DocRow(
                          label: kUniversityRegistrationDocs[i].label,
                          done: _uploadedKeys
                              .contains(kUniversityRegistrationDocs[i].docKey),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('الموعد', style: AppTextStyles.sectionLabel),
                const SizedBox(height: 10),
                const AppCard(
                  child: Row(children: [
                    Icon(Icons.school_rounded, color: AppColors.navy),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'سيتم إبلاغك بتفاصيل موعد التسجيل من قِبل الفريق قريبًا.',
                            style: AppTextStyles.body)),
                  ]),
                ),
              ]),
            ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final bool done;
  const _DocRow({required this.label, required this.done});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: done ? AppColors.success : AppColors.neutral,
          size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: AppTextStyles.body)),
    ]);
  }
}

// InsuranceScreen and EquivalencyScreen are defined in visa_travel_screens.dart
