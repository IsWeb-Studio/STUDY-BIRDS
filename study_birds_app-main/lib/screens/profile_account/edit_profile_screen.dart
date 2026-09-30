import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../core/student_repository.dart';

enum ProfileSection { personal, academic, passport, study }

enum PickSource { camera, gallery }

Future<PickSource?> showPickSourceSheet(
  BuildContext context, {
  required String title,
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
            leading: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.navy,
              child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
            ),
            title: const Text('فتح الكاميرا'),
            onTap: () => Navigator.pop(context, PickSource.camera),
          ),
          ListTile(
            leading: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.orange,
              child: Icon(Icons.folder_open_outlined, color: Colors.white, size: 18),
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
    'address': 'العنوان',
    'passportNumber': 'رقم جواز السفر',
    'dateOfBirth': 'تاريخ الميلاد',
    'currentEducation': 'الدراسة الحالية',
    'gpa': 'المعدل الدراسي',
    'targetCountries': 'الدول المستهدفة (افصل بفاصلة)',
    'intake': 'موعد بدء الدراسة',
    'bio': 'نبذة',
    'parentName': 'اسم ولي الأمر',
    'parentPhone': 'هاتف ولي الأمر',
    'parentRelationship': 'صلة القرابة',
    'emergencyName': 'اسم جهة الطوارئ',
    'emergencyPhone': 'هاتف الطوارئ',
    'emergencyRelationship': 'صلة القرابة',
    'nativeLanguage': 'اللغة الأم',
    'otherLanguages': 'لغات أخرى (افصل بفاصلة)',
  };

  late final Map<String, TextEditingController> _controllers;
  final _form = GlobalKey<FormState>();
  Map<String, dynamic> _profile = {};
  String _level = '';
  bool _loading = true, _saving = false, _loaded = false;
  String? _error;

  bool _passportUploading = false;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StudentRepository.instance.getProfile() ?? {};
      if (!mounted) return;
      _profile = data;
      _loaded = true;

      for (final key in ['englishFullName', 'phone', 'nationality', 'currentResidenceCountry', 'address', 'passportNumber', 'dateOfBirth', 'currentEducation', 'gpa', 'targetCountries', 'intake', 'bio']) {
        final raw = data[key];
        _controllers[key]!.text = raw is List ? raw.join('، ') : raw?.toString() ?? '';
      }
      final dob = DateTime.tryParse(_controllers['dateOfBirth']!.text);
      if (dob != null) {
        _controllers['dateOfBirth']!.text = dob.toIso8601String().split('T').first;
      }

      _level = data['currentEducationLevel']?.toString() ?? '';
      if (!['', 'high-school', 'bachelor', 'master', 'phd'].contains(_level)) {
        _level = '';
      }

      final pi = data['parentInfo'] as Map? ?? {};
      _controllers['parentName']!.text = pi['name']?.toString() ?? '';
      _controllers['parentPhone']!.text = pi['phone']?.toString() ?? '';
      _controllers['parentRelationship']!.text = pi['relationship']?.toString() ?? '';

      final ec = data['emergencyContact'] as Map? ?? {};
      _controllers['emergencyName']!.text = ec['name']?.toString() ?? '';
      _controllers['emergencyPhone']!.text = ec['phone']?.toString() ?? '';
      _controllers['emergencyRelationship']!.text = ec['relationship']?.toString() ?? '';

      _controllers['nativeLanguage']!.text = data['nativeLanguage']?.toString() ?? '';
      final others = data['otherLanguages'];
      _controllers['otherLanguages']!.text = others is List ? others.join('، ') : '';

      if (widget.section == ProfileSection.passport) {
        _loadPassportDoc();
      }
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
      if (passports.isNotEmpty) {
        setState(() => _passportDoc = passports.last);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final next = Map<String, dynamic>.from(_profile);
      final section = widget.section;

      if (section == null || section == ProfileSection.personal) {
        next['englishFullName'] = _controllers['englishFullName']!.text.trim();
        next['phone'] = _controllers['phone']!.text.trim();
        next['nationality'] = _controllers['nationality']!.text.trim();
        next['currentResidenceCountry'] = _controllers['currentResidenceCountry']!.text.trim();
        next['address'] = _controllers['address']!.text.trim();
        next['nativeLanguage'] = _controllers['nativeLanguage']!.text.trim();
        next['otherLanguages'] = _controllers['otherLanguages']!.text
            .split(RegExp('[,،]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        next['parentInfo'] = {
          'name': _controllers['parentName']!.text.trim(),
          'phone': _controllers['parentPhone']!.text.trim(),
          'relationship': _controllers['parentRelationship']!.text.trim(),
        };
        next['emergencyContact'] = {
          'name': _controllers['emergencyName']!.text.trim(),
          'phone': _controllers['emergencyPhone']!.text.trim(),
          'relationship': _controllers['emergencyRelationship']!.text.trim(),
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
        next['targetCountries'] = _controllers['targetCountries']!.text
            .split(RegExp('[,،]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
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
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final stored = DateTime.tryParse(_controllers['dateOfBirth']!.text);
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: today,
      initialDate: stored != null && !stored.isAfter(today) && stored.year >= 1900
          ? stored
          : DateTime(today.year - 18),
      helpText: 'تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (value != null && mounted) {
      setState(() => _controllers['dateOfBirth']!.text = value.toIso8601String().split('T').first);
    }
  }

  Future<void> _pickAndUploadPassport() async {
    final choice = await showPickSourceSheet(context, title: 'رفع جواز السفر');
    if (choice == null || !mounted) return;

    Uint8List? bytes;
    String? fileName;

    if (choice == PickSource.camera) {
      final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
      if (img == null) return;
      bytes = await img.readAsBytes();
      fileName = img.name;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر قراءة الملف')));
        return;
      }
      bytes = file.bytes!;
      fileName = file.name;
    }

    if (!mounted) return;
    if (bytes.length > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حجم الملف كبير جدًا (الحد 10 ميجابايت)')));
      return;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع جواز السفر بنجاح ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر رفع الجواز: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _passportUploading = false);
    }
  }

  Widget _field(String key) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: TextFormField(
          controller: _controllers[key],
          enabled: !_saving,
          readOnly: key == 'dateOfBirth',
          onTap: key == 'dateOfBirth' ? _pickBirthDate : null,
          textDirection: ['englishFullName', 'passportNumber', 'phone', 'gpa', 'dateOfBirth'].contains(key)
              ? TextDirection.ltr
              : null,
          keyboardType: key == 'phone'
              ? TextInputType.phone
              : key == 'gpa'
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
          minLines: key == 'bio' ? 3 : 1,
          maxLines: key == 'bio' ? 5 : 1,
          decoration: featureInput(
            _allLabels[key]!,
            hint: key == 'targetCountries' ? 'مثال: تركيا، ألمانيا' : null,
            suffix: key == 'dateOfBirth'
                ? const Icon(Icons.calendar_today_outlined, size: 20)
                : null,
          ),
          validator: (v) {
            if (key == 'dateOfBirth' && v != null && v.trim().isNotEmpty) {
              final d = DateTime.tryParse(v.trim());
              return d == null || d.isAfter(DateTime.now()) ? 'أدخل تاريخ ميلاد صحيحًا' : null;
            }
            return null;
          },
        ),
      );

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

                    // --- المعلومات الشخصية ---
                    if (section == null || section == ProfileSection.personal) ...[
                      FeaturePanel(
                        title: 'المعلومات الشخصية',
                        subtitle: 'اكتب الاسم كما يظهر في وثائقك الرسمية.',
                        child: Column(children: [
                          _field('englishFullName'),
                          _field('phone'),
                          _field('nationality'),
                          _field('currentResidenceCountry'),
                          _field('address'),
                        ]),
                      ),
                      FeaturePanel(
                        title: 'اللغات',
                        subtitle: 'يساعدنا هذا في اختيار المستشار المناسب.',
                        child: Column(children: [
                          _field('nativeLanguage'),
                          _field('otherLanguages'),
                        ]),
                      ),
                      FeaturePanel(
                        title: 'ولي الأمر',
                        subtitle: 'للتواصل في حالات الضرورة.',
                        child: Column(children: [
                          _field('parentName'),
                          _field('parentPhone'),
                          _field('parentRelationship'),
                        ]),
                      ),
                      FeaturePanel(
                        title: 'جهة الاتصال الطارئة',
                        subtitle: 'شخص يمكن التواصل معه في حالات الطوارئ.',
                        child: Column(children: [
                          _field('emergencyName'),
                          _field('emergencyPhone'),
                          _field('emergencyRelationship'),
                        ]),
                      ),
                    ],

                    // --- جواز السفر ---
                    if (section == null || section == ProfileSection.passport)
                      FeaturePanel(
                        title: 'جواز السفر',
                        subtitle: 'بيانات الجواز تُستخدم في تقديم الطلبات.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field('passportNumber'),
                            _field('dateOfBirth'),
                            const SizedBox(height: 12),
                            _PassportUploadTile(
                              doc: _passportDoc,
                              uploading: _passportUploading,
                              onUpload: _pickAndUploadPassport,
                            ),
                          ],
                        ),
                      ),

                    // --- المعلومات الأكاديمية ---
                    if (section == null || section == ProfileSection.academic)
                      FeaturePanel(
                        title: 'المعلومات الأكاديمية',
                        child: Column(children: [
                          DropdownButtonFormField<String>(
                            initialValue: _level,
                            decoration: featureInput('المستوى الدراسي'),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('غير محدد')),
                              DropdownMenuItem(value: 'high-school', child: Text('ثانوي')),
                              DropdownMenuItem(value: 'bachelor', child: Text('بكالوريوس')),
                              DropdownMenuItem(value: 'master', child: Text('ماجستير')),
                              DropdownMenuItem(value: 'phd', child: Text('دكتوراه')),
                            ],
                            onChanged: _saving ? null : (v) => setState(() => _level = v!),
                          ),
                          const SizedBox(height: 18),
                          _field('currentEducation'),
                          _field('gpa'),
                        ]),
                      ),

                    // --- تفضيلات الدراسة ---
                    if (section == null || section == ProfileSection.study)
                      FeaturePanel(
                        title: 'تفضيلات الدراسة',
                        child: Column(children: [
                          _field('targetCountries'),
                          _field('intake'),
                          _field('bio'),
                        ]),
                      ),
                  ]),
                ),
    );
  }
}

class _PassportUploadTile extends StatelessWidget {
  final Map<String, dynamic>? doc;
  final bool uploading;
  final VoidCallback onUpload;
  const _PassportUploadTile({
    required this.doc,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
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
              color: AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(children: [
              const Icon(Icons.description_outlined, color: AppColors.navy, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('صورة الجواز مرفوعة', style: AppTextStyles.cardTitle)),
              _StatusBadge(status),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(hasDoc ? 'استبدال صورة الجواز' : 'رفع صورة الجواز'),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
