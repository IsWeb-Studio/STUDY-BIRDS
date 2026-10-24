import 'package:flutter/material.dart';

import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/admin_modules_repository.dart';
import '../../core/utils/app_error.dart';

typedef NotificationAudienceLoader = Future<Map<String, dynamic>> Function();
typedef AppNotificationSender = Future<Map<String, dynamic>> Function({
  required String title,
  required String message,
  required String idempotencyKey,
});

/// Admin-only composer for announcements delivered to every active account.
/// The API enforces admin authorization and idempotency independently.
class AdminAppNotificationScreen extends StatefulWidget {
  final NotificationAudienceLoader? loadAudience;
  final AppNotificationSender? sendBroadcast;

  const AdminAppNotificationScreen({
    super.key,
    this.loadAudience,
    this.sendBroadcast,
  });

  @override
  State<AdminAppNotificationScreen> createState() =>
      _AdminAppNotificationScreenState();
}

class _AdminAppNotificationScreenState
    extends State<AdminAppNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  Map<String, dynamic>? _audience;
  Map<String, dynamic>? _result;
  String? _loadError;
  String? _sendError;
  String? _pendingDraft;
  String? _pendingKey;
  bool _loadingAudience = true;
  bool _sending = false;

  NotificationAudienceLoader get _loadAudience =>
      widget.loadAudience ??
      AdminModulesRepository.instance.getNotificationAudience;

  AppNotificationSender get _sendBroadcast =>
      widget.sendBroadcast ??
      AdminModulesRepository.instance.broadcastAppNotification;

  @override
  void initState() {
    super.initState();
    _refreshAudience();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _refreshAudience() async {
    setState(() {
      _loadingAudience = true;
      _loadError = null;
    });
    try {
      final audience = await _loadAudience();
      if (!mounted) return;
      setState(() {
        _audience = audience;
        _loadingAudience = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = AppError.message(error);
        _loadingAudience = false;
      });
    }
  }

  void _draftChanged() {
    final draft = '${_title.text.trim()}\n${_message.text.trim()}';
    if (_pendingDraft != null && _pendingDraft != draft) {
      _pendingDraft = null;
      _pendingKey = null;
    }
    setState(() {
      _sendError = null;
      _result = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    final audience = _audience;
    if (audience == null || audience['canBroadcast'] != true) return;

    final recipientCount = _count(audience['activeUsers']);
    final pushCount = _count(audience['pushEligibleUsers']);
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'تأكيد إرسال إشعار عام',
      message: 'سيُحفظ الإشعار في صندوق الوارد لـ $recipientCount حساب نشط. '
          'التنبيه الفوري متاح لما يصل إلى $pushCount حسابًا حسب إعداداتهم وسماح أجهزتهم. هل تريد المتابعة؟',
      confirmLabel: 'إرسال للجميع',
      scrollable: true,
    );
    if (!confirmed || !mounted) return;

    final title = _title.text.trim();
    final message = _message.text.trim();
    final draft = '$title\n$message';
    if (_pendingDraft != draft || _pendingKey == null) {
      _pendingDraft = draft;
      _pendingKey = ApiClient.newOperationId();
    }

    setState(() {
      _sending = true;
      _sendError = null;
      _result = null;
    });
    try {
      final result = await _sendBroadcast(
        title: title,
        message: message,
        idempotencyKey: _pendingKey!,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _pendingDraft = null;
        _pendingKey = null;
        _title.clear();
        _message.clear();
      });
      await _refreshAudience();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sendError = AppError.message(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int _count(Object? value) => value is num ? value.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    final audience = _audience;
    final canSend = !_loadingAudience &&
        audience?['canBroadcast'] == true &&
        !_sending &&
        _title.text.trim().isNotEmpty &&
        _message.text.trim().isNotEmpty;

    return AppScaffold(
      title: 'إشعارات التطبيق',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign_rounded,
                        color: AppColors.orange, size: 25),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('إرسال إعلان لجميع المستخدمين',
                          style: AppTextStyles.cardTitle),
                    ),
                    IconButton(
                      key: const ValueKey('refresh-notification-audience'),
                      tooltip: 'تحديث الجمهور',
                      onPressed: _loadingAudience ? null : _refreshAudience,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'يصل الإعلان إلى صندوق الإشعارات في كل حساب نشط. التنبيه الفوري يعتمد على إعداد المستخدم وسماح الجهاز.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                if (_loadingAudience) const LinearProgressIndicator(),
                if (!_loadingAudience && audience != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AudienceChip(
                        label: 'الحسابات النشطة',
                        count: _count(audience['activeUsers']),
                      ),
                      _AudienceChip(
                        label: 'المؤهلون للتنبيه الفوري',
                        count: _count(audience['pushEligibleUsers']),
                      ),
                    ],
                  ),
                  if (audience['canBroadcast'] != true) ...[
                    const SizedBox(height: 10),
                    const Text('إرسال الإعلانات متاح لحساب الأدمن فقط.',
                        style: TextStyle(color: AppColors.danger)),
                  ],
                ],
                if (_loadError != null) ...[
                  const SizedBox(height: 10),
                  Text('تعذر تحميل عدد المستلمين: $_loadError',
                      style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('عنوان الإشعار',
                      style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const ValueKey('app-notification-title'),
                    controller: _title,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'مثال: منحة دراسية جديدة',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _draftChanged(),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل عنوان الإشعار.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const Text('نص الإشعار', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const ValueKey('app-notification-message'),
                    controller: _message,
                    maxLength: 500,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'اكتب تفاصيل الإعلان باختصار…',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _draftChanged(),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل نص الإشعار.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const ValueKey('send-app-notification'),
                    onPressed: canSend ? _submit : null,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'جارٍ الإرسال…' : 'إرسال للجميع'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  if (_sendError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'تعذر تأكيد الإرسال. حدّث القائمة قبل إعادة المحاولة. $_sendError',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 12),
                    _BroadcastResult(result: _result!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  final String label;
  final int count;
  const _AudienceChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Chip(
        avatar: const Icon(Icons.people_alt_outlined, size: 17),
        label: Text('$label: $count'),
        backgroundColor: AppColors.background,
        side: const BorderSide(color: AppColors.border),
      );
}

class _BroadcastResult extends StatelessWidget {
  final Map<String, dynamic> result;
  const _BroadcastResult({required this.result});

  int _count(Object? value) => value is num ? value.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    final recipients = _count(result['recipientCount']);
    final pushReported = _count(result['pushReportedRecipientCount']);
    final pushConfigured = result['pushConfigured'] == true;
    final unconfirmed = _count(result['pushUnconfirmedBatches']);
    final summary = pushConfigured
        ? 'تم حفظ الإشعار في $recipients حسابًا نشطًا. أفاد مزود التنبيه بإرساله إلى $pushReported جهازًا/حسابًا.'
        : 'تم حفظ الإشعار في $recipients حسابًا نشطًا. خدمة التنبيه الفوري غير مهيأة.';
    return Container(
      key: const ValueKey('app-notification-send-result'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$summary${unconfirmed > 0 ? ' توجد مجموعات لم يؤكد المزود استلامها.' : ''}',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
