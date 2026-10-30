import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/utils/json_safe.dart';

class AdminPushAnnouncementsScreen extends StatefulWidget {
  const AdminPushAnnouncementsScreen({super.key});
  @override
  State<AdminPushAnnouncementsScreen> createState() => _AnnouncementState();
}

class _AnnouncementState extends State<AdminPushAnnouncementsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<dynamic> _items = [];
  bool _enabled = false, _busy = false;
  String? _requestId, _error, _message;
  String? get _token => AuthSession.instance.token;
  bool get _admin => AuthSession.instance.currentUser?.role == UserRole.admin;
  String _copy(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (!_admin) return;
    try {
      final data = Json.map(await ApiClient.instance
          .get('/admin/push-announcements', token: token, cached: false));
      if (!mounted || token != _token) return;
      setState(() {
        _enabled = data['enabled'] == true;
        _items = Json.list(data['items']);
        _error = null;
      });
    } catch (_) {
      if (mounted && token == _token) {
        setState(() => _error = _copy(
            'تعذر تحميل الإعلانات. تحقق من الاتصال وتحديث السيرفر.',
            'Unable to load announcements. Check connectivity and server deployment.'));
      }
    }
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  String _status(String? status) => status == 'accepted'
      ? _copy('قبلت خدمة الإشعارات طلب الإرسال؛ وصوله لكل جهاز غير مضمون.',
          'Accepted by push service; delivery to every device is not guaranteed.')
      : status == 'no_subscribers'
          ? _copy('لا توجد أجهزة مشتركة.', 'No subscribed devices.')
          : _copy('الإرسال غير مؤكد؛ أعد محاولة نفس الإعلان.',
              'Unconfirmed; retry the same announcement.');

  Future<void> _send([Map<String, dynamic>? previous]) async {
    if (_busy || !_admin || !_enabled) return;
    final title = previous?['title'] as String? ?? _title.text.trim();
    final body = previous?['body'] as String? ?? _body.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    final token = _token;
    setState(() => _busy = true);
    try {
      if (previous == null && _requestId == null) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(_copy('إرسال للجميع؟', 'Send to all?')),
                  content: Text(
                      '$title\n\n$body\n\n${_copy('سيصل لكل مشتركي إشعارات التطبيق.', 'Targets all mobile push subscribers.')}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(_copy('إلغاء', 'Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(_copy('إرسال الآن', 'Send now')))
                  ],
                ));
        if (confirmed != true) return;
      }
      if (!mounted || token != _token || !_admin) return;
      if (previous == null) _requestId ??= _uuid();
      setState(() {
        _error = null;
        _message = null;
      });
      final item = Json.map(await ApiClient.instance
          .post('/admin/push-announcements', token: token, body: {
        'title': title,
        'body': body,
        'requestId': previous?['requestId'] ?? _requestId,
        if (previous != null) 'announcementId': previous['_id'],
      }));
      if (!mounted || token != _token) return;
      setState(() {
        _message = _status(item['status'] as String?);
        if (previous == null) {
          _title.clear();
          _body.clear();
          _requestId = null;
        }
      });
      await _load();
    } catch (_) {
      if (mounted && token == _token) {
        setState(() => _error = _copy(
            'تعذر تأكيد الإرسال. أعد محاولة نفس الإعلان دون تغييره لتفادي التكرار.',
            'Unable to confirm sending. Retry the same announcement without editing to avoid duplicates.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: _copy('إعلانات التطبيق', 'App announcements'),
        body: !_admin
            ? const Center(child: Icon(Icons.lock_outline))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text(_copy(
                      'إرسال إعلان لكل مشتركي إشعارات أندرويد وآيفون من جميع أنواع الحسابات. من عطّل الإشعارات لن يستلمه.',
                      'Send to Android and iPhone push subscribers across all account roles. Users who disabled notifications will not receive it.')),
                  if (!_enabled)
                    Text(_copy(
                        'الإرسال غير متاح حتى تفعيل OneSignal على السيرفر.',
                        'Sending is unavailable until OneSignal is configured on the server.')),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _title,
                      maxLength: 80,
                      enabled: !_busy && _requestId == null,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          labelText: _copy('العنوان', 'Title'))),
                  TextField(
                      controller: _body,
                      maxLength: 1000,
                      minLines: 3,
                      maxLines: 6,
                      enabled: !_busy && _requestId == null,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          labelText: _copy('نص الإعلان', 'Message'))),
                  AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_title.text.isEmpty ? 'COVEY' : _title.text,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(_body.text)
                      ])),
                  FilledButton(
                      onPressed: !_enabled ||
                              _busy ||
                              _title.text.trim().isEmpty ||
                              _body.text.trim().isEmpty
                          ? null
                          : () => _send(),
                      child: Text(_busy
                          ? _copy('جارٍ الإرسال…', 'Sending…')
                          : _requestId != null
                              ? _copy('إعادة محاولة نفس الإعلان',
                                  'Retry same announcement')
                              : _copy('إرسال للجميع', 'Send to all'))),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_message != null) Text(_message!),
                  TextButton(
                      onPressed: _busy ? null : _load,
                      child: Text(_copy('تحديث السجل', 'Refresh history'))),
                  ..._items.map((raw) {
                    final item = Json.map(raw);
                    return AppCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(item['title'] as String? ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(item['body'] as String? ?? ''),
                          Text(item['createdAt'] as String? ?? ''),
                          Text(_status(item['status'] as String?)),
                          if (!['accepted', 'no_subscribers']
                              .contains(item['status']))
                            TextButton(
                                onPressed: _busy || !_enabled
                                    ? null
                                    : () => _send(item),
                                child: Text(_copy('إعادة المحاولة دون تكرار',
                                    'Retry without duplicate delivery'))),
                        ]));
                  }),
                ]),
              ),
      );
}
