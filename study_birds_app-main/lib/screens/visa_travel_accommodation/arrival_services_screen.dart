import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/student_repository.dart';

/// Real feature — replaces the previously-separate Travel Center / Airport
/// Pickup mock screens with the ONE consolidated request the backend
/// actually supports (server/src/models/ArrivalServiceRequest.js). The
/// backend only accepts this once the student reaches final-accepted /
/// travel-and-settlement — that rule is enforced server-side and surfaced
/// here via the real error message, not guessed client-side.
class ArrivalServicesScreen extends StatefulWidget {
  const ArrivalServicesScreen({super.key});

  @override
  State<ArrivalServicesScreen> createState() => _ArrivalServicesScreenState();
}

class _ArrivalServicesScreenState extends State<ArrivalServicesScreen> {
  bool _loading = true;
  String? _loadError;
  Map<String, dynamic>? _existing;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _flightNumber.dispose();
    _airport.dispose();
    _arrivalTime.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await StudentRepository.instance.getArrivalServices();
      if (!mounted) return;
      if (data != null) {
        _existing = data;
        _flightNumber.text = data['flightNumber'] as String? ?? '';
        _airport.text = data['airport'] as String? ?? '';
        _arrivalTime.text = data['arrivalTime'] as String? ?? '';
        _notes.text = data['notes'] as String? ?? '';
        final services = data['services'] as Map<String, dynamic>? ?? {};
        _airportPickup = services['airportPickup'] == true;
        _studentHousing = services['studentHousing'] == true;
        _residencePermitSupport = services['residencePermitSupport'] == true;
        _visaSupport = services['visaSupport'] == true;
        final rawDate = data['arrivalDate'] as String?;
        if (rawDate != null) _arrivalDate = DateTime.tryParse(rawDate);
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is ApiException ? e.message : 'تعذر تحميل بياناتك.';
        _loading = false;
      });
    }
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
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final updated = await StudentRepository.instance.upsertArrivalServices(
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
      if (!mounted) return;
      setState(() => _existing = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلبك بنجاح'), backgroundColor: AppColors.success));
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
      title: 'خدمات الوصول',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري التحميل...')
            : _loadError != null
                ? ErrorState(message: _loadError!, onRetry: _load)
                : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_existing != null) ...[
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('حالة الطلب: ${_existing!['status'] ?? 'submitted'}', style: AppTextStyles.body)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
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
                      Text(_arrivalDate != null ? '${_arrivalDate!.year}-${_arrivalDate!.month}-${_arrivalDate!.day}' : 'اختر تاريخًا', style: AppTextStyles.body),
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
                _serviceSwitch('استقبال من المطار', _airportPickup, (v) => setState(() => _airportPickup = v)),
                _serviceSwitch('سكن طلابي', _studentHousing, (v) => setState(() => _studentHousing = v)),
                _serviceSwitch('دعم الإقامة (تصريح الإقامة)', _residencePermitSupport, (v) => setState(() => _residencePermitSupport = v)),
                _serviceSwitch('دعم التأشيرة', _visaSupport, (v) => setState(() => _visaSupport = v)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('ملاحظات إضافية', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.button), border: Border.all(color: AppColors.border)),
            child: TextField(controller: _notes, maxLines: 3, textAlign: TextAlign.right, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12))),
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
          PrimaryButton(label: _saving ? 'جاري الإرسال...' : 'إرسال الطلب', onPressed: _saving ? null : _submit),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        SizedBox(
          width: 180,
          child: TextField(controller: controller, textAlign: TextAlign.right, decoration: const InputDecoration(border: InputBorder.none, isDense: true)),
        ),
      ],
    );
  }

  Widget _serviceSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.body)),
        Switch(value: value, activeColor: AppColors.orange, onChanged: onChanged),
      ],
    );
  }
}
