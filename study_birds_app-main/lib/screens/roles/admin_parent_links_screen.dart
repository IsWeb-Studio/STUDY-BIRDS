import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/employee_repository.dart';

class AdminParentLinksScreen extends StatefulWidget {
  const AdminParentLinksScreen({super.key});

  @override
  State<AdminParentLinksScreen> createState() => _AdminParentLinksScreenState();
}

class _AdminParentLinksScreenState extends State<AdminParentLinksScreen> {
  List<dynamic> _links = [];
  bool _loading = true;
  String? _error;
  String? _actingOnId;

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
      final data = await EmployeeRepository.instance.getParentLinks();
      if (!mounted) return;
      setState(() {
        _links = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل طلبات الربط.';
        _loading = false;
      });
    }
  }

  Future<void> _decide(String id, String status) async {
    setState(() => _actingOnId = id);
    try {
      final updated = await EmployeeRepository.instance.updateParentLinkStatus(id, status: status);
      if (!mounted) return;
      setState(() {
        _links = _links.map((l) => (l as Map<String, dynamic>)['_id'] == id ? updated : l).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر تحديث الطلب')));
      }
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'طلبات ربط أولياء الأمور',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _links.isEmpty
                    ? const EmptyState(icon: Icons.family_restroom_outlined, title: 'لا توجد طلبات', message: 'ستظهر هنا طلبات أولياء الأمور لمتابعة أبنائهم.')
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _links.length,
                      itemBuilder: (context, i) {
                        final link = _links[i] as Map<String, dynamic>;
                        final parent = link['parent'] as Map<String, dynamic>?;
                        final student = link['student'] as Map<String, dynamic>?;
                        final status = link['status'] as String? ?? 'pending';
                        final id = link['_id'] as String;

                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${parent?['name'] ?? '—'}  ←→  ${student?['name'] ?? '—'}', style: AppTextStyles.cardTitle),
                              const SizedBox(height: 4),
                              Text('${parent?['email'] ?? ''} → ${student?['email'] ?? ''}', style: AppTextStyles.caption),
                              if ((link['relationship'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text('صلة القرابة: ${link['relationship']}', style: AppTextStyles.caption),
                              ],
                              const SizedBox(height: 10),
                              if (status == 'pending')
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _actingOnId == id ? null : () => _decide(id, 'rejected'),
                                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                                        child: const Text('رفض'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: PrimaryButton(label: 'قبول', onPressed: _actingOnId == id ? null : () => _decide(id, 'approved')),
                                    ),
                                  ],
                                )
                              else
                                StatusBadge(
                                  label: status == 'approved' ? 'مقبول' : 'مرفوض',
                                  color: status == 'approved' ? AppColors.success : AppColors.danger,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}
