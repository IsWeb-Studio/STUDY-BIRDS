import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/employee_repository.dart';
import '../../core/catalog_repository.dart';
import 'employee_sections_picker_screen.dart';

const List<Map<String, String>> kAccountRoleOptions = [
  {'value': 'student', 'label': 'طالب'},
  {'value': 'partner', 'label': 'وكيل'},
  {'value': 'admin', 'label': 'أدمن'},
  {'value': 'parent', 'label': 'ولي أمر'},
  {'value': 'university', 'label': 'جامعة'},
  {'value': 'employee', 'label': 'موظف'},
];

/// Admin-only (matches the backend's "user/employee management stays
/// admin-only" rule — an employee account, whatever sections it's granted,
/// can never reach this screen or its endpoints).
class AdminUsersAccessScreen extends StatefulWidget {
  const AdminUsersAccessScreen({super.key});

  @override
  State<AdminUsersAccessScreen> createState() => _AdminUsersAccessScreenState();
}

class _AdminUsersAccessScreenState extends State<AdminUsersAccessScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await EmployeeRepository.instance.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = data;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل المستخدمين.';
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _users.where((u) {
        final user = u as Map<String, dynamic>;
        final matchesQuery = q.isEmpty || (user['name'] as String? ?? '').toLowerCase().contains(q) || (user['email'] as String? ?? '').toLowerCase().contains(q);
        final matchesRole = _roleFilter == 'all' || user['role'] == _roleFilter;
        return matchesQuery && matchesRole;
      }).toList();
    });
  }

  void _replaceUser(Map<String, dynamic> updated) {
    setState(() {
      _users = _users.map((u) => (u as Map<String, dynamic>)['_id'] == updated['_id'] ? updated : u).toList();
    });
    _applyFilter();
  }

  Future<void> _patch(String id, {String? role, bool? isActive}) async {
    try {
      final updated = await EmployeeRepository.instance.updateUser(id, role: role, isActive: isActive);
      _replaceUser(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر تحديث الحساب')));
      }
    }
  }

  Future<void> _onRoleSelected(Map<String, dynamic> user, String newRole) async {
    if (newRole == 'employee') {
      final permissions = (user['permissions'] as List<dynamic>? ?? []).cast<String>();
      final updated = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
        builder: (_) => EmployeeSectionsPickerScreen(
          userId: user['_id'] as String,
          userName: user['name'] as String? ?? '',
          userEmail: user['email'] as String? ?? '',
          initialPermissions: permissions,
        ),
      ));
      if (updated != null) _replaceUser(updated);
      return;
    }
    if (newRole == 'university') {
      await _openLinkUniversity(user);
      return;
    }
    await _patch(user['_id'] as String, role: newRole);
  }

  Future<void> _openLinkUniversity(Map<String, dynamic> user) async {
    List<dynamic> universities = [];
    String? selectedId;
    bool loading = true;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (loading && universities.isEmpty && error == null) {
            CatalogRepository.instance.getUniversities().then((data) {
              setSheetState(() {
                universities = data;
                loading = false;
              });
            }).catchError((e) {
              setSheetState(() {
                error = 'تعذر تحميل الجامعات.';
                loading = false;
              });
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اختيار الجامعة المرتبطة', style: AppTextStyles.cardTitle),
                Text('${user['name']} — ${user['email']}', style: AppTextStyles.caption),
                const SizedBox(height: 12),
                if (loading)
                  const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                else if (error != null)
                  Text(error!, style: const TextStyle(color: AppColors.danger))
                else if (universities.isEmpty)
                  const Text('لا توجد جامعات. أضف جامعة أولًا.', style: AppTextStyles.caption)
                else
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedId,
                        hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('اختر جامعة')),
                        items: universities.map((u) {
                          final uni = u as Map<String, dynamic>;
                          return DropdownMenuItem(value: uni['_id'] as String, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(uni['name'] as String? ?? '—')));
                        }).toList(),
                        onChanged: (v) => setSheetState(() => selectedId = v),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'تأكيد وحفظ',
                  onPressed: selectedId == null
                      ? null
                      : () async {
                          try {
                            final updated = await EmployeeRepository.instance.updateUser(user['_id'] as String, role: 'university', linkedUniversity: selectedId);
                            _replaceUser(updated);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            setSheetState(() => error = e is ApiException ? e.message : 'تعذر ربط الحساب بالجامعة.');
                          }
                        },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'المستخدمون والصلاحيات',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
                  child: TextField(
                    controller: _searchController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(hintText: 'ابحث بالاسم أو البريد...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12), prefixIcon: Icon(Icons.search_rounded, color: AppColors.navy)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _RoleChip(label: 'الكل', selected: _roleFilter == 'all', onTap: () => setState(() { _roleFilter = 'all'; _applyFilter(); })),
                      const SizedBox(width: 6),
                      ...kAccountRoleOptions.map((r) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _RoleChip(label: r['label']!, selected: _roleFilter == r['value'], onTap: () => setState(() { _roleFilter = r['value']!; _applyFilter(); })),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.navy,
              child: _loading
                  ? const LoadingState()
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: _load)
                      : _filtered.isEmpty
                          ? const EmptyState(icon: Icons.people_outline_rounded, title: 'لا يوجد مستخدمون', message: 'لا توجد نتائج مطابقة.')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final user = _filtered[i] as Map<String, dynamic>;
                              final isActive = user['isActive'] != false;
                              return AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(user['name'] as String? ?? '—', style: AppTextStyles.cardTitle),
                                              Text(user['email'] as String? ?? '', style: AppTextStyles.caption),
                                            ],
                                          ),
                                        ),
                                        StatusBadge(label: isActive ? 'نشط' : 'معطّل', color: isActive ? AppColors.success : AppColors.danger),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        DropdownButton<String>(
                                          value: user['role'] as String?,
                                          underline: const SizedBox(),
                                          items: kAccountRoleOptions.map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!))).toList(),
                                          onChanged: (v) {
                                            if (v != null) _onRoleSelected(user, v);
                                          },
                                        ),
                                        if (user['role'] == 'employee')
                                          OutlinedButton(
                                            onPressed: () => _onRoleSelected(user, 'employee'),
                                            child: const Text('تعديل الصلاحيات'),
                                          ),
                                        if (user['role'] == 'university')
                                          OutlinedButton(
                                            onPressed: () => _openLinkUniversity(user),
                                            child: const Text('اختيار الجامعة'),
                                          ),
                                        OutlinedButton(
                                          onPressed: () => _patch(user['_id'] as String, isActive: !isActive),
                                          child: Text(isActive ? 'تعطيل' : 'تفعيل'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: selected ? AppColors.navy : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
