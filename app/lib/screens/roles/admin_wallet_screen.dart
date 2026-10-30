import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_theme.dart';
import '../../core/repositories/admin_modules_repository.dart';
import '../../core/utils/json_safe.dart';
import '../../core/utils/form_input_validation.dart';

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});
  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  final _repo = AdminModulesRepository.instance;
  final _studentId = TextEditingController();
  final _filterId = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  List<Map<String, dynamic>> _entries = [];
  String _direction = 'credit';
  bool _loading = true, _busy = false;
  String? _error, _success;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _studentId.dispose();
    _filterId.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await _repo.getWalletEntries(studentId: _filterId.text.trim());
      if (mounted) {
        setState(() => _entries = rows
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _record() async {
    final student = _studentId.text.trim();
    final amount = double.tryParse(
        FormInputValidators.normalizeDecimal(_amount.text).trim());
    final notes = _notes.text.trim();
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(student)) {
      setState(() => _error = _ar
          ? 'أدخل معرّف طالب صحيحًا (24 رمزًا).'
          : 'Enter a valid student ID (24 characters).');
      return;
    }
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        (amount * 100).truncateToDouble() != amount * 100) {
      setState(() => _error = _ar
          ? 'أدخل مبلغًا موجبًا حتى منزلتين عشريتين.'
          : 'Enter a positive amount with at most two decimal places.');
      return;
    }
    if (notes.isEmpty || notes.length > 500) {
      setState(() => _error = _ar
          ? 'أدخل سبب التسوية (حتى 500 حرف).'
          : 'Enter a reason (up to 500 characters).');
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: _ar ? 'تأكيد التسوية المالية' : 'Confirm wallet adjustment',
      message: _ar
          ? 'سيتم ${_direction == 'credit' ? 'إضافة' : 'خصم'} $amount من محفظة الطالب. راجع المعرّف والسبب قبل المتابعة.'
          : '${_direction == 'credit' ? 'Credit' : 'Debit'} $amount from this student wallet. Check the ID and reason before continuing.',
      confirmLabel: _ar ? 'تسجيل التسوية' : 'Record adjustment',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await _repo.createWalletAdjustment(
          studentId: student,
          direction: _direction,
          amount: amount,
          notes: notes);
      _studentId.clear();
      _amount.clear();
      _notes.clear();
      setState(
          () => _success = _ar ? 'تم تسجيل التسوية.' : 'Adjustment recorded.');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return AppScaffold(
      title: ar ? 'محافظ الطلاب' : 'Student wallets',
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(
              ar
                  ? 'التسويات اليدوية وسجل معاملات المحفظة.'
                  : 'Manual adjustments and the wallet transaction log.',
              style: AppTextStyles.body),
          if (_error != null) _WalletNotice(message: _error!, error: true),
          if (_success != null) _WalletNotice(message: _success!),
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(ar ? 'تسوية يدوية' : 'Manual adjustment',
                            style: AppTextStyles.sectionLabel),
                        const SizedBox(height: 8),
                        TextField(
                            controller: _studentId,
                            maxLength: 24,
                            decoration: InputDecoration(
                                labelText: ar ? 'معرّف الطالب' : 'Student ID')),
                        DropdownButtonFormField<String>(
                          initialValue: _direction,
                          decoration: InputDecoration(
                              labelText: ar ? 'النوع' : 'Direction'),
                          items: [
                            DropdownMenuItem(
                                value: 'credit',
                                child: Text(ar ? 'إضافة رصيد' : 'Credit')),
                            DropdownMenuItem(
                                value: 'debit',
                                child: Text(ar ? 'خصم رصيد' : 'Debit')),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _direction = value ?? 'credit'),
                        ),
                        TextField(
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9٠-٩۰-۹.]'))
                            ],
                            decoration: InputDecoration(
                                labelText: ar ? 'المبلغ' : 'Amount')),
                        TextField(
                            controller: _notes,
                            maxLength: 500,
                            maxLines: 2,
                            decoration: InputDecoration(
                                labelText: ar ? 'السبب' : 'Reason')),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                            onPressed: _busy ? null : _record,
                            icon: const Icon(
                                Icons.account_balance_wallet_outlined),
                            label: Text(
                                ar ? 'تسجيل التسوية' : 'Record adjustment')),
                      ]))),
          const SizedBox(height: 16),
          Text(ar ? 'سجل المعاملات' : 'Transaction log',
              style: AppTextStyles.sectionLabel),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _filterId,
                    maxLength: 24,
                    decoration: InputDecoration(
                        labelText: ar
                            ? 'تصفية بمعرّف الطالب'
                            : 'Filter by student ID'))),
            IconButton(
                tooltip: ar ? 'بحث' : 'Search',
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.search)),
          ]),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()))
          else if (_entries.isEmpty)
            EmptyState(
                icon: Icons.receipt_long_outlined,
                title: ar ? 'لا توجد معاملات' : 'No transactions',
                message: ar
                    ? 'ستظهر معاملات المحفظة هنا.'
                    : 'Wallet transactions will appear here.')
          else
            ..._entries.map((entry) {
              final student = Json.mapOrNull(entry['student']) ?? {};
              final creator = Json.mapOrNull(entry['createdBy']) ?? {};
              final credit = entry['direction'] == 'credit';
              return Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    title: Text(
                        '${student['name'] ?? (ar ? 'طالب' : 'Student')} · ${student['email'] ?? ''}'),
                    subtitle: Text(
                        '${entry['kind'] ?? ''}${entry['notes'] == null ? '' : ' · ${entry['notes']}'}${creator.isEmpty ? '' : ' · ${creator['name'] ?? ''}'}'),
                    trailing: Text(
                        '${credit ? '+' : '-'}${entry['amount'] ?? 0}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                credit ? AppColors.success : AppColors.danger)),
                  ));
            }),
        ]),
      ),
    );
  }
}

class _WalletNotice extends StatelessWidget {
  final String message;
  final bool error;
  const _WalletNotice({required this.message, this.error = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(message,
            style: TextStyle(
                color: error
                    ? Theme.of(context).colorScheme.error
                    : AppColors.success)),
      );
}
