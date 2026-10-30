import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/admin_modules_repository.dart';

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
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/roles/admin_financials_marketing_screens.dart:38');
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
        final proofs = (Json.list(_data!['paymentProofs'])).map((p) => (Json.map(p))['_id'] == id ? updated : p).toList();
        _data = {..._data!, 'paymentProofs': proofs};
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(content: Text(e is ApiException ? e.message : 'تعذر التحديث')));
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
    final invoices = Json.listOrNull(_data!['invoices']) ?? [];
    if (invoices.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'لا توجد فواتير', message: 'ستظهر هنا كل الفواتير المُصدرة.');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.navy,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        itemBuilder: (context, i) {
          final inv = Json.map(invoices[i]);
          final student = Json.mapOrNull(inv['student']);
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
    final proofs = Json.listOrNull(_data!['paymentProofs']) ?? [];
    if (proofs.isEmpty) return const EmptyState(icon: Icons.receipt_outlined, title: 'لا توجد إثباتات', message: 'ستظهر هنا إثباتات الدفع المرفوعة من الطلاب.');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.navy,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: proofs.length,
        itemBuilder: (context, i) {
        final proof = Json.map(proofs[i]);
        final student = Json.mapOrNull(proof['student']);
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
  final _assetTitle = TextEditingController();
  final _assetDescription = TextEditingController();
  final _assetType = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _assetTitle.dispose();
    _assetDescription.dispose();
    _assetType.dispose();
    super.dispose();
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
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/roles/admin_financials_marketing_screens.dart:211');
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المواد التسويقية.';
        _loading = false;
      });
    }
  }

  Future<void> _editAsset({Map<String, dynamic>? asset}) async {
    _assetTitle.text = '${asset?['title'] ?? ''}';
    _assetDescription.text = '${asset?['description'] ?? ''}';
    _assetType.text = '${asset?['type'] ?? ''}';
    bool published = asset?['published'] != false;
    PlatformFile? file;
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(asset == null ? 'إضافة مادة تسويقية' : 'تعديل مادة تسويقية', style: AppTextStyles.cardTitle),
                const SizedBox(height: 12),
                TextField(controller: _assetTitle, decoration: const InputDecoration(labelText: 'اسم المادة')),
                const SizedBox(height: 8),
                TextField(controller: _assetType, decoration: const InputDecoration(labelText: 'النوع')),
                const SizedBox(height: 8),
                TextField(controller: _assetDescription, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'الوصف')),
                if (asset == null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'txt', 'jpg', 'jpeg', 'png', 'webp'],
                        withData: true,
                      );
                      if (!sheetContext.mounted) return;
                      if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
                      if (result.files.single.size > 5 * 1024 * 1024) {
                        setSheetState(() => error = 'الحد الأقصى لحجم الملف 5 ميغابايت.');
                        return;
                      }
                      setSheetState(() { file = result.files.single; error = null; });
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(file?.name ?? 'اختيار الملف'),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: published,
                  onChanged: saving ? null : (value) => setSheetState(() => published = value),
                  title: const Text('نشر المادة للشركاء'),
                ),
                if (error != null) Text(error!, style: const TextStyle(color: AppColors.danger)),
                PrimaryButton(
                  label: saving ? 'جارٍ الحفظ...' : 'حفظ',
                  onPressed: saving ? null : () async {
                    if (_assetTitle.text.trim().isEmpty || _assetType.text.trim().isEmpty || (asset == null && file == null)) {
                      setSheetState(() => error = 'أدخل الاسم والنوع واختر ملفًا للمادة الجديدة.');
                      return;
                    }
                    setSheetState(() { saving = true; error = null; });
                    try {
                      final repository = AdminModulesRepository.instance;
                      if (asset == null) {
                        await repository.createMarketingAsset(
                          title: _assetTitle.text.trim(),
                          description: _assetDescription.text.trim(),
                          type: _assetType.text.trim(),
                          published: published,
                          fileBytes: file!.bytes!,
                          fileName: file!.name,
                        );
                      } else {
                        await repository.updateMarketingAsset(
                          '${asset['_id']}',
                          title: _assetTitle.text.trim(),
                          description: _assetDescription.text.trim(),
                          type: _assetType.text.trim(),
                          published: published,
                        );
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      await _load();
                    } catch (saveError) {
                      if (sheetContext.mounted) {
                        setSheetState(() { saving = false; error = 'تعذر حفظ المادة: $saveError'; });
                      }
                    }
                  },
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    try {
      await AdminModulesRepository.instance.deleteMarketingAsset(id);
      if (mounted) setState(() => _assets.removeWhere((a) => (Json.map(a))['_id'] == id));
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/roles/admin_financials_marketing_screens.dart:224');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(content: const Text('تعذر الحذف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'المواد التسويقية',
      actions: [IconButton(tooltip: 'إضافة مادة', onPressed: () => _editAsset(), icon: const Icon(Icons.add_rounded))],
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
                          final asset = Json.map(_assets[i]);
                          return AppCard(
                            child: Row(
                              children: [
                                Expanded(child: Text(asset['title'] as String? ?? asset['fileName'] as String? ?? '—', style: AppTextStyles.cardTitle)),
                                IconButton(tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined), onPressed: () => _editAsset(asset: asset)),
                                IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _delete(asset['_id'] as String)),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
