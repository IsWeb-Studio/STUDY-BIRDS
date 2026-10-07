import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/auth_session.dart';

class AdminRewardRulesScreen extends StatefulWidget {
  const AdminRewardRulesScreen({super.key});
  @override
  State<AdminRewardRulesScreen> createState() => _AdminRewardRulesScreenState();
}

class _AdminRewardRulesScreenState extends State<AdminRewardRulesScreen> {
  static const events = {
    'application-submitted': 'تقديم طلب دراسة',
    'final-admission': 'الحصول على قبول نهائي',
    'referral-qualified': 'إحالة طالب قدّم طلب دراسة',
  };
  static const path = '/admin/student-financials/reward-rules';
  late Future<dynamic> _rules;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _rules = ApiClient.instance.get(path, token: AuthSession.instance.token); }

  Future<void> _edit(Map? existing) async {
    var event = existing?['event'] as String? ?? events.keys.first;
    var enabled = existing?['enabled'] == true;
    final title = TextEditingController(text: existing?['title'] as String? ?? '');
    final points = TextEditingController(text: existing?['points']?.toString() ?? '');
    var saving = false;
    String? error;
    final route = DialogRoute<bool>(context: context, barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(builder: (dialog, update) => AlertDialog(
        title: const Text('قاعدة المكافأة'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: event,
            items: events.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: existing != null || saving ? null : (value) => update(() => event = value!),
          ),
          TextField(controller: title, enabled: !saving, decoration: const InputDecoration(labelText: 'اسم المكافأة')),
          TextField(controller: points, enabled: !saving, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد النقاط')),
          SwitchListTile(title: const Text('تفعيل المنح'), value: enabled,
            onChanged: saving ? null : (value) => update(() => enabled = value)),
          const Text('التفعيل يشمل الطلبات والإحالات المؤهلة السابقة أيضًا. تمنح النقاط مرة واحدة لكل طلب أو إحالة، ولا تتغير النقاط الممنوحة عند تعديل القاعدة.'),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(onPressed: saving ? null : () async {
            final count = int.tryParse(points.text.trim());
            if (title.text.trim().isEmpty || count == null || count < 1 || count > 1000000) {
              update(() => error = 'أدخل اسمًا وعدد نقاط صحيحًا من 1 إلى 1000000'); return;
            }
            update(() { saving = true; error = null; });
            try {
              final body = {'event': event, 'title': title.text.trim(), 'points': count, 'enabled': enabled};
              if (existing == null) {
                await ApiClient.instance.post(path, token: AuthSession.instance.token, body: body);
              } else {
                await ApiClient.instance.put('$path/${existing['_id']}', token: AuthSession.instance.token, body: body);
              }
              if (dialog.mounted) Navigator.pop(dialog, true);
            } catch (e) {
              if (dialog.mounted) update(() { saving = false; error = e is ApiException ? e.message : 'تعذر الحفظ'; });
            }
          }, child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ')),
        ],
      )));
    final saved = await Navigator.of(context).push(route);
    if (saved == true && mounted) setState(_reload);
    await route.completed;
    title.dispose();
    points.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(title: 'قواعد مكافآت الطلاب', body: Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: FilledButton.icon(
      onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('إضافة قاعدة'))),
    Expanded(child: FutureBuilder<dynamic>(future: _rules, builder: (context, snapshot) {
      if (snapshot.hasError) return ErrorState(message: 'تعذر تحميل القواعد', onRetry: () => setState(_reload));
      if (!snapshot.hasData) return const LoadingState();
      final rules = snapshot.data as List;
      if (rules.isEmpty) return const Center(child: Text('لا توجد قواعد مفعّلة. أضف القواعد وحدد عدد النقاط.'));
      return ListView(children: [for (final row in rules) ListTile(
        title: Text('${row['title']}'),
        subtitle: Text('${events[row['event']] ?? ''} • ${row['points']} نقطة • ${row['enabled'] == true ? 'مفعّلة' : 'معطّلة'}'),
        trailing: const Icon(Icons.edit_outlined), onTap: () => _edit(row as Map),
      )]);
    })),
  ]));
}
