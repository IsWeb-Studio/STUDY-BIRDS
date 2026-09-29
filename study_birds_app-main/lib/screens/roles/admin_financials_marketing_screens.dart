import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/admin_modules_repository.dart';

class AdminStudentFinancialsScreen extends StatefulWidget {
  const AdminStudentFinancialsScreen({super.key});

  @override
  State<AdminStudentFinancialsScreen> createState() => _AdminStudentFinancialsScreenState();
}

class _AdminStudentFinancialsScreenState extends State<AdminStudentFinancialsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _tab = 0;

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
      final data = await AdminModulesRepository.instance.getStudentFinancials();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل البيانات المالية.';
        _loading = false;
      });
    }
  }

  Future<void> _reviewProof(String id, String status) async {
    try {
      final updated = await AdminModulesRepository.instance.reviewPaymentProof(id, status: status);
      if (!mounted) return;
      setState(() {
        final proofs = (_data!['paymentProofs'] as List<dynamic>).map((p) => (p as Map<String, dynamic>)['_id'] == id ? updated : p).toList();
        _data = {..._data!, 'paymentProofs': proofs};
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر التحديث')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مالية الطلاب',
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(child: _tabButton('الفواتير', 0)),
                          const SizedBox(width: 8),
                          Expanded(child: _tabButton('إثباتات الدفع', 1)),
                        ],
                      ),
                    ),
                    Expanded(child: _tab == 0 ? _buildInvoices() : _buildProofs()),
                  ],
                ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? AppColors.navy : Colors.white, borderRadius: BorderRadius.circular(AppRadius.chip), border: Border.all(color: selected ? AppColors.navy : AppColors.border)),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildInvoices() {
    final invoices = _data!['invoices'] as List<dynamic>? ?? [];
    if (invoices.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'لا توجد فواتير', message: 'ستظهر هنا كل الفواتير المُصدرة.');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.navy,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        itemBuilder: (context, i) {
          final inv = invoices[i] as Map<String, dynamic>;
          final student = inv['student'] as Map<String, dynamic>?;
          return AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv['description'] as String? ?? '—', style: AppTextStyles.cardTitle),
                      Text(student?['name'] as String? ?? '', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Text('\$${inv['amount'] ?? 0}', style: AppTextStyles.cardTitle),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProofs() {
    final proofs = _data!['paymentProofs'] as List<dynamic>? ?? [];
    if (proofs.isEmpty) return const EmptyState(icon: Icons.receipt_outlined, title: 'لا توجد إثباتات', message: 'ستظهر هنا إثباتات الدفع المرفوعة من الطلاب.');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.navy,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: proofs.length,
        itemBuilder: (context, i) {
        final proof = proofs[i] as Map<String, dynamic>;
        final student = proof['student'] as Map<String, dynamic>?;
        final status = proof['status'] as String? ?? 'pending';
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(student?['name'] as String? ?? '—', style: AppTextStyles.cardTitle)),
                  Text('\$${proof['amount'] ?? 0}', style: AppTextStyles.cardTitle),
                ],
              ),
              const SizedBox(height: 10),
              if (status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reviewProof(proof['_id'] as String, 'rejected'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                        child: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: PrimaryButton(label: 'قبول', onPressed: () => _reviewProof(proof['_id'] as String, 'approved'))),
                  ],
                )
              else
                StatusBadge(label: status == 'approved' ? 'موثّق' : 'مرفوض', color: status == 'approved' ? AppColors.success : AppColors.danger),
            ],
          ),
        );
        },
      ),
    );
  }
}

class AdminMarketingAssetsScreen extends StatefulWidget {
  const AdminMarketingAssetsScreen({super.key});

  @override
  State<AdminMarketingAssetsScreen> createState() => _AdminMarketingAssetsScreenState();
}

class _AdminMarketingAssetsScreenState extends State<AdminMarketingAssetsScreen> {
  List<dynamic> _assets = [];
  bool _loading = true;
  String? _error;

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
      final data = await AdminModulesRepository.instance.getMarketingAssets();
      if (!mounted) return;
      setState(() {
        _assets = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المواد التسويقية.';
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    try {
      await AdminModulesRepository.instance.deleteMarketingAsset(id);
      if (mounted) setState(() => _assets.removeWhere((a) => (a as Map<String, dynamic>)['_id'] == id));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الحذف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'المواد التسويقية',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _assets.isEmpty
                    ? const EmptyState(icon: Icons.campaign_outlined, title: 'لا توجد مواد', message: 'المواد التسويقية بترفع حاليًا من لوحة التحكم على الويب.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _assets.length,
                        itemBuilder: (context, i) {
                          final asset = _assets[i] as Map<String, dynamic>;
                          return AppCard(
                            child: Row(
                              children: [
                                Expanded(child: Text(asset['title'] as String? ?? asset['fileName'] as String? ?? '—', style: AppTextStyles.cardTitle)),
                                IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _delete(asset['_id'] as String)),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
