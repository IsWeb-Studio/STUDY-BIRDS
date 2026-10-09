import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/app_theme.dart';
import '../../core/repositories/agent_repository.dart';
import 'agent_dashboard_screen.dart' show agentStudentStatusMeta;

// ─── document type catalogue ──────────────────────────────────────────────────

class _DocType {
  final String key;
  final String label;
  final IconData icon;
  final bool isPassport;
  const _DocType(this.key, this.label, this.icon, {this.isPassport = false});
}

const _docTypes = [
  _DocType('passport', 'جواز السفر', Icons.chrome_reader_mode_rounded, isPassport: true),
  _DocType('id-card', 'بطاقة هوية', Icons.badge_rounded),
  _DocType('high-school-cert', 'شهادة الثانوية', Icons.school_rounded),
  _DocType('transcript', 'كشف الدرجات', Icons.list_alt_rounded),
  _DocType('personal-photo', 'صورة شخصية', Icons.photo_camera_rounded),
  _DocType('language-cert', 'شهادة اللغة', Icons.g_translate_rounded),
  _DocType('recommendation', 'خطاب توصية', Icons.mail_outline_rounded),
  _DocType('motivation-letter', 'خطاب الدافعية', Icons.edit_note_rounded),
  _DocType('bank-statement', 'كشف حساب بنكي', Icons.account_balance_outlined),
  _DocType('medical', 'شهادة طبية', Icons.medical_services_outlined),
  _DocType('other', 'أخرى', Icons.attach_file_rounded),
];

// ─── detail screen ─────────────────────────────────────────────────────────

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

  static const _stageLabels = {
    'initial': 'استشارة مبدئية',
    'documents': 'جمع الوثائق',
    'submitted': 'تم التقديم',
    'admission': 'القبول',
    'visa': 'التأشيرة',
    'enrolled': 'مسجّل',
  };

  String _stageLabelOf(String stage) => _stageLabels[stage] ?? stage;

  // ── step 1: pick document type ──────────────────────────────────────────

  Future<void> _startUploadFlow() async {
    final docType = await showModalBottomSheet<_DocType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DocTypeSheet(),
    );
    if (docType == null || !mounted) return;

    if (docType.key == 'other') {
      await _pickWithCustomLabel();
      return;
    }

    if (docType.isPassport) {
      await _passportFlow(docType);
    } else {
      await _genericPickFlow(docType);
    }
  }

  // ── passport: camera or file + confirm ─────────────────────────────────

  Future<void> _passportFlow(_DocType docType) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PassportSourceSheet(),
    );
    if (source == null || !mounted) return;

    List<int>? bytes;
    String? fileName;

    if (source == 'camera') {
      final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
      if (img == null) return;
      bytes = await img.readAsBytes();
      fileName = img.name;
    } else {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (res == null || res.files.isEmpty || res.files.single.bytes == null) return;
      bytes = res.files.single.bytes!;
      fileName = res.files.single.name;
    }

    if (!mounted) return;

    // verification step
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _PassportConfirmDialog(fileName: fileName!),
    );
    if (confirmed != true || !mounted) return;

    await _doUpload(bytes!, fileName!, docType.label);
  }

  // ── generic type: file picker only ─────────────────────────────────────

  Future<void> _genericPickFlow(_DocType docType) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.single.bytes == null) return;
    await _doUpload(res.files.single.bytes!, res.files.single.name, docType.label);
  }

  // ── other: user types own label ─────────────────────────────────────────

  Future<void> _pickWithCustomLabel() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.single.bytes == null) return;
    if (!mounted) return;

    final labelCtrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم المستند', style: AppTextStyles.cardTitle),
        content: TextField(
          controller: labelCtrl,
          autofocus: true,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(hintText: 'مثال: وثيقة التخرج'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = labelCtrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('رفع'),
          ),
        ],
      ),
    );
    if (label == null || !mounted) return;
    await _doUpload(res.files.single.bytes!, res.files.single.name, label);
  }

  // ── actual upload call ──────────────────────────────────────────────────

  Future<void> _doUpload(List<int> bytes, String fileName, String label) async {
    setState(() => _uploading = true);
    try {
      final updated = await AgentRepository.instance.uploadStudentDocument(
        studentId: widget.studentId,
        fileBytes: bytes,
        fileName: fileName,
        label: label,
      );
      if (!mounted) return;
      setState(() => _student = updated);
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: Text('تم رفع "$label" بنجاح'),
        backgroundColor: AppColors.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: Text('تعذر رفع المستند، حاول مرة أخرى'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── build ───────────────────────────────────────────────────────────────

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
          // header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'] as String? ?? '—',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(s['email'] as String? ?? '',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                    ],
                  ),
                ),
                StatusBadge(label: meta.label, color: meta.color),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // info section
          const Text('بيانات الطالب', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                _InfoRow(icon: Icons.phone_rounded, label: 'الهاتف', value: s['phone'] as String? ?? '—'),
                if ((s['country'] as String?)?.isNotEmpty == true) ...[
                  const _Divider(),
                  _InfoRow(icon: Icons.flag_rounded, label: 'بلد الدراسة', value: s['country'] as String),
                ],
                if ((s['desiredUniversity'] as String?)?.isNotEmpty == true) ...[
                  const _Divider(),
                  _InfoRow(icon: Icons.account_balance_rounded, label: 'الجامعة', value: s['desiredUniversity'] as String),
                ],
                if ((s['desiredProgram'] as String?)?.isNotEmpty == true) ...[
                  const _Divider(),
                  _InfoRow(icon: Icons.menu_book_rounded, label: 'البرنامج', value: s['desiredProgram'] as String),
                ],
                if ((s['applicationStage'] as String?) != null) ...[
                  const _Divider(),
                  _InfoRow(
                    icon: Icons.timeline_rounded,
                    label: 'المرحلة',
                    value: _stageLabelOf(s['applicationStage'] as String),
                    valueColor: AppColors.info,
                  ),
                ],
              ],
            ),
          ),

          if ((s['notes'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            const Text('ملاحظات', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 10),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s['notes'] as String, style: AppTextStyles.body)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // documents section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المستندات', style: AppTextStyles.sectionLabel),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${documents.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (documents.isEmpty)
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 36, color: AppColors.border),
                  const SizedBox(height: 8),
                  const Text('لا توجد مستندات مرفوعة بعد', style: AppTextStyles.caption),
                ],
              ),
            )
          else
            AppCard(
              child: Column(
                children: List.generate(documents.length, (i) {
                  final doc = documents[i] as Map<String, dynamic>;
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.navy),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc['label'] as String? ?? doc['fileName'] as String? ?? '—',
                                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                                  Text(doc['fileName'] as String? ?? '', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),

          const SizedBox(height: 16),
          PrimaryButton(
            label: _uploading ? 'جاري الرفع...' : 'رفع مستند للطالب',
            onPressed: _uploading ? null : _startUploadFlow,
            icon: Icons.upload_file_rounded,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── doc type bottom sheet ──────────────────────────────────────────────────

class _DocTypeSheet extends StatelessWidget {
  const _DocTypeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('اختر نوع المستند', style: AppTextStyles.cardTitle),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('حدد نوع المستند الذي تريد رفعه للطالب', style: AppTextStyles.caption),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
            children: _docTypes.map((t) {
              return GestureDetector(
                onTap: () => Navigator.pop(context, t),
                child: Container(
                  decoration: BoxDecoration(
                    color: t.isPassport ? AppColors.orangeSoft : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.isPassport ? AppColors.orange.withValues(alpha: 0.4) : AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon, size: 26, color: t.isPassport ? AppColors.orange : AppColors.navy),
                      const SizedBox(height: 6),
                      Text(t.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.isPassport ? AppColors.orange : AppColors.textPrimary), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── passport source sheet (camera vs file) ────────────────────────────────

class _PassportSourceSheet extends StatelessWidget {
  const _PassportSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('رفع صورة جواز السفر', style: AppTextStyles.cardTitle),
          const SizedBox(height: 6),
          const Text('اختر طريقة إضافة الجواز', style: AppTextStyles.caption),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'مسح ضوئي',
                  subtitle: 'التقط صورة بالكاميرا',
                  color: AppColors.navy,
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceOption(
                  icon: Icons.folder_open_rounded,
                  label: 'من الملفات',
                  subtitle: 'اختر من مستنداتك',
                  color: AppColors.info,
                  onTap: () => Navigator.pop(context, 'files'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SourceOption({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── passport confirm dialog ────────────────────────────────────────────────

class _PassportConfirmDialog extends StatelessWidget {
  final String fileName;
  const _PassportConfirmDialog({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: AppColors.navy, size: 22),
          SizedBox(width: 8),
          Text('تأكيد الجواز', style: AppTextStyles.cardTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, color: AppColors.navy, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(fileName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('قبل الرفع، تأكد من:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          ...const [
            '✅  الصفحة الأولى تحتوي الصورة والبيانات',
            '✅  جميع الأرقام واضحة وقابلة للقراءة',
            '✅  الجواز ساري المفعول',
          ].map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(t, style: AppTextStyles.caption.copyWith(fontSize: 12.5)),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إعادة الاختيار'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('نعم، الجواز صحيح — ارفع'),
        ),
      ],
    );
  }
}

// ─── shared helpers ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: valueColor), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 0.5);
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

// ─── commissions screen (unchanged logic, kept here) ───────────────────────

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
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AgentRepository.instance.getWallet();
      if (!mounted) return;
      setState(() { _wallet = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'تعذر تحميل بيانات المحفظة.'; _loading = false; });
    }
  }

  Future<void> _requestPayout() async {
    final summary = _wallet?['summary'] as Map<String, dynamic>? ?? {};
    final available = (summary['availableBalance'] as num?) ?? 0;
    if (available <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(content: Text('لا يوجد رصيد متاح للسحب حاليًا')));
      return;
    }
    try {
      await AgentRepository.instance.requestPayout(amount: available.toDouble(), method: 'bank-transfer', payoutDetails: 'تحويل بنكي — بيانات الوكيل المسجّلة');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(content: Text('تم إرسال طلب السحب بنجاح'), backgroundColor: AppColors.success));
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(content: Text('تعذر إرسال طلب السحب'), backgroundColor: AppColors.danger));
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
        // balance summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WalletStat(value: '\$${summary['availableBalance'] ?? 0}', label: 'متاح', color: Colors.greenAccent),
              _WalletStat(value: '\$${summary['pendingBalance'] ?? 0}', label: 'معلّق', color: Colors.orangeAccent),
              _WalletStat(value: '\$${summary['receivedBalance'] ?? 0}', label: 'مستلم', color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'طلب سحب الرصيد المتاح', onPressed: _requestPayout, icon: Icons.account_balance_wallet_outlined),
        const SizedBox(height: 20),
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
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: (isCredit ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: isCredit ? AppColors.success : AppColors.danger),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry['description'] as String? ?? (isCredit ? 'عمولة' : 'سحب'), style: AppTextStyles.body)),
                  Text('${isCredit ? '+' : '-'}\$${entry['amount'] ?? 0}', style: TextStyle(fontWeight: FontWeight.w700, color: isCredit ? AppColors.success : AppColors.danger)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _WalletStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _WalletStat({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}
