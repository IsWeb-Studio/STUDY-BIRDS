import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../services/auth_session.dart';

Future<void> reportUnsafeContent(BuildContext context, String content) async {
  final ar = Localizations.localeOf(context).languageCode == 'ar';
  final token = AuthSession.instance.token;
  final reason = await showDialog<String>(
      context: context, builder: (context) => _ReportReasonDialog(ar: ar));
  if (reason == null ||
      !context.mounted ||
      token == null ||
      token != AuthSession.instance.token) {
    return;
  }
  try {
    await ApiClient.instance.post('/safety/reports', token: token, body: {
      'reason': reason,
      'content': content.length > 8000 ? content.substring(0, 8000) : content
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar
              ? 'وصل البلاغ لفريق الدعم للمراجعة.'
              : 'Report sent to Support for review.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ar
              ? 'تعذر إرسال البلاغ. حاول مجددًا.'
              : 'Could not send the report. Please retry.')));
    }
  }
}

class _ReportReasonDialog extends StatefulWidget {
  final bool ar;
  const _ReportReasonDialog({required this.ar});
  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.ar
            ? 'إبلاغ عن محتوى غير مناسب'
            : 'Report inappropriate content'),
        content: TextField(
            controller: _controller,
            maxLength: 1000,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: widget.ar ? 'سبب البلاغ' : 'Reason for reporting')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.ar ? 'إلغاء' : 'Cancel')),
          TextButton(
              onPressed: () {
              if (_controller.text.trim().isNotEmpty) {
                Navigator.pop(context, _controller.text.trim());
              }
              },
              child: Text(widget.ar ? 'إرسال البلاغ' : 'Send report'))
        ],
      );
}

class BlockUserButton extends StatefulWidget {
  final String userId;
  const BlockUserButton({super.key, required this.userId});
  @override
  State<BlockUserButton> createState() => _BlockUserButtonState();
}

class _BlockUserButtonState extends State<BlockUserButton> {
  bool _busy = false;
  Future<void> _block() async {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final token = AuthSession.instance.token;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(ar ? 'حظر المستخدم؟' : 'Block this user?'),
              content: Text(ar
                  ? 'سيُمنع التواصل المباشر وتُخفى منشوراتكما عن بعضكما. يمكنك إلغاء الحظر من إعدادات الأمان.'
                  : 'Direct contact will be prevented and your community content hidden from each other. Unblock from Security settings.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(ar ? 'إلغاء' : 'Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(ar ? 'حظر' : 'Block'))
              ],
            ));
    if (!mounted ||
        confirmed != true ||
        token == null ||
        token != AuthSession.instance.token) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.put(
          '/safety/blocks/${Uri.encodeComponent(widget.userId)}',
          token: token,
          body: {});
      if (mounted) Navigator.maybePop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar
                ? 'تعذر الحظر. حاول مجددًا.'
                : 'Could not block this user. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.userId == AuthSession.instance.currentUser?.id
          ? const SizedBox.shrink()
          : IconButton(
              onPressed: _busy ? null : _block,
              tooltip: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'حظر المستخدم'
                  : 'Block user',
              icon: const Icon(Icons.block_outlined));
}

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String? _busyId;
  final _token = AuthSession.instance.token;
  bool get _valid => _token != null && _token == AuthSession.instance.token;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!_valid) return;
      final data = await ApiClient.instance
          .get('/safety/blocks', token: _token, cached: false);
      if (mounted && _valid) {
        setState(() {
          _rows = (data as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'تعذر تحميل القائمة / Could not load blocked users');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(String id) async {
    if (!_valid || _busyId != null) return;
    setState(() => _busyId = id);
    try {
      await ApiClient.instance
          .delete('/safety/blocks/${Uri.encodeComponent(id)}', token: _token);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إلغاء الحظر / Could not unblock');
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
        appBar:
            AppBar(title: Text(ar ? 'المستخدمون المحظورون' : 'Blocked users')),
        body: !_valid
            ? const Center(child: Text('سجّل الدخول مجددًا / Sign in again'))
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(children: [
                    if (_error != null)
                      ListTile(
                          title: Text(_error!),
                          trailing: IconButton(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh))),
                    if (_rows.isEmpty && _error == null)
                      ListTile(
                          title: Text(ar
                              ? 'لا يوجد مستخدمون محظورون.'
                              : 'No blocked users.')),
                    for (final row in _rows)
                      if (row['blocked'] is Map)
                        ListTile(
                            title: Text('${row['blocked']['name'] ?? ''}'),
                            trailing: TextButton(
                                onPressed: _busyId != null
                                    ? null
                                    : () =>
                                        _unblock('${row['blocked']['_id']}'),
                                child: Text(ar ? 'إلغاء الحظر' : 'Unblock'))),
                  ]));
  }
}
