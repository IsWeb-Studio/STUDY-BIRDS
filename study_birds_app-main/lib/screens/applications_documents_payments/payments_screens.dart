import 'package:url_launcher/url_launcher.dart';
import '../../core/document_access.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_theme.dart';
import '../../core/student_repository.dart';
import '../../core/notification_scheduler.dart';
import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/currency_service.dart';

class InvoiceStatusMeta {
  final String label;
  final Color color;
  const InvoiceStatusMeta(this.label, this.color);
}

InvoiceStatusMeta invoiceStatusMeta(String? status) {
  switch (status) {
    case 'paid':
      return const InvoiceStatusMeta('مدفوعة', AppColors.success);
    case 'pending-confirmation':
      return const InvoiceStatusMeta('قيد التحقق', AppColors.info);
    case 'rejected':
      return const InvoiceStatusMeta('مرفوضة', AppColors.danger);
    case 'unpaid':
    default:
      return const InvoiceStatusMeta('مستحقة', AppColors.warning);
  }
}

InvoiceStatusMeta paymentProofStatusMeta(String? status) {
  switch (status) {
    case 'approved':
      return const InvoiceStatusMeta('موثّقة', AppColors.success);
    case 'rejected':
      return const InvoiceStatusMeta('مرفوضة', AppColors.danger);
    case 'pending':
    default:
      return const InvoiceStatusMeta('قيد المراجعة', AppColors.info);
  }
}

String _money(num? amount) => CurrencyService.instance.formatAmount(amount);

class PaymentsSummaryScreen extends StatefulWidget {
  const PaymentsSummaryScreen({super.key});

  @override
  State<PaymentsSummaryScreen> createState() => _PaymentsSummaryScreenState();
}

class _PaymentsSummaryScreenState extends State<PaymentsSummaryScreen> {
  Map<String, dynamic>? _financials;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('payments_summary');
    CurrencyService.instance.refreshRatesInBackground();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StudentRepository.instance.getFinancials();
      if (!mounted) return;
      setState(() {
        _financials = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات المدفوعات.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'ملخص الدفعات',
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white),
          tooltip: 'سجل الدفعات',
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _buildContent(context, _financials!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> financials) {
    final summary = financials['summary'] as Map<String, dynamic>? ?? {};
    final invoices = financials['invoices'] as List<dynamic>? ?? [];
    final remainingFees = summary['remainingFees'] as num?;
    final totalProgramFees = summary['totalProgramFees'] as num?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryStat(
                  label: 'المدفوع',
                  value: _money(summary['paidAmount'] as num?),
                  color: AppColors.success),
              _SummaryStat(
                  label: 'قيد التحقق',
                  value: _money(summary['pendingConfirmationAmount'] as num?),
                  color: AppColors.info),
              _SummaryStat(
                  label: 'المتبقي',
                  value: remainingFees != null ? _money(remainingFees) : _money(summary['outstandingAmount'] as num?),
                  color: remainingFees == 0 ? AppColors.success : AppColors.warning),
            ],
          ),
        ),
        if (totalProgramFees != null && totalProgramFees > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'إجمالي الرسوم الدراسية: ${_money(totalProgramFees)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.navy),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 8),
        const Text('الفواتير', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        if (invoices.isEmpty)
          const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'لا توجد فواتير بعد',
              message: 'ستظهر هنا أي فواتير أو دفعات مطلوبة منك.')
        else
          ...invoices.map((inv) {
            final invoice = inv as Map<String, dynamic>;
            final meta = invoiceStatusMeta(invoice['status'] as String?);
            return AppCard(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => PaymentDetailScreen(invoice: invoice)))
                  .then((_) => _load()),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invoice['description'] as String? ?? '—',
                            style: AppTextStyles.cardTitle),
                        const SizedBox(height: 3),
                        Text(invoice['invoiceNumber'] as String? ?? '',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_money(invoice['amount'] as num?),
                          style: AppTextStyles.cardTitle),
                      const SizedBox(height: 4),
                      StatusBadge(label: meta.label, color: meta.color),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SummaryStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.screenTitle
                .copyWith(color: color ?? AppColors.navy, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class PaymentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  const PaymentDetailScreen({super.key, required this.invoice});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> with WidgetsBindingObserver {
  bool _uploading = false;
  bool _paying = false;
  bool _stripeEnabled = false;
  late Map<String, dynamic> _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    WidgetsBinding.instance.addObserver(this);
    _loadPaymentAvailability();
    AnalyticsService.instance.paymentInitiated(
        '${widget.invoice['_id'] ?? ''}',
        widget.invoice['amount']?.toDouble() ?? 0.0);
    _schedulePaymentReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshInvoice();
  }

  Future<void> _loadPaymentAvailability() async {
    try {
      final status = await ApiClient.instance.get('/payments/stripe/status');
      if (mounted) setState(() => _stripeEnabled = status is Map && status['enabled'] == true);
    } catch (_) { /* Bank transfer remains available when card payment is disabled. */ }
  }

  Future<void> _refreshInvoice() async {
    try {
      final data = await StudentRepository.instance.getFinancials(forceRefresh: true);
      final matches = (data['invoices'] as List? ?? []).whereType<Map>().where((row) => row['_id'] == _invoice['_id']);
      if (mounted && matches.isNotEmpty) {
        setState(() => _invoice = Map<String, dynamic>.from(matches.first));
        if (_invoice['status'] == 'paid') await NotificationScheduler.instance.cancel('payment:${_invoice['_id']}');
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديث حالة الدفع. حاول مجددًا.')));
    }
  }

  Future<void> _payByCard() async {
    setState(() => _paying = true);
    try {
      final result = await ApiClient.instance.post('/payments/stripe/checkout', token: AuthSession.instance.token, body: {'invoiceId': _invoice['_id']});
      final uri = Uri.parse('${result['url']}');
      if (uri.scheme != 'https' || uri.host != 'checkout.stripe.com' || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const ApiException(0, 'تعذر فتح صفحة الدفع');
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is ApiException ? error.message : 'تعذر بدء الدفع. حاول مجددًا.')));
    } finally { if (mounted) setState(() => _paying = false); }
  }

  void _schedulePaymentReminder() {
    final inv = widget.invoice;
    final id = '${inv['_id'] ?? ''}';
    final dueRaw = inv['dueDate'] ?? inv['due_date'];
    final due = DateTime.tryParse('$dueRaw');
    final status = '${inv['status'] ?? ''}';
    if (id.isEmpty || due == null) return;
    if (status == 'verified' || status == 'paid') return;
    final amount = inv['amount']?.toString() ?? '';
    NotificationScheduler.instance.schedulePaymentDue(
      invoiceId: id,
      amount: amount,
      dueDate: due,
    );
  }

  Future<void> _uploadProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      await StudentRepository.instance.uploadPaymentProof(
        invoiceId: widget.invoice['_id'] as String,
        fileBytes: file.bytes!,
        fileName: file.name,
        amount: (widget.invoice['amount'] as num?)?.toDouble(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم رفع إيصال الدفع بنجاح'),
          backgroundColor: AppColors.success));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر رفع الإيصال، حاول مرة أخرى'),
          backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    final meta = invoiceStatusMeta(invoice['status'] as String?);
    final canUpload =
        invoice['status'] == 'unpaid' || invoice['status'] == 'rejected';

    return AppScaffold(
      title: 'تفاصيل الدفعة',
      actions: [IconButton(onPressed: _refreshInvoice, icon: const Icon(Icons.refresh), tooltip: 'تحديث حالة الدفع')],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Text('${invoice['amount'] ?? 0} ${invoice['currency'] ?? 'USD'}',
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy))),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                children: [
                  _DetailRow(
                      label: 'الوصف',
                      value: invoice['description'] as String? ?? '—'),
                  const Divider(height: 20),
                  _DetailRow(
                      label: 'رقم الفاتورة',
                      value: invoice['invoiceNumber'] as String? ?? '—'),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الحالة', style: AppTextStyles.caption),
                      StatusBadge(label: meta.label, color: meta.color)
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_stripeEnabled && invoice['status'] == 'unpaid') ...[
              PrimaryButton(label: _paying ? 'جاري فتح الدفع...' : 'الدفع بالبطاقة', onPressed: _paying ? null : _payByCard, icon: Icons.credit_card),
              const SizedBox(height: 12),
            ],
            if (canUpload)
              PrimaryButton(
                label: _uploading ? 'جاري الرفع...' : 'رفع إيصال الدفع',
                onPressed: _uploading ? null : _uploadProof,
                icon: Icons.upload_file_rounded,
              )
            else
              const AppCard(
                  child: Text(
                      'لا يوجد إجراء مطلوب — هذه الفاتورة قيد المراجعة أو مدفوعة بالفعل.',
                      style: AppTextStyles.caption)),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Flexible(
            child: Text(value,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<dynamic> _proofs = [];
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
      final data = await StudentRepository.instance.getFinancials();
      if (!mounted) return;
      setState(() {
        _proofs = data['paymentProofs'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل سجل الدفعات.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'سجل الدفعات',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _proofs.isEmpty
                    ? const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'لا يوجد سجل بعد',
                        message: 'ستظهر هنا كل إيصالات الدفع اللي رفعتها.')
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _proofs.length,
                      itemBuilder: (context, i) {
                        final p = _proofs[i] as Map<String, dynamic>;
                        final meta =
                            paymentProofStatusMeta(p['status'] as String?);
                        final invoice = p['invoice'] as Map<String, dynamic>?;
                        return AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        invoice?['description'] as String? ??
                                            p['fileName'] as String? ??
                                            '—',
                                        style: AppTextStyles.cardTitle),
                                    Text(
                                        (p['createdAt'] as String?)
                                                ?.split('T')
                                                .first ??
                                            '—',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_money(p['amount'] as num?),
                                      style: AppTextStyles.cardTitle),
                                  const SizedBox(height: 4),
                                  StatusBadge(
                                      label: meta.label, color: meta.color),
                                  if (p['filePath'] is String)
                                    IconButton(
                                        tooltip: 'فتح إثبات الدفع',
                                        icon:
                                            const Icon(Icons.download_rounded),
                                        onPressed: () async {
                                          try {
                                            final uri =
                                                await resolveDocumentDownload(
                                                    p['filePath'] as String);
                                            if (!await launchUrl(uri,
                                                mode: LaunchMode
                                                    .externalApplication))
                                              throw Exception(
                                                  'Cannot open file');
                                          } catch (_) {
                                            if (context.mounted)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          'تعذر فتح إثبات الدفع. تحقق من الجلسة والصلاحيات.')));
                                          }
                                        }),
                                ],
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
