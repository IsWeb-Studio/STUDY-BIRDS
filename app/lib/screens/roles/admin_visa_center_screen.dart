import 'package:flutter/material.dart';

import '../../core/config/app_theme.dart';
import '../../core/repositories/admin_modules_repository.dart';
import '../../core/utils/json_safe.dart';

const _visaStates = <String>[
  'not-started',
  'preparing-documents',
  'ready',
  'submitted',
  'under-review',
  'approved',
  'rejected',
];

String _visaLabel(String state, bool ar) {
  const labels = <String, List<String>>{
    'not-started': ['لم تبدأ', 'Not started'],
    'preparing-documents': ['تجهيز المستندات', 'Preparing documents'],
    'ready': ['جاهز للتقديم', 'Ready to submit'],
    'submitted': ['تم التقديم', 'Submitted'],
    'under-review': ['قيد المراجعة', 'Under review'],
    'approved': ['مقبولة', 'Approved'],
    'rejected': ['مرفوضة', 'Rejected'],
  };
  return labels[state]?[ar ? 0 : 1] ?? state;
}

class AdminVisaCenterScreen extends StatefulWidget {
  const AdminVisaCenterScreen({super.key});

  @override
  State<AdminVisaCenterScreen> createState() => _AdminVisaCenterScreenState();
}

class _AdminVisaCenterScreenState extends State<AdminVisaCenterScreen> {
  final _repo = AdminModulesRepository.instance;
  List<Map<String, dynamic>> _cases = [];
  bool _loading = true;
  String? _error;
  String _filter = '';

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

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
      final rows = await _repo.getVisaCases();
      if (!mounted) return;
      setState(() => _cases = rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList());
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    final visible = _cases
        .where((item) => _filter.isEmpty || item['status'] == _filter)
        .toList();
    return AppScaffold(
      title: ar ? 'مركز التأشيرات' : 'Visa center',
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                          ar
                              ? 'تابع متطلبات السفارة والمواعيد والتأمين لطلبات القبول النهائي.'
                              : 'Manage embassy requirements, appointments, and insurance for final-admission applications.',
                          style: AppTextStyles.body),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _filter,
                        decoration: InputDecoration(
                            labelText: ar ? 'تصفية الحالة' : 'Filter status'),
                        items: [
                          DropdownMenuItem(
                              value: '',
                              child: Text(ar ? 'كل الحالات' : 'All statuses')),
                          for (final state in _visaStates)
                            DropdownMenuItem(
                                value: state,
                                child: Text(_visaLabel(state, ar))),
                        ],
                        onChanged: (value) =>
                            setState(() => _filter = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      if (visible.isEmpty)
                        EmptyState(
                          icon: Icons.flight_takeoff_rounded,
                          title: ar ? 'لا توجد ملفات تأشيرة' : 'No visa cases',
                          message: ar
                              ? 'ستظهر الطلبات المؤهلة هنا.'
                              : 'Eligible applications will appear here.',
                        )
                      else
                        ...visible.map((item) {
                          final student = Json.mapOrNull(item['student']) ?? {};
                          final appId = '${item['applicationId'] ?? ''}';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(
                                  '${student['name'] ?? (ar ? 'طالب' : 'Student')}'),
                              subtitle: Text(
                                  '${item['university'] ?? ''} · ${item['program'] ?? ''}'),
                              trailing: Chip(
                                  label: Text(_visaLabel(
                                      '${item['status'] ?? 'not-started'}',
                                      ar))),
                              onTap: appId.isEmpty
                                  ? null
                                  : () async {
                                      final changed =
                                          await Navigator.of(context)
                                              .push<bool>(MaterialPageRoute(
                                        builder: (_) => _AdminVisaCaseEditor(
                                            applicationId: appId),
                                      ));
                                      if (changed == true) _load();
                                    },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _VisaRequirement {
  String label;
  bool done;
  _VisaRequirement(this.label, this.done);
  factory _VisaRequirement.fromJson(dynamic value) {
    final map = Json.mapOrNull(value) ?? {};
    return _VisaRequirement('${map['label'] ?? ''}', map['done'] == true);
  }
  Map<String, dynamic> toJson() => {'label': label.trim(), 'done': done};
}

class _AdminVisaCaseEditor extends StatefulWidget {
  final String applicationId;
  const _AdminVisaCaseEditor({required this.applicationId});

  @override
  State<_AdminVisaCaseEditor> createState() => _AdminVisaCaseEditorState();
}

class _AdminVisaCaseEditorState extends State<_AdminVisaCaseEditor> {
  final _repo = AdminModulesRepository.instance;
  final _newRequirement = TextEditingController();
  final _location = TextEditingController();
  final _provider = TextEditingController();
  final _policy = TextEditingController();
  final _notes = TextEditingController();
  List<_VisaRequirement> _requirements = [];
  Map<String, dynamic>? _data;
  DateTime? _appointment, _expiry;
  String _status = 'not-started';
  bool _loading = true, _saving = false;
  String? _error;

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newRequirement.dispose();
    _location.dispose();
    _provider.dispose();
    _policy.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getVisaCase(widget.applicationId);
      final appointment = Json.mapOrNull(data['appointment']) ?? {};
      final insurance = Json.mapOrNull(data['insurance']) ?? {};
      if (!mounted) return;
      setState(() {
        _data = data;
        _status = '${data['status'] ?? 'not-started'}';
        _requirements = Json.list(data['requirements'])
            .map(_VisaRequirement.fromJson)
            .toList();
        _appointment =
            DateTime.tryParse('${appointment['date'] ?? ''}')?.toLocal();
        _expiry =
            DateTime.tryParse('${insurance['expiresAt'] ?? ''}')?.toLocal();
        _location.text = '${appointment['location'] ?? ''}';
        _provider.text = '${insurance['provider'] ?? ''}';
        _policy.text = '${insurance['policyNumber'] ?? ''}';
        _notes.text = '${data['notes'] ?? ''}';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<DateTime?> _chooseDate(DateTime? current) async {
    final now = DateTime.now();
    final initial = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (date == null || !mounted) return current;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return current;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _dateText(DateTime? date) => date == null
      ? (_ar ? 'اختر التاريخ والوقت' : 'Choose date and time')
      : '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}';

  Future<void> _save() async {
    if (_data == null || _saving || _requirements.length > 30) return;
    if (_requirements
        .any((item) => item.label.trim().isEmpty || item.label.length > 200)) {
      setState(() => _error = _ar
          ? 'تحقق من نصوص المتطلبات (حتى 200 حرف لكل متطلب).'
          : 'Check requirement labels (up to 200 characters each).');
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: _ar ? 'تأكيد حفظ ملف التأشيرة' : 'Confirm visa case update',
      message: _ar
          ? 'سيتم حفظ الحالة والمتطلبات وبيانات الموعد والتأمين.'
          : 'This saves status, requirements, appointment and insurance details.',
      confirmLabel: _ar ? 'حفظ' : 'Save',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.updateVisaCase(widget.applicationId, {
        'version': _data!['version'],
        'status': _status,
        'requirements': _requirements.map((item) => item.toJson()).toList(),
        'appointmentDate': _appointment?.toUtc().toIso8601String(),
        'appointmentLocation': _location.text.trim(),
        'insuranceProvider': _provider.text.trim(),
        'insurancePolicyNumber': _policy.text.trim(),
        'insuranceExpiresAt': _expiry?.toUtc().toIso8601String(),
        'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    if (_loading) {
      return AppScaffold(
          title: ar ? 'ملف التأشيرة' : 'Visa case', body: const LoadingState());
    }
    if (_error != null && _data == null) {
      return AppScaffold(
          title: ar ? 'ملف التأشيرة' : 'Visa case',
          body: ErrorState(message: _error!, onRetry: _load));
    }
    if (_data?['eligible'] != true) {
      return AppScaffold(
          title: ar ? 'ملف التأشيرة' : 'Visa case',
          body: Center(
              child: Text(ar
                  ? 'هذا الطلب غير مؤهل لملف التأشيرة حاليًا.'
                  : 'This application is not currently eligible for a visa case.')));
    }
    return AppScaffold(
      title: ar ? 'ملف التأشيرة' : 'Visa case',
      body: Form(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_error != null) _InlineError(message: _error!),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
                labelText: ar ? 'حالة التأشيرة' : 'Visa status'),
            items: [
              for (final state in _visaStates)
                DropdownMenuItem(
                    value: state, child: Text(_visaLabel(state, ar)))
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: 18),
          Text(
              ar
                  ? 'متطلبات السفارة والمستندات'
                  : 'Embassy and document requirements',
              style: AppTextStyles.sectionLabel),
          for (var i = 0; i < _requirements.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                  value: _requirements[i].done,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _requirements[i].done = value ?? false)),
              title: Text(_requirements[i].label),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _requirements.removeAt(i))),
            ),
          Row(children: [
            Expanded(
                child: TextField(
              controller: _newRequirement,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: ar ? 'متطلب جديد' : 'New requirement'),
            )),
            IconButton(
                tooltip: ar ? 'إضافة' : 'Add',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _saving ||
                        _requirements.length >= 30 ||
                        _newRequirement.text.trim().isEmpty
                    ? null
                    : () => setState(() {
                          _requirements.add(_VisaRequirement(
                              _newRequirement.text.trim(), false));
                          _newRequirement.clear();
                        })),
          ]),
          const SizedBox(height: 12),
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ar ? 'موعد السفارة' : 'Embassy appointment'),
              subtitle: Text(_dateText(_appointment)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _saving
                  ? null
                  : () async {
                      final value = await _chooseDate(_appointment);
                      if (mounted) setState(() => _appointment = value);
                    }),
          TextFormField(
              controller: _location,
              maxLength: 250,
              decoration: InputDecoration(
                  labelText: ar ? 'مكان الموعد' : 'Appointment location')),
          TextFormField(
              controller: _provider,
              maxLength: 150,
              decoration: InputDecoration(
                  labelText: ar ? 'مزود التأمين الصحي' : 'Insurance provider')),
          TextFormField(
              controller: _policy,
              maxLength: 100,
              decoration: InputDecoration(
                  labelText:
                      ar ? 'رقم وثيقة التأمين' : 'Insurance policy number')),
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ar ? 'انتهاء التأمين' : 'Insurance expiry'),
              subtitle: Text(_dateText(_expiry)),
              trailing: const Icon(Icons.event_outlined),
              onTap: _saving
                  ? null
                  : () async {
                      final value = await _chooseDate(_expiry);
                      if (mounted) setState(() => _expiry = value);
                    }),
          TextFormField(
              controller: _notes,
              maxLength: 2000,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: ar ? 'ملاحظات داخلية' : 'Internal notes')),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(ar ? 'حفظ ملف التأشيرة' : 'Save visa case')),
        ]),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
}
