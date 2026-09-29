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

  void _openForm({Map<String, dynamic>? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ArrivalFormScreen(existing: existing)),
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
              onPressed: () => _openForm(),
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
            onCta: () => _openForm(),
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
        return AppCard(
          onTap: () => _openForm(existing: req),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      req['flightNumber'] as String? ?? 'رحلة جوية',
                      style: AppTextStyles.cardTitle,
                      overflow: TextOverflow.ellipsis,
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

class _ArrivalFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ArrivalFormScreen({this.existing});

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
        await StudentRepository.instance.createArrivalService(
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
      title: _isEditing ? 'تعديل الرحلة' : 'رحلة جديدة',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          Switch(value: value, activeColor: AppColors.orange, onChanged: onChanged),
        ],
      );
}
