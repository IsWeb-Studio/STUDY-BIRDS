import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_theme.dart';
import '../../core/agent_repository.dart';
import 'agent_dashboard_screen.dart' show agentStudentStatusMeta;

class AgentStudentDetailScreen extends StatefulWidget {
  final String studentId;
  final Map<String, dynamic> initialData;
  const AgentStudentDetailScreen({super.key, required this.studentId, required this.initialData});

  @override
  State<AgentStudentDetailScreen> createState() => _AgentStudentDetailScreenState();
}

class _AgentStudentDetailScreenState extends State<AgentStudentDetailScreen> {
  late Map<String, dynamic> _student;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _student = widget.initialData;
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      final updated = await AgentRepository.instance.uploadStudentDocument(
        studentId: widget.studentId,
        fileBytes: file.bytes!,
        fileName: file.name,
        label: file.name,
      );
      if (!mounted) return;
      setState(() => _student = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع المستند بنجاح'), backgroundColor: AppColors.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر رفع المستند'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _student;
    final meta = agentStudentStatusMeta(s['applicationStatus'] as String?);
    final documents = s['documents'] as List<dynamic>? ?? [];

    return AppScaffold(
      title: s['name'] as String? ?? 'طالب',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(radius: 26, backgroundColor: AppColors.border, child: Icon(Icons.person_rounded, color: AppColors.navy)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'] as String? ?? '—', style: AppTextStyles.cardTitle),
                      Text(s['desiredUniversity'] as String? ?? s['email'] as String? ?? '', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                StatusBadge(label: meta.label, color: meta.color),
              ],
            ),
          ),
          const Text('بيانات التواصل', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                _MiniRow(label: 'البريد الإلكتروني', value: s['email'] as String? ?? '—'),
                const Divider(height: 20),
                _MiniRow(label: 'الهاتف', value: s['phone'] as String? ?? '—'),
                if ((s['desiredProgram'] as String?)?.isNotEmpty == true) ...[
                  const Divider(height: 20),
                  _MiniRow(label: 'البرنامج المطلوب', value: s['desiredProgram'] as String),
                ],
              ],
            ),
          ),
          if ((s['notes'] as String?)?.isNotEmpty == true) ...[
            const Text('ملاحظات', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            AppCard(child: Text(s['notes'] as String, style: AppTextStyles.body)),
          ],
          const Text('المستندات', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          if (documents.isEmpty)
            const AppCard(child: Text('لا توجد مستندات مرفوعة بعد.', style: AppTextStyles.caption))
          else
            AppCard(
              child: Column(
                children: documents.map((d) {
                  final doc = d as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.navy),
                        const SizedBox(width: 10),
                        Expanded(child: Text(doc['label'] as String? ?? doc['fileName'] as String? ?? '—', style: AppTextStyles.body)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: _uploading ? 'جاري الرفع...' : 'رفع مستند نيابةً عنه',
            onPressed: _uploading ? null : _uploadDocument,
            icon: Icons.upload_file_rounded,
          ),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  final String label;
  final String value;
  const _MiniRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Flexible(child: Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class MyCommissionsScreen extends StatefulWidget {
  const MyCommissionsScreen({super.key});

  @override
  State<MyCommissionsScreen> createState() => _MyCommissionsScreenState();
}

class _MyCommissionsScreenState extends State<MyCommissionsScreen> {
  Map<String, dynamic>? _wallet;
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
      final data = await AgentRepository.instance.getWallet();
      if (!mounted) return;
      setState(() {
        _wallet = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات المحفظة.';
        _loading = false;
      });
    }
  }

  Future<void> _requestPayout() async {
    final summary = _wallet?['summary'] as Map<String, dynamic>? ?? {};
    final available = (summary['availableBalance'] as num?) ?? 0;
    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رصيد متاح للسحب حاليًا')));
      return;
    }
    try {
      await AgentRepository.instance.requestPayout(amount: available.toDouble(), method: 'bank-transfer', payoutDetails: 'تحويل بنكي — بيانات الوكيل المسجّلة');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب السحب بنجاح'), backgroundColor: AppColors.success));
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال طلب السحب'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'محفظتي',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري تحميل المحفظة...')
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _buildContent(context, _wallet!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> wallet) {
    final summary = wallet['summary'] as Map<String, dynamic>? ?? {};
    final entries = wallet['entries'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(value: '\$${summary['availableBalance'] ?? 0}', label: 'متاح للسحب'),
              _Stat(value: '\$${summary['pendingBalance'] ?? 0}', label: 'قيد المعالجة'),
              _Stat(value: '\$${summary['receivedBalance'] ?? 0}', label: 'مستلم بالفعل'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'طلب سحب الرصيد المتاح', onPressed: _requestPayout, icon: Icons.account_balance_wallet_outlined),
        const SizedBox(height: 16),
        const Text('سجل الحركات', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          const EmptyState(icon: Icons.receipt_long_outlined, title: 'لا يوجد سجل بعد', message: 'ستظهر هنا عمولاتك أول ما تتحقق.')
        else
          ...entries.map((e) {
            final entry = e as Map<String, dynamic>;
            final isCredit = entry['direction'] == 'credit';
            return AppCard(
              child: Row(
                children: [
                  Expanded(child: Text(entry['description'] as String? ?? (isCredit ? 'عمولة' : 'سحب'), style: AppTextStyles.cardTitle)),
                  Text('${isCredit ? '+' : '-'}\$${entry['amount'] ?? 0}', style: TextStyle(fontWeight: FontWeight.w700, color: isCredit ? AppColors.success : AppColors.danger)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.screenTitle.copyWith(fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
