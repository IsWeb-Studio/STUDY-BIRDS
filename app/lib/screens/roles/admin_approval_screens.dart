import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/repositories/admin_modules_repository.dart';
import 'generic_approval_list_screen.dart';
import 'admin_partner_profile_screen.dart';

class AdminAgencyRequestsScreen extends StatelessWidget {
  const AdminAgencyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenericApprovalListScreen(
      title: 'طلبات الوكالة',
      fetchItems: () => AdminModulesRepository.instance.getAgencyRequests(),
      itemTitle: (item) => (Json.mapOrNull(item['student']))?['name'] as String? ?? '—',
      itemSubtitle: (item) => (Json.mapOrNull(item['student']))?['email'] as String? ?? '',
      idOf: (item) => item['_id'] as String,
      statusOf: (item) => item['status'] as String? ?? 'pending',
      statusOptions: const [
        StatusOption('pending', 'قيد المراجعة', AppColors.warning),
        StatusOption('approved', 'قبول', AppColors.success),
        StatusOption('rejected', 'رفض', AppColors.danger),
      ],
      onDecide: (id, status) => AdminModulesRepository.instance.updateAgencyRequestStatus(id, status: status),
      emptyMessage: 'ستظهر هنا طلبات الطلاب الراغبين في أن يصبحوا وكلاء.',
    );
  }
}

class AdminArrivalRequestsScreen extends StatelessWidget {
  const AdminArrivalRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenericApprovalListScreen(
      title: 'طلبات وصول الطلاب',
      fetchItems: () => AdminModulesRepository.instance.getArrivalRequests(),
      itemTitle: (item) => (Json.mapOrNull(item['student']))?['name'] as String? ?? '—',
      itemSubtitle: (item) => 'رحلة: ${item['flightNumber'] ?? '—'} • ${item['airport'] ?? ''}',
      idOf: (item) => item['_id'] as String,
      statusOf: (item) => item['status'] as String? ?? 'submitted',
      statusOptions: const [
        StatusOption('submitted', 'مُرسل', AppColors.warning),
        StatusOption('in-progress', 'قيد التنفيذ', AppColors.info),
        StatusOption('completed', 'مكتمل', AppColors.success),
      ],
      onDecide: (id, status) => AdminModulesRepository.instance.updateArrivalRequest(id, status: status),
      emptyMessage: 'ستظهر هنا طلبات خدمات الوصول اللي بيرسلها الطلاب.',
    );
  }
}

class AdminPayoutRequestsScreen extends StatelessWidget {
  const AdminPayoutRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenericApprovalListScreen(
      title: 'طلبات سحب العمولات',
      fetchItems: () => AdminModulesRepository.instance.getPayoutRequests(),
      itemTitle: (item) => '\$${item['amount'] ?? 0} — ${(Json.mapOrNull(item['agent']))?['name'] ?? ''}',
      itemSubtitle: (item) => item['method'] as String? ?? '',
      idOf: (item) => item['_id'] as String,
      statusOf: (item) => item['status'] as String? ?? 'pending',
      statusOptions: const [
        StatusOption('pending', 'قيد المراجعة', AppColors.warning),
        StatusOption('approved', 'موافَق عليه', AppColors.success),
        StatusOption('rejected', 'مرفوض', AppColors.danger),
      ],
      onDecide: (id, status) => AdminModulesRepository.instance.updatePayoutRequestStatus(id, status: status),
      emptyMessage: 'ستظهر هنا طلبات سحب الأرصدة من الوكلاء.',
    );
  }
}

class AdminVerificationScreen extends StatelessWidget {
  const AdminVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenericApprovalListScreen(
      title: 'توثيق الوكلاء',
      fetchItems: () => AdminModulesRepository.instance.getVerificationQueue(),
      itemTitle: (item) => (Json.mapOrNull(item['agent']))?['name'] as String? ?? '—',
      itemSubtitle: (item) => item['documentType'] as String? ?? '',
      idOf: (item) => item['_id'] as String,
      statusOf: (item) => item['status'] as String? ?? 'pending',
      statusOptions: const [
        StatusOption('pending', 'قيد المراجعة', AppColors.warning),
        StatusOption('approved', 'مقبول', AppColors.success),
        StatusOption('rejected', 'مرفوض', AppColors.danger),
      ],
      onDecide: (id, status) => AdminModulesRepository.instance.reviewVerificationDocument(id, status: status),
      emptyMessage: 'ستظهر هنا مستندات توثيق الوكلاء.',
    );
  }
}

class AdminPartnerStudentsScreen extends StatelessWidget {
  const AdminPartnerStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenericApprovalListScreen(
      title: 'طلاب الوكلاء',
      fetchItems: () => AdminModulesRepository.instance.getAllPartnerStudents(),
      itemTitle: (item) => item['name'] as String? ?? '—',
      itemSubtitle: (item) => item['desiredUniversity'] as String? ?? item['email'] as String? ?? '',
      idOf: (item) => item['_id'] as String,
      statusOf: (item) => item['applicationStatus'] as String? ?? 'under-review',
      statusOptions: const [
        StatusOption('under-review', 'قيد المراجعة', AppColors.warning),
        StatusOption('preliminary-accepted', 'قبول مبدئي', AppColors.info),
        StatusOption('final-accepted', 'قبول نهائي', AppColors.success),
        StatusOption('rejected', 'مرفوض', AppColors.danger),
      ],
      onDecide: (id, status) => AdminModulesRepository.instance.updatePartnerStudentStatus(id, applicationStatus: status),
      emptyMessage: 'ستظهر هنا طلاب كل الوكلاء.',
    );
  }
}

class AdminAgentsScreen extends StatefulWidget {
  const AdminAgentsScreen({super.key});

  @override
  State<AdminAgentsScreen> createState() => _AdminAgentsScreenState();
}

class _AdminAgentsScreenState extends State<AdminAgentsScreen> {
  List<dynamic> _agents = [];
  final _search = TextEditingController();
  final Set<String> _selected = {};
  bool _loading = true;
  bool _bulkBusy = false;
  String? _error;

  List<dynamic> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _agents;
    return _agents.where((raw) {
      final agent = Json.map(raw);
      final profile = Json.mapOrNull(agent['profile']) ?? {};
      return [agent['name'], agent['email'], profile['companyName'], profile['location'], profile['website']]
          .whereType<Object>()
          .join(' ')
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AdminModulesRepository.instance.getPartners();
      if (!mounted) return;
      setState(() { _agents = data; _loading = false; });
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/roles/admin_approval_screens.dart:149');
      if (!mounted) return;
      setState(() { _error = 'تعذر تحميل قائمة الوكلاء.'; _loading = false; });
    }
  }

  Future<void> _setSelectedStatus(bool active) async {
    if (_selected.isEmpty || _bulkBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'تفعيل الشركاء المحددين؟' : 'تعطيل الشركاء المحددين؟'),
        content: Text('سيتم تحديث ${_selected.length} حسابًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      final updated = <String, Map<String, dynamic>>{};
      for (final id in _selected) {
        updated[id] = await AdminModulesRepository.instance
            .updatePartnerAccountStatus(id, isActive: active);
      }
      if (!mounted) return;
      setState(() {
        _agents = _agents.map((raw) {
          final agent = Json.map(raw);
          final patch = updated['${agent['_id']}'];
          return patch == null ? raw : {...agent, ...patch};
        }).toList();
        _selected.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: Text(active ? 'تم تفعيل الحسابات المحددة.' : 'تم تعطيل الحسابات المحددة.'),
        backgroundColor: AppColors.success,
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
          content: Text('تعذر إكمال التحديث: $error'),
          backgroundColor: AppColors.danger,
        ));
        await _load();
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'ملفات الوكلاء',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          labelText: 'بحث بالاسم أو البريد أو الشركة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_selected.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('تم تحديد ${_selected.length} شريك'),
                        Wrap(spacing: 8, children: [
                          OutlinedButton.icon(
                            onPressed: _bulkBusy ? null : () => _setSelectedStatus(true),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('تفعيل المحدد'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _bulkBusy ? null : () => _setSelectedStatus(false),
                            icon: const Icon(Icons.block_outlined),
                            label: const Text('تعطيل المحدد'),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 12),
                      if (_filtered.isEmpty)
                        const EmptyState(icon: Icons.handshake_outlined, title: 'لا توجد نتائج', message: 'جرّب اسمًا أو بريدًا أو اسم شركة آخر.')
                      else
                        ..._filtered.map((raw) {
                          final agent = Json.map(raw);
                          final profile = Json.mapOrNull(agent['profile']) ?? {};
                          final id = '${agent['_id'] ?? ''}';
                          final active = agent['isActive'] != false;
                          return AppCard(
                            onTap: id.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => AdminPartnerProfileScreen(partnerId: id),
                            )),
                            child: Row(children: [
                              Checkbox(
                                value: _selected.contains(id),
                                onChanged: id.isEmpty ? null : (value) => setState(() {
                                  if (value == true) { _selected.add(id); } else { _selected.remove(id); }
                                }),
                              ),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${agent['name'] ?? '—'}', style: AppTextStyles.cardTitle),
                                Text('${agent['email'] ?? ''}', style: AppTextStyles.caption),
                                if ('${profile['companyName'] ?? ''}'.isNotEmpty)
                                  Text('${profile['companyName']} · ${profile['location'] ?? ''}', style: AppTextStyles.caption),
                              ])),
                              StatusBadge(label: active ? 'مفعل' : 'معطل', color: active ? AppColors.success : AppColors.danger),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded),
                            ]),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}
