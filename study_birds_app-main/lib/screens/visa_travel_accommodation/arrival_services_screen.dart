import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/student_repository.dart';

class ArrivalServicesScreen extends StatefulWidget {
  const ArrivalServicesScreen({super.key});

  @override
  State<ArrivalServicesScreen> createState() => _ArrivalServicesScreenState();
}

class _ArrivalServicesScreenState extends State<ArrivalServicesScreen> {
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final data = await StudentRepository.instance.getArrivalServices();
      if (!mounted) return;
      setState(() {
        _requests = data.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is ApiException ? e.message : 'تعذر تحميل بياناتك.';
        _loading = false;
      });
    }
  }

  Future<void> _openNew() async {
    // Fetch all applications, filter out those already linked to an arrival service.
    List<Map<String, dynamic>> applications = [];
    try {
      final data = await StudentRepository.instance.getApplications();
      applications = data.whereType<Map<String, dynamic>>().toList();
    } catch (_) {}

    final usedAppIds = _requests
        .map((r) {
          final app = r['application'];
          if (app is Map) return app['_id']?.toString();
          return app?.toString();
        })
        .whereType<String>()
        .toSet();

    final available = applications
        .where((a) => !usedAppIds.contains(a['_id']?.toString()))
        .toList();

    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('جميع رحلاتك الدراسية لديها طلبات وصول مرتبطة بها بالفعل.'),
        backgroundColor: AppColors.orange,
      ));
      return;
    }

    // If only one available, go directly to form.
    if (available.length == 1) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _ArrivalFormScreen(application: available.first),
        ),
      );
      if (result == true) _load();
      return;
    }

    // Multiple available — show picker.
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ApplicationPickerSheet(applications: available),
    );
    if (picked == null || !mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ArrivalFormScreen(application: picked),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openEdit(Map<String, dynamic> req) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ArrivalFormScreen(existing: req)),
    );
    if (result == true) _load();
  }

  String _statusLabel(String? s) => switch (s) {
    'completed' => 'مكتمل',
    'in-progress' => 'قيد التنفيذ',
    _ => 'مُقدَّم',
  };

  Color _statusColor(String? s) => switch (s) {
    'completed' => AppColors.success,
    'in-progress' => AppColors.orange,
    _ => AppColors.info,
  };

  String _programTitle(Map<String, dynamic> req) {
    final app = req['application'];
    if (app is Map) {
      final prog = app['program'];
      if (prog is Map) return prog['title'] as String? ?? 'برنامج دراسي';
      return 'برنامج دراسي';
    }
    return 'رحلة دراسية';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'خدمات الوصول',
      body: _loading
          ? const LoadingState(message: 'جاري التحميل...')
          : _loadError != null
              ? ErrorState(message: _loadError!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.navy,
                  child: _buildList(),
                ),
      floatingActionButton: _loading || _loadError != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNew,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('رحلة جديدة'),
            ),
    );
  }

  Widget _buildList() {
    if (_requests.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.flight_land_rounded,
            title: 'لا توجد طلبات وصول',
            message: 'اضغط "رحلة جديدة" لتقديم طلب الاستقبال والخدمات.',
            ctaLabel: 'تقديم طلب جديد',
            onCta: _openNew,
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _requests.length,
      itemBuilder: (_, i) {
        final req = _requests[i];
        final services = req['services'] as Map<String, dynamic>? ?? {};
        final tags = [
          if (services['airportPickup'] == true) 'استقبال المطار',
          if (services['studentHousing'] == true) 'السكن',
          if (services['residencePermitSupport'] == true) 'الإقامة',
          if (services['visaSupport'] == true) 'التأشيرة',
        ];
        final programName = _programTitle(req);
        return AppCard(
          onTap: () => _openEdit(req),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(programName, style: AppTextStyles.cardTitle, overflow: TextOverflow.ellipsis),
                        if ((req['flightNumber'] as String? ?? '').isNotEmpty)
                          Text('رقم الرحلة: ${req['flightNumber']}', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: _statusLabel(req['status'] as String?),
                    color: _statusColor(req['status'] as String?),
                  ),
                ],
              ),
              if ((req['arrivalDate'] as String?) != null) ...[
                const SizedBox(height: 4),
                Text(
                  'تاريخ الوصول: ${(req['arrivalDate'] as String).substring(0, 10)}',
                  style: AppTextStyles.caption,
                ),
              ],
              if ((req['airport'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('المطار: ${req['airport']}', style: AppTextStyles.caption),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.navy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(t, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 6),
              Text('اضغط للتعديل', style: AppTextStyles.caption.copyWith(color: AppColors.navy, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

// ── Application picker bottom sheet ──────────────────────────────────────────

class _ApplicationPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> applications;
  const _ApplicationPickerSheet({required this.applications});

  String _label(Map<String, dynamic> app) {
    final prog = app['program'];
    final title = (prog is Map ? prog['title'] : null) as String? ?? 'برنامج دراسي';
    final uni = prog is Map ? (prog['university'] is Map ? prog['university']['name'] : null) : null;
    return uni != null ? '$title — $uni' : title;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر الرحلة الدراسية', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 4),
            const Text('اختر الرحلة التي تريد ربط طلب الوصول بها',
                style: AppTextStyles.caption),
            const SizedBox(height: 16),
            ...applications.map((app) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_outlined, size: 20, color: AppColors.navy),
                  ),
                  title: Text(_label(app), style: AppTextStyles.body),
                  subtitle: Text(
                    _statusAr(app['status'] as String?),
                    style: AppTextStyles.caption,
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.navy),
                  onTap: () => Navigator.of(context).pop(app),
                )),
          ],
        ),
      ),
    );
  }

  String _statusAr(String? s) => switch (s) {
    'accepted' || 'final-admission' => 'مقبول',
    'visa-preparation' => 'قيد التحضير للتأشيرة',
    'completed' => 'مكتمل',
    'submitted' => 'قيد المراجعة',
    _ => 'جارٍ',
  };
}

// ── Form screen ───────────────────────────────────────────────────────────────

class _ArrivalFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Map<String, dynamic>? application; // only when creating new
  const _ArrivalFormScreen({this.existing, this.application});

  @override
  State<_ArrivalFormScreen> createState() => _ArrivalFormScreenState();
}

class _ArrivalFormScreenState extends State<_ArrivalFormScreen> {
  final _flightNumber = TextEditingController();
  final _airport = TextEditingController();
  final _arrivalTime = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _arrivalDate;

  bool _airportPickup = false;
  bool _studentHousing = false;
  bool _residencePermitSupport = false;
  bool _visaSupport = false;

  bool _saving = false;
  String? _saveError;

  bool get _isEditing => widget.existing != null;

  String get _programLabel {
    if (widget.application != null) {
      final prog = widget.application!['program'];
      return (prog is Map ? prog['title'] : null) as String? ?? 'البرنامج المختار';
    }
    if (widget.existing != null) {
      final app = widget.existing!['application'];
      if (app is Map) {
        final prog = app['program'];
        return (prog is Map ? prog['title'] : null) as String? ?? 'البرنامج الدراسي';
      }
    }
    return 'البرنامج الدراسي';
  }

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    if (d != null) {
      _flightNumber.text = d['flightNumber'] as String? ?? '';
      _airport.text = d['airport'] as String? ?? '';
      _arrivalTime.text = d['arrivalTime'] as String? ?? '';
      _notes.text = d['notes'] as String? ?? '';
      final services = d['services'] as Map<String, dynamic>? ?? {};
      _airportPickup = services['airportPickup'] == true;
      _studentHousing = services['studentHousing'] == true;
      _residencePermitSupport = services['residencePermitSupport'] == true;
      _visaSupport = services['visaSupport'] == true;
      final rawDate = d['arrivalDate'] as String?;
      if (rawDate != null) _arrivalDate = DateTime.tryParse(rawDate);
    }
  }

  @override
  void dispose() {
    _flightNumber.dispose();
    _airport.dispose();
    _arrivalTime.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _arrivalDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _arrivalDate = picked);
  }

  Future<void> _submit() async {
    setState(() { _saving = true; _saveError = null; });
    try {
      if (_isEditing) {
        await StudentRepository.instance.upsertArrivalServices(
          id: widget.existing!['_id'] as String?,
          arrivalDate: _arrivalDate?.toIso8601String(),
          arrivalTime: _arrivalTime.text.trim(),
          flightNumber: _flightNumber.text.trim(),
          airport: _airport.text.trim(),
          notes: _notes.text.trim(),
          airportPickup: _airportPickup,
          studentHousing: _studentHousing,
          residencePermitSupport: _residencePermitSupport,
          visaSupport: _visaSupport,
        );
      } else {
        final appId = widget.application!['_id'] as String;
        await StudentRepository.instance.createArrivalService(
          applicationId: appId,
          arrivalDate: _arrivalDate?.toIso8601String(),
          arrivalTime: _arrivalTime.text.trim(),
          flightNumber: _flightNumber.text.trim(),
          airport: _airport.text.trim(),
          notes: _notes.text.trim(),
          airportPickup: _airportPickup,
          studentHousing: _studentHousing,
          residencePermitSupport: _residencePermitSupport,
          visaSupport: _visaSupport,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing ? 'تم تحديث الطلب بنجاح' : 'تم إرسال طلبك بنجاح'),
        backgroundColor: AppColors.success,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = e is ApiException ? e.message : 'تعذر إرسال الطلب.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEditing ? 'تعديل رحلة الوصول' : 'رحلة وصول جديدة',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Journey badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.navy.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, size: 18, color: AppColors.navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _programLabel,
                      style: AppTextStyles.body.copyWith(color: AppColors.navy, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('معلومات الرحلة', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickDate,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تاريخ الوصول', style: AppTextStyles.caption),
                        Text(
                          _arrivalDate != null
                              ? '${_arrivalDate!.year}-${_arrivalDate!.month.toString().padLeft(2,'0')}-${_arrivalDate!.day.toString().padLeft(2,'0')}'
                              : 'اختر تاريخًا',
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                  _field('وقت الوصول', _arrivalTime),
                  const Divider(height: 20),
                  _field('رقم الرحلة', _flightNumber),
                  const Divider(height: 20),
                  _field('المطار', _airport),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('الخدمات المطلوبة', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  _svc('استقبال من المطار', _airportPickup, (v) => setState(() => _airportPickup = v)),
                  _svc('سكن طلابي', _studentHousing, (v) => setState(() => _studentHousing = v)),
                  _svc('دعم الإقامة (تصريح الإقامة)', _residencePermitSupport, (v) => setState(() => _residencePermitSupport = v)),
                  _svc('دعم التأشيرة', _visaSupport, (v) => setState(() => _visaSupport = v)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('ملاحظات إضافية', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _notes,
                maxLines: 3,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(_saveError!, style: const TextStyle(color: AppColors.warning, fontSize: 12.5)),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: _saving ? 'جاري الإرسال...' : (_isEditing ? 'حفظ التعديلات' : 'إرسال الطلب'),
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          SizedBox(
            width: 180,
            child: TextField(controller: controller, textAlign: TextAlign.right, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
          ),
        ],
      );

  Widget _svc(String label, bool value, ValueChanged<bool> onChanged) => Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Switch(value: value, activeThumbColor: AppColors.orange, onChanged: onChanged),
        ],
      );
}
