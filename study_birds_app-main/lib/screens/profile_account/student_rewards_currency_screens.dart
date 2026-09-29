import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import '../../core/currency_service.dart';

// ─── بند 53: مكافآت الطالب ────────────────────────────────────────────────────

class StudentRewardsScreen extends StatefulWidget {
  const StudentRewardsScreen({super.key});
  @override
  State<StudentRewardsScreen> createState() => _StudentRewardsScreenState();
}

class _StudentRewardsScreenState extends State<StudentRewardsScreen> {
  int _totalPoints = 0;
  List<dynamic> _entries = [];
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
      final data = await ApiClient.instance.get(
        '/students/rewards',
        token: AuthSession.instance.token,
      );
      if (!mounted) return;
      final map = data as Map<String, dynamic>;
      setState(() {
        _totalPoints = (map['totalPoints'] as num?)?.toInt() ?? 0;
        _entries = map['entries'] as List? ?? [];
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل المكافآت. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'مكافآتي',
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.navy,
          child: _loading
              ? const LoadingState(message: 'جاري تحميل المكافآت...')
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _PointsSummaryCard(totalPoints: _totalPoints),
                        const SizedBox(height: 20),
                        if (_entries.isEmpty)
                          const AppCard(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: EmptyState(
                                    icon: Icons.workspace_premium_outlined,
                                    title: 'لا توجد مكافآت بعد',
                                    message: 'ستظهر نقاطك هنا عند كسبها.'),
                              ),
                            ),
                          )
                        else ...[
                          const Text('سجل النقاط',
                              style: AppTextStyles.sectionLabel),
                          const SizedBox(height: 10),
                          for (final e in _entries)
                            if (e is Map)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _RewardEntryCard(entry: e),
                              ),
                        ],
                      ],
                    ),
        ),
      );
}

class _PointsSummaryCard extends StatelessWidget {
  final int totalPoints;
  const _PointsSummaryCard({required this.totalPoints});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, Color(0xFF3D7DC8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text('$totalPoints',
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy)),
          const Text('نقطة', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          const Text('إجمالي نقاط المكافآت',
              style: AppTextStyles.body, textAlign: TextAlign.center),
        ]),
      );
}

class _RewardEntryCard extends StatelessWidget {
  final Map entry;
  const _RewardEntryCard({required this.entry});

  static const _typeLabels = {
    'referral': 'إحالة',
    'stage': 'مرحلة',
    'bonus': 'مكافأة',
    'admin': 'منحة إدارية',
  };

  static const _typeColors = {
    'referral': AppColors.success,
    'stage': AppColors.navy,
    'bonus': AppColors.orange,
    'admin': AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final type = '${entry['type'] ?? 'admin'}';
    final points = (entry['points'] as num?)?.toInt() ?? 0;
    final desc = '${entry['description'] ?? ''}';
    final date = _fmtDate(entry['createdAt']);
    final color = _typeColors[type] ?? AppColors.textSecondary;
    final label = _typeLabels[type] ?? type;

    return AppCard(
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.add_circle_outline_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(desc, style: AppTextStyles.cardTitle),
          const SizedBox(height: 2),
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
            if (date.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(date, style: AppTextStyles.caption),
            ],
          ]),
        ])),
        const SizedBox(width: 8),
        Text('+$points نق.',
            style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ]),
    );
  }

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ─── بند 74: تحويل العملات ───────────────────────────────────────────────────

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});
  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  String _from = 'USD';
  String _to = 'TRY';
  final _controller = TextEditingController(text: '1000');
  Map<String, double>? _rates;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _from = CurrencyService.instance.selected;
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rates = await CurrencyService.instance.fetchRates(_from);
      if (mounted) setState(() => _rates = rates);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر جلب أسعار الصرف.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
      _rates = null;
    });
    _fetchRates();
  }

  double get _result {
    final amount = double.tryParse(_controller.text) ?? 0;
    if (_rates == null) return 0;
    return amount * (_rates![_to] ?? 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'تحويل العملات',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('المبلغ', style: AppTextStyles.sectionLabel),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'أدخل المبلغ',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.card)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _CurrencyDropdown(
                    label: 'من',
                    value: _from,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _from = v;
                        _rates = null;
                      });
                      _fetchRates();
                    },
                  )),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                        onPressed: _swap,
                        icon: const Icon(Icons.swap_horiz_rounded,
                            color: AppColors.navy)),
                  ),
                  Expanded(child: _CurrencyDropdown(
                    label: 'إلى',
                    value: _to,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _to = v);
                    },
                  )),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: _loading
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: AppColors.navy)))
                  : _error != null
                      ? Column(children: [
                          Text(_error!, style: AppTextStyles.caption),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: _fetchRates,
                              child: const Text('إعادة المحاولة')),
                        ])
                      : Column(children: [
                          Text(
                            '${_controller.text.isEmpty ? '0' : _controller.text} $_from',
                            style: AppTextStyles.body,
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary),
                          Text(
                            '${_result.toStringAsFixed(2)} $_to',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy),
                          ),
                          if (_rates != null)
                            Text(
                              '1 $_from = ${(_rates![_to] ?? 0).toStringAsFixed(4)} $_to',
                              style: AppTextStyles.caption,
                            ),
                        ]),
            ),
            const SizedBox(height: 16),
            if (_rates != null) ...[
              const Text('جميع العملات', style: AppTextStyles.sectionLabel),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  children: supportedCurrencies.keys
                      .where((c) => c != _from)
                      .map((c) {
                    final amount = double.tryParse(_controller.text) ?? 1;
                    final converted = amount * (_rates![c] ?? 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                supportedCurrencies[c] ?? c,
                                style: AppTextStyles.body)),
                        Text('${converted.toStringAsFixed(2)} $c',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      );
}

class _CurrencyDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String?> onChanged;
  const _CurrencyDropdown(
      {required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: supportedCurrencies.keys
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      );
}

// ─── بند 54: المحفظة الإلكترونية ─────────────────────────────────────────────

class StudentWalletScreen extends StatefulWidget {
  const StudentWalletScreen({super.key});
  @override
  State<StudentWalletScreen> createState() => _StudentWalletScreenState();
}

class _StudentWalletScreenState extends State<StudentWalletScreen> {
  Map<String, dynamic>? _data;
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
      final data = await ApiClient.instance.get(
        '/students/wallet',
        token: AuthSession.instance.token,
      );
      if (!mounted) return;
      setState(() => _data = data as Map<String, dynamic>);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل المحفظة. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showRedeemSheet() async {
    final balance = (_data?['balance'] as num?)?.toDouble() ?? 0;
    List<dynamic> unpaidInvoices = [];
    try {
      final fin = await ApiClient.instance.get('/students/financials', token: AuthSession.instance.token) as Map;
      unpaidInvoices = ((fin['invoices'] as List?) ?? [])
          .where((i) => (i as Map)['status'] == 'unpaid')
          .toList();
    } catch (_) {}

    if (!mounted) return;
    if (unpaidInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد فواتير غير مدفوعة حاليًا.')));
      return;
    }

    Map<String, dynamic>? selectedInvoice;
    final amountCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('استخدام رصيد المحفظة', style: AppTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text('رصيدك المتاح: ${balance.toStringAsFixed(0)} نقطة', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          const Text('اختر الفاتورة', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 8),
          for (final inv in unpaidInvoices) ...[
            GestureDetector(
              onTap: () => setSheet(() => selectedInvoice = inv as Map<String, dynamic>),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selectedInvoice?['_id'] == (inv as Map)['_id']
                      ? AppColors.navy.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: selectedInvoice?['_id'] == inv['_id']
                        ? AppColors.navy
                        : AppColors.border),
                ),
                child: Row(children: [
                  Icon(
                    selectedInvoice?['_id'] == inv['_id']
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 20,
                    color: selectedInvoice?['_id'] == inv['_id']
                        ? AppColors.navy
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    '${inv['description'] ?? 'فاتورة'} — ${inv['amount']} ${inv['currency'] ?? ''}',
                    style: AppTextStyles.body)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ المراد خصمه (دولار)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: PrimaryButton(
            label: 'تأكيد الخصم',
            onPressed: () async {
              final inv = selectedInvoice;
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (inv == null || amount <= 0) {
                ScaffoldMessenger.of(ctx2).showSnackBar(
                  const SnackBar(content: Text('اختر فاتورة وأدخل مبلغاً صحيحاً.')));
                return;
              }
              final nav = Navigator.of(ctx2);
              final messenger = ScaffoldMessenger.of(ctx2);
              try {
                await ApiClient.instance.post('/students/wallet/redeem',
                    token: AuthSession.instance.token,
                    body: { 'invoiceId': inv['_id'], 'amount': amount });
                nav.pop();
                await _load();
                messenger.showSnackBar(const SnackBar(content: Text('تم خصم الرصيد بنجاح.')));
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e is ApiException ? e.message : 'تعذر تنفيذ الخصم.')));
              }
            },
          )),
          const SizedBox(height: 20),
        ]),
      )),
    );
    amountCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'محفظتي',
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.navy,
          child: _loading
              ? const LoadingState(message: 'جاري تحميل المحفظة...')
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : _buildBody(),
        ),
      );

  Widget _buildBody() {
    final d = _data!;
    final balance = (d['balance'] as num?)?.toDouble() ?? 0;
    final referralCode = '${d['referralCode'] ?? ''}';
    final referrals = (d['referrals'] as List?) ?? [];
    final transactions = (d['transactions'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _WalletBalanceCard(balance: balance, referralCode: referralCode, onRedeem: balance > 0 ? _showRedeemSheet : null),
        const SizedBox(height: 20),
        if (referrals.isNotEmpty) ...[
          const Text('إحالاتك', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                for (int i = 0; i < referrals.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _ReferralRow(referral: referrals[i] as Map),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const Text('حركات المحفظة', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'لا توجد حركات بعد',
                  message: 'ستظهر هنا عمليات الإضافة والخصم من محفظتك.',
                ),
              ),
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (int i = 0; i < transactions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _TransactionRow(tx: transactions[i] as Map),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  final double balance;
  final String referralCode;
  final VoidCallback? onRedeem;
  const _WalletBalanceCard({required this.balance, required this.referralCode, this.onRedeem});

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, Color(0xFF3D7DC8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            balance.toStringAsFixed(2),
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const Text('نقطة رصيد', style: AppTextStyles.caption),
          if (referralCode.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('كود الإحالة الخاص بك', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: referralCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الكود')),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(referralCode,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                          letterSpacing: 2)),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.navy),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () {
                  final msg = Uri.encodeComponent(
                      'سجّل في Study Birds باستخدام كود الإحالة الخاص بي: $referralCode 🎓\nhttps://studybirds.app');
                  launchUrl(
                    Uri.parse('https://wa.me/?text=$msg'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('مشاركة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
              )),
              if (onRedeem != null) ...[
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: onRedeem,
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: const Text('استخدام الرصيد'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.navy),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                )),
              ],
            ]),
          ],
        ]),
      );
}

class _ReferralRow extends StatelessWidget {
  final Map referral;
  const _ReferralRow({required this.referral});

  @override
  Widget build(BuildContext context) {
    final name = '${referral['name'] ?? 'طالب'}';
    final status = '${referral['status'] ?? 'pending'}';
    final date = _fmtDate(referral['createdAt']);
    final isQualified = status == 'qualified';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              (isQualified ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
          child: Icon(
            isQualified ? Icons.check_rounded : Icons.hourglass_top_rounded,
            size: 18,
            color: isQualified ? AppColors.success : AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: AppTextStyles.cardTitle),
          if (date.isNotEmpty) Text(date, style: AppTextStyles.caption),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isQualified ? AppColors.success : AppColors.warning)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isQualified ? 'مؤهّل' : 'قيد الانتظار',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isQualified ? AppColors.success : AppColors.warning),
          ),
        ),
      ]),
    );
  }

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _TransactionRow extends StatelessWidget {
  final Map tx;
  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final direction = '${tx['direction'] ?? 'credit'}';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final notes = '${tx['notes'] ?? ''}';
    final date = _fmtDate(tx['createdAt']);
    final isCredit = direction == 'credit';
    final color = isCredit ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isCredit ? Icons.add_rounded : Icons.remove_rounded,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            notes.isNotEmpty ? notes : (isCredit ? 'إضافة رصيد' : 'خصم رصيد'),
            style: AppTextStyles.body,
          ),
          if (date.isNotEmpty) Text(date, style: AppTextStyles.caption),
        ])),
        Text(
          '${isCredit ? '+' : '-'}${amount.toStringAsFixed(0)}',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ]),
    );
  }

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}
