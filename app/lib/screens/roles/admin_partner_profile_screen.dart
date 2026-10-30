import 'package:flutter/material.dart';

import '../../core/config/app_theme.dart';
import '../../core/repositories/admin_modules_repository.dart';
import '../../core/utils/json_safe.dart';
import '../../core/widgets/app_notice.dart';

class AdminPartnerProfileScreen extends StatefulWidget {
  final String partnerId;
  const AdminPartnerProfileScreen({super.key, required this.partnerId});

  @override
  State<AdminPartnerProfileScreen> createState() => _AdminPartnerProfileScreenState();
}

class _AdminPartnerProfileScreenState extends State<AdminPartnerProfileScreen> {
  Map<String, dynamic> _data = {};
  final Map<String, String> _statusDrafts = {};
  bool _loading = true;
  bool _updatingAccount = false;
  String? _error;

  static const _statuses = <String, String>{
    'under-review': 'قيد المراجعة',
    'preliminary-accepted': 'قبول مبدئي',
    'final-accepted': 'قبول نهائي',
    'rejected': 'مرفوض',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AdminModulesRepository.instance.getPartnerDetails(widget.partnerId);
      if (!mounted) return;
      final students = Json.list(data['students']);
      _statusDrafts
        ..clear()
        ..addEntries(students.map((raw) {
          final student = Json.map(raw);
          final id = '${student['_id'] ?? ''}';
          return MapEntry(id, '${student['applicationStatus'] ?? 'under-review'}');
        }));
      setState(() { _data = data; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _toggleAccountStatus(bool active) async {
    if (_updatingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'تفعيل حساب الشريك؟' : 'تعطيل حساب الشريك؟'),
        content: Text(active
            ? 'سيتمكن الشريك من استخدام حسابه مجددًا.'
            : 'سيتوقف الشريك عن تسجيل الدخول حتى إعادة تفعيل الحساب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updatingAccount = true);
    try {
      final updated = await AdminModulesRepository.instance.updatePartnerAccountStatus(
        widget.partnerId, isActive: active);
      final partner = Json.mapOrNull(_data['partner']) ?? {};
      setState(() => _data['partner'] = {...partner, ...updated});
      _notice(active ? 'تم تفعيل الحساب.' : 'تم تعطيل الحساب.');
    } catch (error) {
      _notice('تعذر تحديث حالة الحساب: $error', error: true);
    } finally {
      if (mounted) setState(() => _updatingAccount = false);
    }
  }

  Future<void> _saveStudentStatus(String studentId) async {
    final students = Json.list(_data['students']).map(Json.map).toList();
    final index = students.indexWhere((student) => '${student['_id']}' == studentId);
    if (index < 0) return;
    final current = '${students[index]['applicationStatus'] ?? ''}';
    final next = _statusDrafts[studentId];
    if (next == null || next == current) return;
    try {
      final updated = await AdminModulesRepository.instance.updatePartnerStudentStatus(
        studentId, applicationStatus: next);
      students[index] = updated;
      setState(() => _data['students'] = students);
      _notice('تم تحديث حالة الطالب وإشعار الشريك.');
    } catch (error) {
      _notice('تعذر تحديث حالة الطالب: $error', error: true);
    }
  }

  void _notice(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ));
  }

  Widget _section(String title, List<dynamic> values, {String subtitleKey = 'description'}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$title (${values.length})', style: AppTextStyles.cardTitle),
          if (values.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 10), child: Text('لا توجد سجلات'))
          else
            ...values.take(8).map((raw) {
              final item = Json.map(raw);
              final heading = item['subject'] ?? item['title'] ?? item['description'] ?? item['fileName'] ?? item['kind'] ?? 'سجل';
              final detail = item[subtitleKey] ?? item['status'] ?? item['message'] ?? item['amount'] ?? '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('$heading', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: '$detail'.isEmpty ? null : Text('$detail', maxLines: 2, overflow: TextOverflow.ellipsis),
              );
            }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppScaffold(title: 'ملف الشريك', body: LoadingState());
    if (_error != null) return AppScaffold(title: 'ملف الشريك', body: ErrorState(message: _error!, onRetry: _load));
    final partner = Json.mapOrNull(_data['partner']) ?? {};
    final profile = Json.mapOrNull(partner['profile']) ?? {};
    final students = Json.list(_data['students']);
    final active = partner['isActive'] != false;
    return AppScaffold(
      title: '${partner['name'] ?? 'ملف الشريك'}',
      actions: [IconButton(tooltip: 'تحديث', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${partner['name'] ?? '—'}', style: AppTextStyles.screenTitle),
              const SizedBox(height: 4), Text('${partner['email'] ?? ''}'),
              const Divider(height: 24),
              for (final entry in <String, String>{
                'الشركة': '${profile['companyName'] ?? '—'}',
                'الموقع': '${profile['location'] ?? '—'}',
                'الهاتف': '${profile['phone'] ?? '—'}',
                'العنوان': '${profile['address'] ?? '—'}',
                'الموقع الإلكتروني': '${profile['website'] ?? '—'}',
                'حالة التوثيق': '${profile['verificationStatus'] ?? 'pending'}',
              }.entries)
                Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('${entry.key}: ${entry.value}')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(active ? 'الحساب مفعل' : 'الحساب معطل'),
                value: active,
                onChanged: _updatingAccount ? null : _toggleAccountStatus,
              ),
            ]),
          )),
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('طلاب الشريك (${students.length})', style: AppTextStyles.cardTitle),
              if (students.isEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('لا يوجد طلاب مرتبطون')),
              ...students.map((raw) {
                final student = Json.map(raw);
                final id = '${student['_id'] ?? ''}';
                final current = '${student['applicationStatus'] ?? 'under-review'}';
                return Column(children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${student['name'] ?? '—'}'),
                    subtitle: Text('${student['email'] ?? ''} · ${student['desiredUniversity'] ?? ''}'),
                  ),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      initialValue: _statuses.containsKey(_statusDrafts[id]) ? _statusDrafts[id] : current,
                      decoration: const InputDecoration(labelText: 'حالة الملف', border: OutlineInputBorder()),
                      items: _statuses.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                      onChanged: (value) { if (value != null) setState(() => _statusDrafts[id] = value); },
                    )),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'حفظ الحالة',
                      onPressed: _statusDrafts[id] == current ? null : () => _saveStudentStatus(id),
                      icon: const Icon(Icons.save_outlined),
                    ),
                  ]),
                  const Divider(height: 24),
                ]);
              }),
            ]),
          )),
          _section('طلبات السحب', Json.list(_data['payoutRequests']), subtitleKey: 'status'),
          _section('تذاكر الدعم', Json.list(_data['supportTickets']), subtitleKey: 'status'),
          _section('مستندات التوثيق', Json.list(_data['verificationDocuments']), subtitleKey: 'status'),
          _section('حركات المحفظة', Json.list(_data['walletEntries']), subtitleKey: 'amount'),
          _section('الإشعارات الأخيرة', Json.list(_data['notifications']), subtitleKey: 'message'),
        ]),
      ),
    );
  }
}
