import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../core/student_repository.dart';

class EditProfileScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const EditProfileScreen({super.key, this.onSaved});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const fields = {
    'englishFullName': 'الاسم بالإنجليزية',
    'phone': 'رقم الهاتف',
    'nationality': 'الجنسية',
    'currentResidenceCountry': 'بلد الإقامة',
    'passportNumber': 'رقم جواز السفر',
    'dateOfBirth': 'تاريخ الميلاد (YYYY-MM-DD)',
    'currentEducation': 'الدراسة الحالية',
    'gpa': 'المعدل الدراسي',
    'targetCountries': 'الدول المستهدفة (افصل بفاصلة)',
    'intake': 'موعد بدء الدراسة',
    'address': 'العنوان',
    'bio': 'نبذة',
  };
  // حقول بند 8
  static const parentFields = {
    'parentName': 'اسم ولي الأمر',
    'parentPhone': 'هاتف ولي الأمر',
    'parentRelationship': 'صلة القرابة',
  };
  static const emergencyFields = {
    'emergencyName': 'اسم جهة الطوارئ',
    'emergencyPhone': 'هاتف الطوارئ',
    'emergencyRelationship': 'صلة القرابة',
  };
  static const langFields = {
    'nativeLanguage': 'اللغة الأم',
    'otherLanguages': 'لغات أخرى (افصل بفاصلة)',
  };

  final controllers = {
    for (final key in fields.keys) key: TextEditingController(),
    for (final key in parentFields.keys) key: TextEditingController(),
    for (final key in emergencyFields.keys) key: TextEditingController(),
    for (final key in langFields.keys) key: TextEditingController(),
  };
  final form = GlobalKey<FormState>();
  Map<String, dynamic> profile = {};
  String level = '';
  bool loading = true, saving = false, loaded = false;
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
      final value = await StudentRepository.instance.getProfile() ?? {};
      if (!mounted) return;
      profile = value;
      loaded = true;
      for (final key in fields.keys) {
        final raw = value[key];
        controllers[key]!.text =
            raw is List ? raw.join('، ') : raw?.toString() ?? '';
      }
      final dob = DateTime.tryParse(controllers['dateOfBirth']!.text);
      if (dob != null) {
        controllers['dateOfBirth']!.text =
            dob.toIso8601String().split('T').first;
      }
      level = value['currentEducationLevel']?.toString() ?? '';
      if (!['', 'high-school', 'bachelor', 'master', 'phd'].contains(level)) {
        level = '';
      }
      // بند 8: ولي الأمر وجهة الطوارئ واللغات
      final pi = value['parentInfo'] as Map? ?? {};
      controllers['parentName']!.text = '${pi['name'] ?? ''}';
      controllers['parentPhone']!.text = '${pi['phone'] ?? ''}';
      controllers['parentRelationship']!.text = '${pi['relationship'] ?? ''}';
      final ec = value['emergencyContact'] as Map? ?? {};
      controllers['emergencyName']!.text = '${ec['name'] ?? ''}';
      controllers['emergencyPhone']!.text = '${ec['phone'] ?? ''}';
      controllers['emergencyRelationship']!.text = '${ec['relationship'] ?? ''}';
      controllers['nativeLanguage']!.text = '${value['nativeLanguage'] ?? ''}';
      final others = value['otherLanguages'];
      controllers['otherLanguages']!.text =
          others is List ? others.join('، ') : '';
    } catch (e) {
      if (mounted) error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final next = {
        ...profile,
        for (final key in fields.keys) key: controllers[key]!.text.trim(),
      };
      next['targetCountries'] = controllers['targetCountries']!
          .text
          .split(RegExp('[,،]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      next['dateOfBirth'] = controllers['dateOfBirth']!.text.trim().isEmpty
          ? null
          : controllers['dateOfBirth']!.text.trim();
      next['currentEducationLevel'] = level;
      // بند 8
      next['parentInfo'] = {
        'name': controllers['parentName']!.text.trim(),
        'phone': controllers['parentPhone']!.text.trim(),
        'relationship': controllers['parentRelationship']!.text.trim(),
      };
      next['emergencyContact'] = {
        'name': controllers['emergencyName']!.text.trim(),
        'phone': controllers['emergencyPhone']!.text.trim(),
        'relationship': controllers['emergencyRelationship']!.text.trim(),
      };
      next['nativeLanguage'] = controllers['nativeLanguage']!.text.trim();
      next['otherLanguages'] = controllers['otherLanguages']!
          .text
          .split(RegExp('[,،]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await StudentRepository.instance.updateProfile(next);
      if (!mounted) return;
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pickBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final stored = DateTime.tryParse(controllers['dateOfBirth']!.text);
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
        confirmText: 'اختيار');
    if (value != null && mounted)
      setState(() => controllers['dateOfBirth']!.text =
          value.toIso8601String().split('T').first);
  }

  Widget field(String key) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controllers[key],
        enabled: !saving,
        readOnly: key == 'dateOfBirth',
        onTap: key == 'dateOfBirth' ? pickBirthDate : null,
        textDirection: [
          'englishFullName',
          'passportNumber',
          'phone',
          'gpa',
          'dateOfBirth'
        ].contains(key)
            ? TextDirection.ltr
            : null,
        keyboardType: key == 'phone'
            ? TextInputType.phone
            : key == 'gpa'
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
        minLines: key == 'bio' ? 3 : 1,
        maxLines: key == 'bio' ? 5 : 1,
        decoration: featureInput(fields[key]!,
            hint: key == 'targetCountries' ? 'مثال: تركيا، ألمانيا' : null,
            suffix: key == 'dateOfBirth'
                ? const Icon(Icons.calendar_today_outlined, size: 20)
                : null),
        validator: (value) {
          if (key != 'dateOfBirth' || value == null || value.trim().isEmpty)
            return null;
          final date = DateTime.tryParse(value.trim());
          return date == null || date.isAfter(DateTime.now())
              ? 'أدخل تاريخ ميلاد صحيحًا'
              : null;
        },
      ));

  Widget _extraField(
    String key,
    Map<String, String> labels, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    bool ltr = false,
  }) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: TextFormField(
            controller: controllers[key],
            enabled: !saving,
            textDirection: ltr ? TextDirection.ltr : null,
            keyboardType: keyboard,
            decoration: featureInput(labels[key]!, hint: hint),
          ));

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'الملف الشخصي',
        bottomBar: !loaded
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  color: Colors.white,
                  child: PrimaryButton(
                      label: saving ? 'جاري الحفظ...' : 'حفظ البيانات',
                      icon: Icons.check_rounded,
                      onPressed: saving ? null : save),
                )),
        body: loading
            ? const LoadingState()
            : error != null && !loaded
                ? ErrorState(message: error!, onRetry: load)
                : Form(
                    key: form,
                    child: FeatureBody(children: [
                      const FeatureIntro(
                          title: 'ملفك، بداية رحلتك',
                          subtitle:
                              'حدّث بياناتك لتسهيل التقديم ومتابعة طلباتك. يمكنك إكمالها في أي وقت.',
                          icon: Icons.person_outline_rounded),
                      if (error != null) InlineNotice(error!, error: true),
                      FeaturePanel(
                          title: 'المعلومات الشخصية',
                          subtitle: 'اكتب الاسم كما يظهر في وثائقك الرسمية.',
                          child: Column(children: [
                            field('englishFullName'),
                            field('phone'),
                            field('nationality'),
                            field('currentResidenceCountry'),
                            field('address'),
                          ])),
                      FeaturePanel(
                          title: 'وثائق الهوية',
                          child: Column(children: [
                            field('passportNumber'),
                            field('dateOfBirth')
                          ])),
                      FeaturePanel(
                          title: 'المعلومات الأكاديمية',
                          child: Column(children: [
                            DropdownButtonFormField<String>(
                                initialValue: level,
                                decoration: featureInput('المستوى الدراسي'),
                                items: const [
                                  DropdownMenuItem(
                                      value: '', child: Text('غير محدد')),
                                  DropdownMenuItem(
                                      value: 'high-school',
                                      child: Text('ثانوي')),
                                  DropdownMenuItem(
                                      value: 'bachelor',
                                      child: Text('بكالوريوس')),
                                  DropdownMenuItem(
                                      value: 'master', child: Text('ماجستير')),
                                  DropdownMenuItem(
                                      value: 'phd', child: Text('دكتوراه')),
                                ],
                                onChanged: saving
                                    ? null
                                    : (value) =>
                                        setState(() => level = value!)),
                            const SizedBox(height: 18),
                            field('currentEducation'),
                            field('gpa'),
                          ])),
                      FeaturePanel(
                          title: 'خطتك الدراسية',
                          child: Column(children: [
                            field('targetCountries'),
                            field('intake'),
                            field('bio')
                          ])),
                      FeaturePanel(
                          title: 'اللغات',
                          subtitle: 'يساعدنا هذا في اختيار المستشار المناسب.',
                          child: Column(children: [
                            _extraField('nativeLanguage', langFields),
                            _extraField('otherLanguages', langFields,
                                hint: 'مثال: الإنجليزية، الفرنسية'),
                          ])),
                      FeaturePanel(
                          title: 'ولي الأمر',
                          subtitle: 'للتواصل في حالات الضرورة.',
                          child: Column(children: [
                            _extraField('parentName', parentFields),
                            _extraField('parentPhone', parentFields,
                                keyboard: TextInputType.phone, ltr: true),
                            _extraField('parentRelationship', parentFields),
                          ])),
                      FeaturePanel(
                          title: 'جهة الاتصال الطارئة',
                          subtitle: 'شخص يمكن التواصل معه في حالات الطوارئ.',
                          child: Column(children: [
                            _extraField('emergencyName', emergencyFields),
                            _extraField('emergencyPhone', emergencyFields,
                                keyboard: TextInputType.phone, ltr: true),
                            _extraField('emergencyRelationship',
                                emergencyFields),
                          ])),
                    ])),
      );
}
