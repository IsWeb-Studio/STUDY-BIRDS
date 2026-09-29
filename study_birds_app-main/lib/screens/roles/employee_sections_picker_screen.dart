import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/employee_repository.dart';
import '../../core/employee_sections.dart';

/// Mirrors the web's EmployeePermissionsDialog.tsx exactly: pick one or more
/// sections, save via PATCH /api/admin/users/:id with role="employee".
/// Pushed as a full screen here (the web uses a <dialog>) since a modal
/// bottom sheet with 28 checkboxes would be cramped on mobile.
class EmployeeSectionsPickerScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final List<String> initialPermissions;

  const EmployeeSectionsPickerScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.initialPermissions,
  });

  @override
  State<EmployeeSectionsPickerScreen> createState() => _EmployeeSectionsPickerScreenState();
}

class _EmployeeSectionsPickerScreenState extends State<EmployeeSectionsPickerScreen> {
  late Set<String> _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPermissions.toSet();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await EmployeeRepository.instance.updateUser(
        widget.userId,
        role: 'employee',
        permissions: _selected.toList(),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'تعذر حفظ صلاحيات الموظف.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'صلاحيات الموظف',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.userName} — ${widget.userEmail}', style: AppTextStyles.body),
                const SizedBox(height: 6),
                const Text(
                  'اختر قسمًا أو أكثر للسماح بعرض وإدارة بياناته. إدارة المستخدمين والصلاحيات للأدمن فقط.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(onPressed: () => setState(() => _selected = kEmployeeSections.map((s) => s.key).toSet()), child: const Text('تحديد الكل')),
                    TextButton(onPressed: () => setState(() => _selected = {}), child: const Text('إلغاء الكل')),
                  ],
                ),
                if (_selected.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Text('بدون أقسام، لن يستطيع الموظف فتح أي قسم إداري.', style: TextStyle(color: AppColors.warning, fontSize: 12.5)),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: kEmployeeSections.length,
              itemBuilder: (context, i) {
                final section = kEmployeeSections[i];
                final checked = _selected.contains(section.key);
                return CheckboxListTile(
                  value: checked,
                  onChanged: (v) => setState(() => v == true ? _selected.add(section.key) : _selected.remove(section.key)),
                  title: Text(section.labelAr, style: AppTextStyles.body),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(label: _saving ? 'جاري الحفظ...' : 'حفظ الصلاحيات', onPressed: _saving ? null : _save),
          ),
        ],
      ),
    );
  }
}
