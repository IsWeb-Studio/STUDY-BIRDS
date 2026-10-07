import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/auth_session.dart';

class AlumniDirectoryScreen extends StatefulWidget {
  const AlumniDirectoryScreen({super.key});
  @override
  State<AlumniDirectoryScreen> createState() => _AlumniDirectoryScreenState();
}

class _AlumniDirectoryScreenState extends State<AlumniDirectoryScreen> {
  final _country = TextEditingController();
  bool _mentoring = false;
  late Future<dynamic> _profiles;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _country.dispose(); super.dispose(); }
  void _reload() {
    final query = Uri(queryParameters: {'country': _country.text.trim(), 'mentoring': '$_mentoring'}).query;
    _profiles = ApiClient.instance.get('/alumni?$query', token: AuthSession.instance.token);
  }
  @override
  Widget build(BuildContext context) => AppScaffold(title: 'دليل الخريجين', actions: [
    TextButton(onPressed: () async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AlumniProfileEditor()));
      if (mounted) setState(_reload);
    }, child: const Text('ملفي')),
  ], body: Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _country,
      onSubmitted: (_) => setState(_reload), decoration: InputDecoration(labelText: 'البحث حسب الدولة',
        suffixIcon: IconButton(onPressed: () => setState(_reload), icon: const Icon(Icons.search))))),
    CheckboxListTile(title: const Text('المتاحون للإرشاد فقط'), value: _mentoring,
      onChanged: (value) => setState(() { _mentoring = value ?? false; _reload(); })),
    Expanded(child: FutureBuilder<dynamic>(future: _profiles, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'تعذر تحميل الخريجين', onRetry: () => setState(_reload));
      if (!snapshot.hasData) return const LoadingState();
      final rows = snapshot.data as List;
      if (rows.isEmpty) return const Center(child: Text('لا توجد ملفات منشورة تطابق البحث'));
      return ListView(padding: const EdgeInsets.all(16), children: [for (final row in rows)
        AppCard(margin: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(row['user'] as Map?)?['name'] ?? 'خريج'}', style: AppTextStyles.cardTitle),
          for (final key in ['university', 'fieldOfStudy', 'country', 'graduationYear', 'currentJob', 'bio'])
            if (row[key] != null && '${row[key]}'.isNotEmpty) Text('${row[key]}'),
          if (row['openToMentoring'] == true) const Text('متاح لإرشاد الطلاب'),
          if ('${row['linkedinUrl'] ?? ''}'.isNotEmpty) TextButton(onPressed: () async {
            final uri = Uri.tryParse('${row['linkedinUrl']}');
            if (uri == null || uri.scheme != 'https' || !['linkedin.com', 'www.linkedin.com'].contains(uri.host) || uri.userInfo.isNotEmpty) return;
            try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
            catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط'))); }
          }, child: const Text('التواصل عبر LinkedIn')),
        ])),
      ]);
    })),
  ]));
}

class _AlumniProfileEditor extends StatefulWidget {
  const _AlumniProfileEditor();
  @override
  State<_AlumniProfileEditor> createState() => _AlumniProfileEditorState();
}

class _AlumniProfileEditorState extends State<_AlumniProfileEditor> {
  static const labels = {'university': 'الجامعة', 'fieldOfStudy': 'التخصص', 'country': 'الدولة',
    'graduationYear': 'سنة التخرج', 'currentJob': 'العمل الحالي', 'bio': 'نبذة عنك', 'linkedinUrl': 'رابط LinkedIn'};
  final _fields = {for (final key in labels.keys) key: TextEditingController()};
  bool _loading = true, _saving = false, _public = false, _mentoring = false;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { for (final field in _fields.values) { field.dispose(); } super.dispose(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.instance.get('/alumni/me/profile', token: AuthSession.instance.token);
      if (!mounted) return;
      if (data is Map) {
        for (final entry in _fields.entries) { entry.value.text = '${data[entry.key] ?? ''}'; }
        _public = data['isPublic'] == true; _mentoring = data['openToMentoring'] == true;
      }
    } catch (_) { if (mounted) _error = 'تعذر تحميل ملفك'; }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _save() async {
    final yearText = _fields['graduationYear']!.text.trim();
    final year = int.tryParse(yearText);
    if (yearText.isNotEmpty && (year == null || year < 1900 || year > DateTime.now().year)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل سنة تخرج صحيحة'))); return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.instance.put('/alumni/me', token: AuthSession.instance.token, body: {
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
        'graduationYear': year, 'isPublic': _public, 'openToMentoring': _mentoring,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر الحفظ')));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => AppScaffold(title: 'ملفي في شبكة الخريجين', body: _loading
    ? const LoadingState() : _error != null ? ErrorState(message: _error!, onRetry: _load)
    : ListView(padding: const EdgeInsets.all(16), children: [
      for (final entry in labels.entries) Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(
        controller: _fields[entry.key], enabled: !_saving, maxLines: entry.key == 'bio' ? 4 : 1,
        keyboardType: entry.key == 'graduationYear' ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: entry.value))),
      SwitchListTile(title: const Text('متاح لإرشاد الطلاب'), value: _mentoring,
        onChanged: _saving ? null : (value) => setState(() => _mentoring = value)),
      SwitchListTile(title: const Text('إظهار ملفي لمستخدمي المنصة'),
        subtitle: const Text('يشمل اسمك ومعلوماتك أعلاه ورابط التواصل. يمكنك إخفاؤه في أي وقت.'), value: _public,
        onChanged: _saving ? null : (value) => setState(() => _public = value)),
      PrimaryButton(label: _saving ? 'جارٍ الحفظ...' : 'حفظ', onPressed: _saving ? null : _save),
    ]));
}
