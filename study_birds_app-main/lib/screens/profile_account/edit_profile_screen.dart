import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/passport_scan.dart';
import 'passport_scanner_screen.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../core/student_repository.dart';
import '../../core/country_data.dart';
import '../../core/profile_field_data.dart';

enum ProfileSection { personal, academic, passport, study }

enum PickSource { camera, gallery }

Future<PickSource?> showPickSourceSheet(
  BuildContext context, {
  required String title,
  String cameraLabel = 'فتح الكاميرا',
  IconData cameraIcon = Icons.camera_alt_outlined,
}) {
  return showModalBottomSheet<PickSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title, style: AppTextStyles.cardTitle),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.navy,
              child: Icon(cameraIcon, color: Colors.white, size: 18),
            ),
            title: Text(cameraLabel),
            onTap: () => Navigator.pop(context, PickSource.camera),
          ),
          ListTile(
            leading: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.orange,
              child: Icon(Icons.folder_open_outlined,
                  color: Colors.white, size: 18),
            ),
            title: const Text('اختيار من الهاتف'),
            onTap: () => Navigator.pop(context, PickSource.gallery),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class EditProfileScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  final ProfileSection? section;
  const EditProfileScreen({super.key, this.onSaved, this.section});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _allLabels = <String, String>{
    'englishFullName': 'الاسم بالإنجليزية',
    'phone': 'رقم الهاتف',
    'nationality': 'الجنسية',
    'currentResidenceCountry': 'بلد الإقامة',
    'residenceRegion': 'المنطقة/المحافظة',
    'address': 'العنوان التفصيلي',
    'passportNumber': 'رقم جواز السفر',
    'dateOfBirth': 'تاريخ الميلاد',
    'currentEducation': 'الدراسة الحالية',
    'gpa': 'المعدل الدراسي',
    'intake': 'موعد بدء الدراسة',
    'bio': 'نبذة',
    'parentName': 'اسم ولي الأمر',
    'parentPhone': 'هاتف ولي الأمر',
    'parentRelationship': 'صلة القرابة',
    'parentRelCustom': 'صلة القرابة (أخرى)',
    'emergencyName': 'اسم جهة الطوارئ',
    'emergencyPhone': 'هاتف الطوارئ',
    'emergencyRelationship': 'صلة القرابة',
    'emergencyRelCustom': 'صلة القرابة (أخرى)',
    'nativeLanguage': 'اللغة الأم',
  };

  late final Map<String, TextEditingController> _controllers;
  final _form = GlobalKey<FormState>();
  Map<String, dynamic> _profile = {};
  String _level = '';
  bool _loading = true, _saving = false, _loaded = false;
  String? _error;

  // Phone country pickers
  Country _phoneCountry = kDefaultCountry;
  Country _parentPhoneCountry = kDefaultCountry;
  Country _emergencyPhoneCountry = kDefaultCountry;

  // Residence
  String _residenceIso2 = '';

  // Languages (other)
  List<String> _selectedOtherLanguages = [];

  // Target countries
  List<String> _selectedTargetCountries = [];

  // Relationships
  bool _parentRelCustom = false;
  bool _emergencyRelCustom = false;

  // Passport
  bool _passportUploading = false;
  bool _passportVerifying = false;
  Map<String, dynamic>? _passportDoc;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final key in _allLabels.keys) key: TextEditingController(),
    };
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await StudentRepository.instance.getProfile() ?? {};
      if (!mounted) return;
      _profile = data;
      _loaded = true;

      // Basic fields
      for (final key in ['englishFullName', 'nationality', 'address',
          'passportNumber', 'dateOfBirth', 'currentEducation', 'gpa',
          'intake', 'bio']) {
        final raw = data[key];
        _controllers[key]!.text = raw?.toString() ?? '';
      }
      final dob = DateTime.tryParse(_controllers['dateOfBirth']!.text);
      if (dob != null) {
        _controllers['dateOfBirth']!.text = dob.toIso8601String().split('T').first;
      }

      // Education level
      _level = data['currentEducationLevel']?.toString() ?? '';
      if (!['', 'high-school', 'bachelor', 'master', 'phd'].contains(_level)) {
        _level = '';
      }

      // Phone — parse country code
      final phone = data['phone']?.toString() ?? '';
      final parsedPhone = parseFullPhone(phone);
      if (parsedPhone != null) {
        _phoneCountry = parsedPhone.country;
        _controllers['phone']!.text = parsedPhone.local;
      } else {
        _controllers['phone']!.text = phone.replaceAll(RegExp(r'[^0-9]'), '');
      }

      // Residence country
      final countryName = data['currentResidenceCountry']?.toString() ?? '';
      _controllers['currentResidenceCountry']!.text = countryName;
      _controllers['residenceRegion']!.text =
          data['currentResidenceRegion']?.toString() ?? '';
      try {
        final c = kCountries.firstWhere((c) => c.nameAr == countryName);
        _residenceIso2 = c.iso2;
      } catch (_) {
        _residenceIso2 = '';
      }

      // Parent info
      final pi = data['parentInfo'] as Map? ?? {};
      _controllers['parentName']!.text = pi['name']?.toString() ?? '';
      final parentPhoneRaw = pi['phone']?.toString() ?? '';
      final parsedParent = parseFullPhone(parentPhoneRaw);
      if (parsedParent != null) {
        _parentPhoneCountry = parsedParent.country;
        _controllers['parentPhone']!.text = parsedParent.local;
      } else {
        _controllers['parentPhone']!.text =
            parentPhoneRaw.replaceAll(RegExp(r'[^0-9]'), '');
      }
      final parentRel = pi['relationship']?.toString() ?? '';
      if (parentRel.isNotEmpty && !kRelationshipOptions.contains(parentRel)) {
        _parentRelCustom = true;
        _controllers['parentRelationship']!.text = '';
        _controllers['parentRelCustom']!.text = parentRel;
      } else {
        _parentRelCustom = false;
        _controllers['parentRelationship']!.text = parentRel;
      }

      // Emergency contact
      final ec = data['emergencyContact'] as Map? ?? {};
      _controllers['emergencyName']!.text = ec['name']?.toString() ?? '';
      final emergPhoneRaw = ec['phone']?.toString() ?? '';
      final parsedEmerg = parseFullPhone(emergPhoneRaw);
      if (parsedEmerg != null) {
        _emergencyPhoneCountry = parsedEmerg.country;
        _controllers['emergencyPhone']!.text = parsedEmerg.local;
      } else {
        _controllers['emergencyPhone']!.text =
            emergPhoneRaw.replaceAll(RegExp(r'[^0-9]'), '');
      }
      final emergRel = ec['relationship']?.toString() ?? '';
      if (emergRel.isNotEmpty && !kRelationshipOptions.contains(emergRel)) {
        _emergencyRelCustom = true;
        _controllers['emergencyRelationship']!.text = '';
        _controllers['emergencyRelCustom']!.text = emergRel;
      } else {
        _emergencyRelCustom = false;
        _controllers['emergencyRelationship']!.text = emergRel;
      }

      // Native language
      _controllers['nativeLanguage']!.text =
          data['nativeLanguage']?.toString() ?? '';

      // Other languages
      final others = data['otherLanguages'];
      _selectedOtherLanguages =
          others is List ? others.map((e) => e.toString()).toList() : [];

      // Target countries
      final targets = data['targetCountries'];
      _selectedTargetCountries =
          targets is List ? targets.map((e) => e.toString()).toList() : [];

      if (widget.section == ProfileSection.passport) _loadPassportDoc();
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPassportDoc() async {
    try {
      final docs = await StudentRepository.instance.getDocuments();
      if (!mounted) return;
      final passports = docs
          .whereType<Map<String, dynamic>>()
          .where((d) => d['type'] == 'passport')
          .toList();
      if (passports.isNotEmpty) setState(() => _passportDoc = passports.last);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final next = Map<String, dynamic>.from(_profile);
      final section = widget.section;

      if (section == null || section == ProfileSection.personal) {
        next['englishFullName'] = _controllers['englishFullName']!.text.trim();

        // Phone — combine country code + local digits
        final localDigits =
            _controllers['phone']!.text.replaceAll(RegExp(r'[^0-9]'), '');
        next['phone'] = localDigits.isEmpty
            ? ''
            : '+${_phoneCountry.dialCode}$localDigits';

        next['nationality'] = _controllers['nationality']!.text.trim();
        next['currentResidenceCountry'] =
            _controllers['currentResidenceCountry']!.text.trim();
        next['currentResidenceRegion'] =
            _controllers['residenceRegion']!.text.trim();
        next['address'] = _controllers['address']!.text.trim();
        next['nativeLanguage'] = _controllers['nativeLanguage']!.text.trim();
        next['otherLanguages'] = _selectedOtherLanguages;

        // Parent phone
        final parentLocal =
            _controllers['parentPhone']!.text.replaceAll(RegExp(r'[^0-9]'), '');
        final parentRel = _parentRelCustom
            ? _controllers['parentRelCustom']!.text.trim()
            : _controllers['parentRelationship']!.text.trim();
        next['parentInfo'] = {
          'name': _controllers['parentName']!.text.trim(),
          'phone': parentLocal.isEmpty
              ? ''
              : '+${_parentPhoneCountry.dialCode}$parentLocal',
          'relationship': parentRel,
        };

        // Emergency phone
        final emergLocal = _controllers['emergencyPhone']!.text
            .replaceAll(RegExp(r'[^0-9]'), '');
        final emergRel = _emergencyRelCustom
            ? _controllers['emergencyRelCustom']!.text.trim()
            : _controllers['emergencyRelationship']!.text.trim();
        next['emergencyContact'] = {
          'name': _controllers['emergencyName']!.text.trim(),
          'phone': emergLocal.isEmpty
              ? ''
              : '+${_emergencyPhoneCountry.dialCode}$emergLocal',
          'relationship': emergRel,
        };
      }
      if (section == null || section == ProfileSection.passport) {
        next['passportNumber'] = _controllers['passportNumber']!.text.trim();
        final dob = _controllers['dateOfBirth']!.text.trim();
        next['dateOfBirth'] = dob.isEmpty ? null : dob;
      }
      if (section == null || section == ProfileSection.academic) {
        next['currentEducationLevel'] = _level;
        next['currentEducation'] = _controllers['currentEducation']!.text.trim();
        next['gpa'] = _controllers['gpa']!.text.trim();
      }
      if (section == null || section == ProfileSection.study) {
        next['targetCountries'] = _selectedTargetCountries;
        next['intake'] = _controllers['intake']!.text.trim();
        next['bio'] = _controllers['bio']!.text.trim();
      }

      await StudentRepository.instance.updateProfile(next);
      if (!mounted) return;
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final stored = DateTime.tryParse(_controllers['dateOfBirth']!.text);
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: today,
      initialDate:
          stored != null && !stored.isAfter(today) && stored.year >= 1900
              ? stored
              : DateTime(today.year - 18),
      helpText: 'تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (value != null && mounted) {
      setState(() => _controllers['dateOfBirth']!.text =
          value.toIso8601String().split('T').first);
    }
  }

  Future<void> _pickAndUploadPassport() async {
    final choice = await showPickSourceSheet(
      context,
      title: 'رفع جواز السفر',
      cameraLabel: 'مسح ضوئي للجواز',
      cameraIcon: Icons.document_scanner_rounded,
    );
    if (choice == null || !mounted) return;

    Uint8List? bytes;
    String? fileName;

    if (choice == PickSource.camera) {
      final xFile = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => const PassportScannerScreen()),
      );
      if (xFile == null || !mounted) return;
      bytes = await xFile.readAsBytes();
      fileName = 'passport_${DateTime.now().millisecondsSinceEpoch}.jpg';
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر قراءة الملف')));
        }
        return;
      }
      bytes = file.bytes!;
      fileName = file.name;
    }

    if (!mounted) return;
    if (bytes.length > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حجم الملف كبير جدًا (الحد 10 ميجابايت)')));
      return;
    }

    // OCR validation
    setState(() => _passportVerifying = true);
    try {
      await PassportScan.validate(bytes);
    } on PassportScanException catch (e) {
      if (!mounted) return;
      setState(() => _passportVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 5)));
      return;
    } catch (_) {
      // Unexpected error — allow upload
    } finally {
      if (mounted) setState(() => _passportVerifying = false);
    }

    if (!mounted) return;

    // Auto-fill passport data from MRZ before uploading
    final extracted = await PassportScan.extractFromBytes(bytes);
    if (mounted) {
      setState(() {
        if (extracted.passportNumber != null) {
          _controllers['passportNumber']!.text = extracted.passportNumber!;
        }
        if (extracted.dateOfBirth != null) {
          _controllers['dateOfBirth']!.text = extracted.dateOfBirth!;
        }
      });
    }

    setState(() => _passportUploading = true);
    try {
      final doc = await StudentRepository.instance.uploadDocument(
        fileBytes: bytes,
        fileName: fileName,
        type: 'passport',
      );
      if (mounted) {
        setState(() => _passportDoc = doc);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extracted.passportNumber != null
              ? 'تم رفع الجواز واستخراج البيانات تلقائيًا ✓'
              : 'تم رفع جواز السفر بنجاح ✓'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر رفع الجواز: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _passportUploading = false);
    }
  }

  // ─── Field helpers ──────────────────────────────────────────────────────────

  Widget _field(String key) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: TextFormField(
          controller: _controllers[key],
          enabled: !_saving,
          readOnly: key == 'dateOfBirth',
          onTap: key == 'dateOfBirth' ? _pickBirthDate : null,
          textDirection:
              ['englishFullName', 'passportNumber', 'gpa', 'dateOfBirth']
                      .contains(key)
                  ? TextDirection.ltr
                  : null,
          keyboardType: key == 'gpa'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: key == 'gpa'
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : null,
          minLines: key == 'bio' ? 3 : 1,
          maxLines: key == 'bio' ? 5 : 1,
          decoration: featureInput(
            _allLabels[key]!,
            hint: key == 'gpa' ? 'مثال: 85 أو 3.7' : null,
            suffix: key == 'dateOfBirth'
                ? const Icon(Icons.calendar_today_outlined, size: 20)
                : null,
          ),
          validator: (v) {
            if (key == 'dateOfBirth' && v != null && v.trim().isNotEmpty) {
              final d = DateTime.tryParse(v.trim());
              return d == null || d.isAfter(DateTime.now())
                  ? 'أدخل تاريخ ميلاد صحيحًا'
                  : null;
            }
            return null;
          },
        ),
      );

  // Phone row: country picker + digits-only field
  Widget _phoneRow(
    String localKey,
    Country country,
    VoidCallback onPickCountry,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_allLabels[localKey]!, style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _saving ? null : onPickCountry,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(country.flag,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 6),
                        Text('+${country.dialCode}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.navy)),
                        const SizedBox(width: 2),
                        if (!_saving)
                          Icon(Icons.expand_more_rounded,
                              size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _controllers[localKey],
                    enabled: !_saving,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '5xxxxxxxx',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 17),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.navy, width: 1.5)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  // Tappable read-only field (for pickers)
  // ValueKey forces a new TextFormField when value changes so initialValue
  // reflects the latest state after setState.
  Widget _tapField(
    String label,
    String value,
    VoidCallback? onTap, {
    Widget? trailing,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: GestureDetector(
          onTap: _saving ? null : onTap,
          child: AbsorbPointer(
            child: TextFormField(
              key: ValueKey('$label::$value'),
              readOnly: true,
              initialValue: value,
              decoration: featureInput(
                label,
                suffix: trailing ??
                    Icon(Icons.arrow_drop_down_rounded,
                        size: 24, color: Colors.grey.shade500),
              ),
            ),
          ),
        ),
      );

  // Relationship dropdown + optional custom text
  Widget _relationshipSection({
    required String dropdownKey,
    required String customKey,
    required bool isCustom,
    required void Function(bool) onCustomChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: DropdownButtonFormField<String>(
              value: isCustom
                  ? 'أخرى'
                  : (_controllers[dropdownKey]!.text.isEmpty
                      ? null
                      : _controllers[dropdownKey]!.text),
              hint: const Text('اختر صلة القرابة'),
              decoration: featureInput(_allLabels[dropdownKey]!),
              isExpanded: true,
              items: [
                ...kRelationshipOptions.map((r) =>
                    DropdownMenuItem(value: r, child: Text(r))),
                const DropdownMenuItem(value: 'أخرى', child: Text('أخرى...')),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v == 'أخرى') {
                        setState(() {
                          onCustomChanged(true);
                          _controllers[dropdownKey]!.text = '';
                        });
                      } else {
                        setState(() {
                          onCustomChanged(false);
                          _controllers[dropdownKey]!.text = v ?? '';
                        });
                      }
                    },
            ),
          ),
          if (isCustom) _field(customKey),
        ],
      );

  // Chips row for multi-select lists
  Widget _chipsRow(
    String label,
    List<String> items,
    Future<String?> Function() onAddTap,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ...items.map((item) => Chip(
                      label: Text(item, style: const TextStyle(fontSize: 13)),
                      backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                      side: BorderSide.none,
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: _saving
                          ? null
                          : () => setState(() => items.remove(item)),
                    )),
                if (!_saving)
                  ActionChip(
                    label: const Text('+ إضافة'),
                    backgroundColor: AppColors.orangeSoft,
                    side: BorderSide.none,
                    onPressed: () async {
                      final picked = await onAddTap();
                      if (picked != null && !items.contains(picked) && mounted) {
                        setState(() => items.add(picked));
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      );

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final title = section == ProfileSection.personal
        ? 'المعلومات الشخصية'
        : section == ProfileSection.academic
            ? 'المعلومات الأكاديمية'
            : section == ProfileSection.passport
                ? 'جواز السفر'
                : section == ProfileSection.study
                    ? 'تفضيلات الدراسة'
                    : 'الملف الشخصي';

    return AppScaffold(
      title: title,
      bottomBar: !_loaded
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                color: Colors.white,
                child: PrimaryButton(
                  label: _saving ? 'جاري الحفظ...' : 'حفظ البيانات',
                  icon: Icons.check_rounded,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
      body: _loading
          ? const LoadingState()
          : _error != null && !_loaded
              ? ErrorState(message: _error!, onRetry: _load)
              : Form(
                  key: _form,
                  child: FeatureBody(children: [
                    if (_error != null) InlineNotice(_error!, error: true),

                    // ─── المعلومات الشخصية ──────────────────────────────────
                    if (section == null ||
                        section == ProfileSection.personal) ...[
                      FeaturePanel(
                        title: 'المعلومات الشخصية',
                        subtitle: 'اكتب الاسم كما يظهر في وثائقك الرسمية.',
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _field('englishFullName'),

                              // Phone with country code picker
                              _phoneRow('phone', _phoneCountry, () async {
                                final picked = await showCountryPicker(context);
                                if (picked != null && mounted) {
                                  setState(() {
                                    _phoneCountry = picked;
                                    // Auto-fill nationality from chosen country
                                    final nat =
                                        kNationalityByIso2[picked.iso2];
                                    if (nat != null &&
                                        _controllers['nationality']!
                                            .text
                                            .isEmpty) {
                                      _controllers['nationality']!.text = nat;
                                    }
                                  });
                                }
                              }),

                              // Nationality — auto-filled but editable
                              _field('nationality'),

                              // Residence country — editable + flag prefix + picker icon
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: TextFormField(
                                  controller: _controllers[
                                      'currentResidenceCountry'],
                                  enabled: !_saving,
                                  decoration: featureInput(
                                    'بلد الإقامة',
                                    suffix: IconButton(
                                      icon: Icon(
                                          Icons.arrow_drop_down_rounded,
                                          size: 24,
                                          color: Colors.grey.shade500),
                                      onPressed: _saving
                                          ? null
                                          : () async {
                                              final picked =
                                                  await showCountryPicker(
                                                      context);
                                              if (picked != null && mounted) {
                                                setState(() {
                                                  _controllers[
                                                          'currentResidenceCountry']!
                                                      .text = picked.nameAr;
                                                  _residenceIso2 = picked.iso2;
                                                  _controllers[
                                                          'residenceRegion']!
                                                      .text = '';
                                                });
                                              }
                                            },
                                    ),
                                  ).copyWith(
                                    prefixIcon: _residenceIso2.isEmpty
                                        ? null
                                        : Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text(
                                              countryByIso2(_residenceIso2)
                                                      ?.flag ??
                                                  '',
                                              style: const TextStyle(
                                                  fontSize: 24),
                                            ),
                                          ),
                                  ),
                                  onChanged: (_) {
                                    // Manual typing clears iso2 so flag + regions hide
                                    if (_residenceIso2.isNotEmpty) {
                                      setState(() => _residenceIso2 = '');
                                    }
                                  },
                                ),
                              ),

                              // Region — picker if known regions exist, else free text
                              if (_residenceIso2.isNotEmpty &&
                                  (kRegionsByIso2[_residenceIso2]?.isNotEmpty ??
                                      false))
                                _tapField(
                                  'المنطقة/المحافظة',
                                  _controllers['residenceRegion']!.text,
                                  () async {
                                    final picked = await showRegionPicker(
                                        context, _residenceIso2);
                                    if (picked != null && mounted) {
                                      setState(() => _controllers[
                                          'residenceRegion']!.text = picked);
                                    }
                                  },
                                )
                              else
                                _field('residenceRegion'),

                              _field('address'),
                            ]),
                      ),

                      // Languages
                      FeaturePanel(
                        title: 'اللغات',
                        subtitle: 'يساعدنا هذا في اختيار المستشار المناسب.',
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Native language — single picker
                              _tapField(
                                'اللغة الأم',
                                _controllers['nativeLanguage']!.text,
                                () async {
                                  final picked = await showLanguagePicker(
                                      context,
                                      current: _controllers['nativeLanguage']!
                                          .text);
                                  if (picked != null && mounted) {
                                    setState(() =>
                                        _controllers['nativeLanguage']!.text =
                                            picked);
                                  }
                                },
                              ),
                              // Other languages — chips
                              _chipsRow(
                                'لغات أخرى',
                                _selectedOtherLanguages,
                                () => showLanguagePicker(context),
                              ),
                            ]),
                      ),

                      // Parent info
                      FeaturePanel(
                        title: 'ولي الأمر',
                        subtitle: 'للتواصل في حالات الضرورة.',
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _field('parentName'),
                              _phoneRow('parentPhone', _parentPhoneCountry,
                                  () async {
                                final picked = await showCountryPicker(context);
                                if (picked != null && mounted) {
                                  setState(() => _parentPhoneCountry = picked);
                                }
                              }),
                              _relationshipSection(
                                dropdownKey: 'parentRelationship',
                                customKey: 'parentRelCustom',
                                isCustom: _parentRelCustom,
                                onCustomChanged: (v) =>
                                    _parentRelCustom = v,
                              ),
                            ]),
                      ),

                      // Emergency contact
                      FeaturePanel(
                        title: 'جهة الاتصال الطارئة',
                        subtitle: 'شخص يمكن التواصل معه في حالات الطوارئ.',
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _field('emergencyName'),
                              _phoneRow(
                                  'emergencyPhone', _emergencyPhoneCountry,
                                  () async {
                                final picked = await showCountryPicker(context);
                                if (picked != null && mounted) {
                                  setState(
                                      () => _emergencyPhoneCountry = picked);
                                }
                              }),
                              _relationshipSection(
                                dropdownKey: 'emergencyRelationship',
                                customKey: 'emergencyRelCustom',
                                isCustom: _emergencyRelCustom,
                                onCustomChanged: (v) =>
                                    _emergencyRelCustom = v,
                              ),
                            ]),
                      ),
                    ],

                    // ─── جواز السفر ────────────────────────────────────────
                    if (section == null || section == ProfileSection.passport)
                      FeaturePanel(
                        title: 'جواز السفر',
                        subtitle:
                            'بيانات الجواز تُستخدم في تقديم الطلبات. يتم استخراجها تلقائيًا عند المسح.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field('passportNumber'),
                            _field('dateOfBirth'),
                            const SizedBox(height: 12),
                            _PassportUploadTile(
                              doc: _passportDoc,
                              verifying: _passportVerifying,
                              uploading: _passportUploading,
                              onUpload: _pickAndUploadPassport,
                            ),
                          ],
                        ),
                      ),

                    // ─── المعلومات الأكاديمية ───────────────────────────────
                    if (section == null || section == ProfileSection.academic)
                      FeaturePanel(
                        title: 'المعلومات الأكاديمية',
                        child: Column(children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey('level:$_level'),
                            initialValue: _level,
                            decoration: featureInput('المستوى الدراسي'),
                            items: const [
                              DropdownMenuItem(
                                  value: '', child: Text('غير محدد')),
                              DropdownMenuItem(
                                  value: 'high-school', child: Text('ثانوي')),
                              DropdownMenuItem(
                                  value: 'bachelor',
                                  child: Text('بكالوريوس')),
                              DropdownMenuItem(
                                  value: 'master',
                                  child: Text('ماجستير')),
                              DropdownMenuItem(
                                  value: 'phd', child: Text('دكتوراه')),
                            ],
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _level = v!),
                          ),
                          const SizedBox(height: 18),
                          _field('currentEducation'),
                          // GPA — numbers only
                          _field('gpa'),
                        ]),
                      ),

                    // ─── تفضيلات الدراسة ────────────────────────────────────
                    if (section == null || section == ProfileSection.study)
                      FeaturePanel(
                        title: 'تفضيلات الدراسة',
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Target countries — restricted to available
                              _chipsRow(
                                'الدول المستهدفة',
                                _selectedTargetCountries,
                                () => showTargetCountryPicker(context),
                              ),
                              _field('intake'),
                              _field('bio'),
                            ]),
                      ),
                  ]),
                ),
    );
  }
}

// ─── Passport upload tile ─────────────────────────────────────────────────────
class _PassportUploadTile extends StatelessWidget {
  final Map<String, dynamic>? doc;
  final bool verifying;
  final bool uploading;
  final VoidCallback onUpload;
  const _PassportUploadTile({
    required this.doc,
    required this.verifying,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    if (verifying) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          CircularProgressIndicator(color: AppColors.orange),
          SizedBox(height: 12),
          Text('جارٍ المسح الضوئي والتحقق من الجواز...',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }
    if (uploading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('جارٍ رفع الجواز...', textAlign: TextAlign.center),
        ]),
      );
    }
    final hasDoc = doc != null;
    final status = doc?['status'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasDoc) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(children: [
              const Icon(Icons.description_outlined,
                  color: AppColors.navy, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('صورة الجواز مرفوعة',
                      style: AppTextStyles.cardTitle)),
              _StatusBadge(status),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(hasDoc ? 'فحص ورفع جواز بديل' : 'مسح وفحص جواز السفر'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            side: const BorderSide(color: AppColors.navy),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
      case 'verified':
        color = AppColors.success;
        label = 'موافق عليه';
        break;
      case 'rejected':
        color = AppColors.danger;
        label = 'مرفوض';
        break;
      case 'needs-revision':
        color = AppColors.warning;
        label = 'يحتاج تعديل';
        break;
      default:
        color = AppColors.info;
        label = 'قيد المراجعة';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
