import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/admin_modules_repository.dart';
import 'generic_approval_list_screen.dart';

class AdminAgencyRequestsScreen extends StatelessWidget {
  const AdminAgencyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenericApprovalListScreen(
      title: 'طلبات الوكالة',
      fetchItems: () => AdminModulesRepository.instance.getAgencyRequests(),
      itemTitle: (item) => (item['student'] as Map<String, dynamic>?)?['name'] as String? ?? '—',
      itemSubtitle: (item) => (item['student'] as Map<String, dynamic>?)?['email'] as String? ?? '',
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
      itemTitle: (item) => (item['student'] as Map<String, dynamic>?)?['name'] as String? ?? '—',
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
      itemTitle: (item) => '\$${item['amount'] ?? 0} — ${(item['agent'] as Map<String, dynamic>?)?['name'] ?? ''}',
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
      itemTitle: (item) => (item['agent'] as Map<String, dynamic>?)?['name'] as String? ?? '—',
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

/// Read-only — the backend doesn't expose a write action for browsing agent
/// profiles from this list (that's what partner-students/verification are
/// for), so this is a simple directory.
class AdminAgentsScreen extends StatefulWidget {
  const AdminAgentsScreen({super.key});

  @override
  State<AdminAgentsScreen> createState() => _AdminAgentsScreenState();
}

class _AdminAgentsScreenState extends State<AdminAgentsScreen> {
  List<dynamic> _agents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AdminModulesRepository.instance.getPartners();
      if (!mounted) return;
      setState(() { _agents = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'تعذر تحميل قائمة الوكلاء.'; _loading = false; });
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
                : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _agents.length,
                  itemBuilder: (context, i) {
                    final agent = _agents[i] as Map<String, dynamic>;
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(agent['name'] as String? ?? '—', style: AppTextStyles.cardTitle),
                          Text(agent['email'] as String? ?? '', style: AppTextStyles.caption),
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
