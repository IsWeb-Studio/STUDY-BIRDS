import '../community/student_profile_link.dart';
import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/app_notice.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/network/pinned_http.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'support_team_ai_screens.dart';

class ConversationThreadScreen extends StatefulWidget {
  final String contactName;
  final String contactAvatar;
  final String? contactId;
  const ConversationThreadScreen(
      {super.key,
      this.contactId,
      this.contactName = 'الرسائل',
      this.contactAvatar = ''});
  @override
  State<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState extends State<ConversationThreadScreen> {
  List<dynamic> contacts = [], messages = [];
  Map? contact;
  HttpClient? _httpClient;
  StreamSubscription<String>? _sseSub;
  bool loading = true, sending = false, older = false;
  String? _draftKey, _draftText;
  String? error;
  final text = TextEditingController();
  Timer? _liveTimer;
  bool _syncing = false;
  int _messageRevision = 0;
  bool _muted = false, _changing = false;
  Uint8List? _image, _draftImage;
  String? _imageName;
  double? _uploadProgress;
  final _messageScroll = ScrollController();
  bool get _visible =>
      (ModalRoute.isCurrentOf(context) ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  String? get token => AuthSession.instance.token;

  @override
  void initState() {
    super.initState();
    if (widget.contactId != null) {
      contact = {
        '_id': widget.contactId,
        'name': widget.contactName,
        'avatar': widget.contactAvatar
      };
    }
    load();
    _liveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_visible && !loading && contact != null) _resyncAfterGap();
    });
    _reconnectSub = ConnectivityService.instance.onReconnected.listen((_) {
      if (contact != null) {
        _sseGap = true;
        _sseAttempt = 0;
        _connectSse();
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _sseTimer?.cancel();
    _reconnectSub?.cancel();
    _sseSub?.cancel();
    _httpClient?.close(force: true);
    _messageScroll.dispose();
    text.dispose();
    super.dispose();
  }

  // Opens SSE connection to receive real-time messages from the server.
  // Reconnects with exponential backoff + jitter (never a tight loop), waits
  // while the device is offline, and re-syncs missed messages after a gap.
  int _sseAttempt = 0;
  bool _sseRefreshed = false;
  bool _sseGap = false;
  Timer? _sseTimer;
  StreamSubscription<void>? _reconnectSub;

  void _scheduleSse() {
    if (!mounted) return;
    _sseGap = true;
    _sseTimer?.cancel();
    final seconds = (2 << (_sseAttempt < 5 ? _sseAttempt : 5)).clamp(2, 60);
    _sseAttempt++;
    final jitter = Duration(
        milliseconds:
            (seconds * 1000 * .3 * (DateTime.now().microsecond / 1000000))
                .round());
    _sseTimer = Timer(Duration(seconds: seconds) + jitter, () {
      // No point opening sockets while the network is known to be down;
      // onReconnected below resumes immediately when it returns.
      if (ConnectivityService.instance.status == NetworkStatus.offline) {
        _scheduleSse();
      } else {
        _connectSse();
      }
    });
  }

  Future<void> _resyncAfterGap() async {
    final selected = contact;
    if (selected == null || _syncing || _changing || !_visible) return;
    final revision = _messageRevision;
    _syncing = true;
    try {
      final query =
          Uri(queryParameters: {'recipient': '${selected['_id']}'}).query;
      final value = await ApiClient.instance.get(
          '/mobile-workspace/messages?$query',
          token: token,
          cached: false);
      if (!mounted ||
          !_visible ||
          value is! List ||
          contact?['_id'] != selected['_id'] ||
          revision != _messageRevision) {
        return;
      }
      final refreshed = <String, dynamic>{
        for (final m in value) '${m['_id']}': m
      };
      final loadedIds = messages
          .map((m) => '${m['_id']}')
          .where((id) => !refreshed.containsKey(id))
          .toList();
      final removed = <String>{};
      for (var offset = 0; offset < loadedIds.length; offset += 100) {
        final ids = loadedIds.skip(offset).take(100).toList();
        final query = Uri(queryParameters: {
          'recipient': '${selected['_id']}',
          'ids': ids.join(',')
        }).query;
        final updates = Json.list(await ApiClient.instance.get(
            '/mobile-workspace/messages?$query',
            token: token,
            cached: false));
        if (!mounted ||
            !_visible ||
            contact?['_id'] != selected['_id'] ||
            revision != _messageRevision) {
          return;
        }
        final present = {for (final m in updates) '${m['_id']}'};
        removed.addAll(ids.where((id) => !present.contains(id)));
        for (final m in updates) {
          refreshed['${m['_id']}'] = m;
        }
      }
      if (!mounted || !_visible || revision != _messageRevision) return;
      setState(() {
        final merged = <String, dynamic>{
          for (final m in messages)
            if (!removed.contains('${m['_id']}')) '${m['_id']}': m,
          ...refreshed
        };
        messages = merged.values.toList()
          ..sort((a, b) => '${a['_id']}'.compareTo('${b['_id']}'));
      });
      if (value.isNotEmpty) {
        await ApiClient.instance.post('/mobile-workspace/messages/read',
            token: token,
            body: {'sender': selected['_id'], 'through': value.last['_id']});
      }
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/services_support/messaging_and_emergency_screens.dart:103');
    } finally {
      _syncing = false;
    }
  }

  void _connectSse() {
    _sseTimer?.cancel();
    _sseSub?.cancel();
    _httpClient?.close(force: true);
    final tok = token;
    if (tok == null) return;
    const baseUrl = ApiClient.baseUrl;
    final uri = Uri.parse('$baseUrl/mobile-workspace/events');
    PinnedHttp.newHttpClient(forUrl: baseUrl).then<void>((created) {
      if (!mounted) {
        created.close(force: true);
        return;
      }
      _httpClient?.close(force: true);
      _httpClient = created..connectionTimeout = const Duration(seconds: 15);
      _openSse(created, uri, tok);
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.swallowed(e, s, 'messaging.sse.client');
      _scheduleSse();
    });
  }

  void _openSse(HttpClient client, Uri uri, String tok) {
    client.getUrl(uri).then((req) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $tok');
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      return req.close();
    }).then<void>((res) {
      if (!mounted || client != _httpClient) return;
      if (res.statusCode != 200) {
        if (res.statusCode == 401 && !_sseRefreshed) {
          // Expired access token: renew once, then reconnect with the new one.
          _sseRefreshed = true;
          res.drain<void>().catchError(ErrorReporter.silent(
              'screens/services_support/messaging_and_emergency_screens.dart:129'));
          AuthSession.instance.refreshAccessToken(tok).then<void>((fresh) {
            if (mounted && fresh != null) _connectSse();
          }).catchError(ErrorReporter.silent(
              'screens/services_support/messaging_and_emergency_screens.dart:132'));
          return;
        }
        // Auth/feature errors will not fix themselves: stop, don't hammer.
        if (res.statusCode >= 500 || res.statusCode == 429) _scheduleSse();
        return;
      }
      _sseRefreshed = false;
      _sseAttempt = 0;
      if (_sseGap) {
        _sseGap = false;
        _resyncAfterGap(); // messages that arrived while the stream was down
      }
      _sseSub = res
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .listen((line) {
        if (!line.startsWith('data:')) return;
        try {
          final payload = jsonDecode(line.substring(5).trim());
          if (payload is! Map) return;
          final senderId = '${payload['sender']}';
          final currentId = '${contact?['_id']}';
          if (senderId != currentId || !mounted || !_visible) return;
          if (payload['_id'] == null) {
            unawaited(_resyncAfterGap());
            return;
          }
          setState(() {
            final index =
                messages.indexWhere((m) => m['_id'] == payload['_id']);
            if (index < 0) {
              messages = [...messages, payload];
            } else {
              messages[index] = payload;
            }
          });
          // Mark as read immediately
          ApiClient.instance.post('/mobile-workspace/messages/read',
              token: token,
              body: {
                'sender': senderId,
                'through': payload['_id']
              }).catchError(ErrorReporter.silent(
              'screens/services_support/messaging_and_emergency_screens.dart:165'));
        } catch (swallowedError, swallowedStack) {
          ErrorReporter.swallowed(swallowedError, swallowedStack,
              'screens/services_support/messaging_and_emergency_screens.dart:154');
        }
      },
              onError: (_) => _scheduleSse(),
              onDone: _scheduleSse,
              cancelOnError: true);
    }).catchError((Object e_, StackTrace s_) {
      ErrorReporter.swallowed(e_, s_,
          'screens/services_support/messaging_and_emergency_screens.dart:171');
      _scheduleSse();
    });
  }

  Future<void> load({bool previous = false}) async {
    final selected = contact;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (selected == null) {
        final value = await ApiClient.instance
            .get('/mobile-workspace/contacts', token: token, cached: false);
        if (mounted) setState(() => contacts = Json.list(value));
      } else {
        if (widget.contactId != null &&
            selected['name'] == widget.contactName &&
            widget.contactName == 'الرسائل') {
          final person = await ApiClient.instance.get(
              '/mobile-workspace/contacts/${selected['_id']}',
              token: token,
              cached: false);
          if (mounted && person is Map) setState(() => contact = person);
        }
        if (!previous) {
          final preference = await ApiClient.instance.get(
              '/mobile-workspace/conversations/${selected['_id']}',
              token: token,
              cached: false);
          if (mounted && preference is Map) {
            setState(() => _muted = preference['muted'] == true);
          }
        }
        final query = Uri(queryParameters: {
          'recipient': '${selected['_id']}',
          if (previous && messages.isNotEmpty)
            'before': '${messages.first['_id']}'
        }).query;
        final value = Json.list(await ApiClient.instance.get(
            '/mobile-workspace/messages?$query',
            token: token,
            cached: false));
        if (!mounted) return;
        setState(() {
          messages = previous ? [...value, ...messages] : value;
          older = value.length == 50;
        });
        if (_visible && value.isNotEmpty) {
          await ApiClient.instance.post('/mobile-workspace/messages/read',
              token: token,
              body: {'sender': selected['_id'], 'through': value.last['_id']});
        }
        // Start SSE real-time stream (replaces polling)
        _connectSse();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException && e.statusCode == 404
            ? 'المحادثات لم تُفعّل على السيرفر بعد. يمكنك استخدام تذاكر الدعم.'
            : AppError.isOffline(e)
                ? AppError.connection
                : 'تعذر تحميل الرسائل. حاول مجددًا.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final body = text.text.trim();
    if ((body.isEmpty && _image == null) || contact == null || sending) return;
    setState(() => sending = true);
    // One key per draft: a re-send of the SAME text after an uncertain failure
    // carries the same key so a supporting server can drop the duplicate.
    final key = (_draftKey != null &&
            _draftText == body &&
            identical(_draftImage, _image))
        ? _draftKey!
        : ApiClient.newOperationId();
    _draftKey = key;
    _draftText = body;
    _draftImage = _image;
    try {
      final value = _image != null
          ? await ApiClient.instance.postMultipart(
              '/mobile-workspace/messages/image',
              fileBytes: _image!,
              fileName: _imageName ?? 'chat.jpg',
              token: token,
              fields: {
                  'recipient': '${contact!['_id']}',
                  'body': body,
                  'operationId': key
                }, onProgress: (value) {
              if (mounted) setState(() => _uploadProgress = value);
            })
          : await ApiClient.instance.post('/mobile-workspace/messages',
              token: token,
              idempotencyKey: key,
              body: {'recipient': contact!['_id'], 'body': body});
      if (!mounted) return;
      _draftKey = null;
      _draftText = null;
      _draftImage = null;
      setState(() {
        final id = '${value is Map ? value['_id'] : ''}';
        if (id.isEmpty || !messages.any((m) => '${m['_id']}' == id)) {
          messages = [...messages, value];
        }
        text.clear();
        _image = null;
        _imageName = null;
        _uploadProgress = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
            content: Text(e is ApiException && e.statusCode == 408
                ? 'تأخر الاتصال؛ قد تكون الرسالة أُرسلت. حدّث المحادثة قبل إعادة الإرسال.'
                : AppError.isOffline(e)
                    ? 'لا يوجد اتصال بالإنترنت. لم تُرسل الرسالة وهي محفوظة في الحقل.'
                    : e is ApiException
                        ? e.message
                        : 'تعذر الإرسال؛ رسالتك محفوظة في الحقل')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _pickImage() async {
    if (sending) return;
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _notice('اختر صورة أصغر من 5 ميجابايت');
        return;
      }
      if (mounted) {
        setState(() {
          _image = bytes;
          _imageName = picked.name;
        });
      }
    } catch (_) {
      _notice('تعذر فتح الصور، حاول مجددًا');
    }
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirm(String title, String description) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(title),
                  content: Text(description),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف',
                            style: TextStyle(color: Colors.red))),
                  ])) ??
      false;

  Future<void> _chatAction(String action) async {
    if (_changing || contact == null) return;
    _changing = true;
    try {
      final path = '/mobile-workspace/conversations/${contact!['_id']}';
      if (action == 'mute') {
        final value = await ApiClient.instance
            .put(path, token: token, body: {'muted': !_muted});
        if (mounted) setState(() => _muted = value['muted'] == true);
        _notice(
            _muted ? 'تم كتم إشعارات المحادثة' : 'تم تفعيل إشعارات المحادثة');
      } else if (action == 'delete' &&
          await _confirm('حذف المحادثة؟',
              'ستُحذف المحادثة من عندك فقط. تظهر من جديد إذا وصلت رسالة جديدة.')) {
        await ApiClient.instance.delete(path, token: token);
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (_) {
      _notice('تعذر تنفيذ العملية، حاول مجددًا');
    } finally {
      _changing = false;
    }
  }

  Future<void> _messageOptions(Map row) async {
    if (sending || _changing) return;
    final mine = '${row['sender']}' == AuthSession.instance.currentUser?.id;
    final deleted = row['deletedAt'] != null;
    final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!deleted && '${row['body'] ?? ''}'.isNotEmpty)
                ListTile(
                    leading: const Icon(Icons.copy_outlined),
                    title: const Text('نسخ النص'),
                    onTap: () => Navigator.pop(ctx, 'copy')),
              ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('حذف لدي'),
                  onTap: () => Navigator.pop(ctx, 'me')),
              if (mine && !deleted)
                ListTile(
                    leading: const Icon(Icons.undo_rounded),
                    title: const Text('إلغاء الإرسال للجميع'),
                    onTap: () => Navigator.pop(ctx, 'everyone')),
            ])));
    if (!mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: '${row['body']}'));
      _notice('تم نسخ النص');
      return;
    }
    if (action == 'everyone' &&
        !await _confirm(
            'إلغاء إرسال الرسالة؟', 'سيتم حذف محتوى الرسالة لدى الطرفين.')) {
      return;
    }
    if (!mounted) return;
    _changing = true;
    _messageRevision++;
    try {
      await ApiClient.instance.delete(
          '/mobile-workspace/messages/${row['_id']}?scope=$action',
          token: token);
      if (!mounted) return;
      setState(() {
        if (action == 'me') {
          messages.removeWhere((m) => m['_id'] == row['_id']);
        } else {
          messages = messages
              .map((m) => m['_id'] == row['_id']
                  ? {
                      ...m,
                      'body': '',
                      'imagePath': null,
                      'deletedAt': DateTime.now().toIso8601String()
                    }
                  : m)
              .toList();
        }
      });
    } catch (_) {
      _notice('تعذر حذف الرسالة، حاول مجددًا');
    } finally {
      _changing = false;
    }
  }

  Widget _imageView(Map row, {bool expanded = false}) =>
      Image.network('${ApiClient.baseUrl}${row['imagePath']}',
          key: ValueKey('chat-image-${row['_id']}-$expanded'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
          width: expanded ? null : 260,
          height: expanded ? null : 220,
          fit: expanded ? BoxFit.contain : BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator())),
          errorBuilder: (context, error, stack) => const SizedBox(
              height: 120, child: Center(child: Text('تعذر تحميل الصورة'))));

  String _time(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    return date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Expanded(
              child: StudentIdentity(
                  id: '${contact?['_id'] ?? ''}',
                  name: contact?['name']?.toString() ?? 'المحادثات',
                  avatar: '${contact?['avatar'] ?? ''}')),
          if (_muted && contact != null)
            const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.notifications_off_outlined, size: 18)),
        ]),
        actions: [
          if (contact != null)
            PopupMenuButton<String>(
                tooltip: 'خيارات المحادثة',
                onSelected: _chatAction,
                itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'mute',
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(_muted
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined),
                              title: Text(
                                  _muted ? 'إلغاء الكتم' : 'كتم الإشعارات'))),
                      const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('حذف المحادثة',
                                  style: TextStyle(color: Colors.red)))),
                    ]),
        ],
      ),
      body: loading && messages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : error != null && messages.isEmpty
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: () => load(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة')),
                      ])))
              : contact == null
                  ? _contactsList()
                  : _thread());

  // A conversation always occupies the whole screen, including wide layouts.
  Widget _contactsList() => ListView(children: [
        if (contacts.isEmpty)
          const Padding(
              padding: EdgeInsets.all(32),
              child:
                  Text('لا توجد محادثات متاحة.', textAlign: TextAlign.center)),
        for (final row in contacts)
          ListTile(
              leading: StudentProfileLink(
                  studentId: row['role'] == 'student' ? '${row['_id']}' : '',
                  child: CircleAvatar(
                      backgroundImage: '${row['avatar'] ?? ''}'.isEmpty
                          ? null
                          : NetworkImage('${row['avatar']}'),
                      child: '${row['avatar'] ?? ''}'.isEmpty
                          ? const Icon(Icons.person_outline)
                          : null)),
              title: Text('${row['name']}'),
              onTap: () {
                setState(() => contact = Json.rawMap(row));
                load();
              }),
      ]);

  Widget _thread() => Column(children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
            child: ListView.builder(
          controller: _messageScroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          itemCount:
              messages.length + (older ? 1 : 0) + (messages.isEmpty ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= messages.length) {
              if (older) {
                return TextButton(
                    onPressed: loading ? null : () => load(previous: true),
                    child: const Text('رسائل أقدم'));
              }
              return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.blueGrey, size: 42),
                    SizedBox(height: 12),
                    Text('ابدأ المحادثة 👋',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('أرسل رسالة أو صورة لصديقك',
                        style: TextStyle(color: Colors.blueGrey)),
                  ]));
            }
            final row = messages[messages.length - 1 - index] as Map;
            final mine =
                '${row['sender']}' == AuthSession.instance.currentUser?.id;
            final deleted = row['deletedAt'] != null;
            final color = mine ? Colors.white : AppColors.textPrimary;
            final date = DateTime.tryParse('${row['createdAt']}')?.toLocal();
            final previousDate = index + 1 < messages.length
                ? DateTime.tryParse(
                        '${messages[messages.length - 2 - index]['createdAt']}')
                    ?.toLocal()
                : null;
            final dayLabel = date != null &&
                (previousDate == null ||
                    date.year != previousDate.year ||
                    date.month != previousDate.month ||
                    date.day != previousDate.day);
            return Column(children: [
              if (dayLabel)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text('${date.day}/${date.month}/${date.year}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blueGrey))),
              Align(
                  alignment: mine
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: GestureDetector(
                      onLongPress: () => _messageOptions(row),
                      onSecondaryTap: () => _messageOptions(row),
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: (MediaQuery.sizeOf(context).width * .78)
                                .clamp(100, 520)),
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color:
                                mine ? const Color(0xFF4169E1) : Colors.white,
                            borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(mine ? 20 : 5),
                                bottomRight: Radius.circular(mine ? 5 : 20)),
                            border: mine
                                ? null
                                : Border.all(color: const Color(0xFFE8ECF3))),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (deleted)
                                Text('تم حذف هذه الرسالة',
                                    style: TextStyle(
                                        color: color.withValues(alpha: .65),
                                        fontStyle: FontStyle.italic))
                              else ...[
                                if (row['imagePath'] != null)
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: GestureDetector(
                                              onTap: () => Navigator.of(context)
                                                  .push(MaterialPageRoute(
                                                      builder: (_) => Scaffold(
                                                          backgroundColor:
                                                              Colors.black,
                                                          appBar: AppBar(
                                                              backgroundColor:
                                                                  Colors.black,
                                                              foregroundColor:
                                                                  Colors.white),
                                                          body: Center(
                                                              child: InteractiveViewer(child: _imageView(row, expanded: true)))))),
                                              child: _imageView(row)))),
                                if ('${row['body'] ?? ''}'.isNotEmpty)
                                  Text('${row['body']}',
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 15,
                                          height: 1.45)),
                              ],
                              const SizedBox(height: 5),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(_time(row['createdAt']),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: color.withValues(alpha: .65))),
                                if (mine && !deleted) ...[
                                  const SizedBox(width: 5),
                                  Icon(
                                      row['readAt'] != null
                                          ? Icons.done_all
                                          : Icons.check,
                                      size: 14,
                                      color: row['readAt'] != null
                                          ? const Color(0xFFAFFFE7)
                                          : Colors.white70)
                                ],
                              ]),
                            ]),
                      ))),
            ]);
          },
        )),
        SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE8ECF3)))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_image != null)
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Stack(children: [
                            ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(_image!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover)),
                            Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton.filled(
                                    tooltip: 'إزالة الصورة',
                                    onPressed: sending
                                        ? null
                                        : () => setState(() {
                                              _image = null;
                                              _imageName = null;
                                            }),
                                    icon: const Icon(Icons.close, size: 16))),
                          ]))),
                if (sending && _image != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(value: _uploadProgress)),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  IconButton(
                      tooltip: 'إرفاق صورة',
                      onPressed: sending ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined,
                          color: Color(0xFF4169E1))),
                  Expanded(
                      child: TextField(
                          controller: text,
                          enabled: !sending,
                          maxLength: 4000,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                              hintText: 'اكتب رسالة…',
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFFF4F6FA),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none)))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      tooltip: 'إرسال',
                      onPressed: sending ? null : send,
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF4169E1)),
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded)),
                ]),
              ]),
            )),
      ]);
}

class EmergencySupportScreen extends StatelessWidget {
  const EmergencySupportScreen({super.key});

  static const _phone = '+905000000000';
  static const _whatsapp = 'https://wa.me/905000000000';

  Future<void> _launch(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw '';
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/services_support/messaging_and_emergency_screens.dart:435');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            AppSnackBar(content: const Text('تعذر فتح التطبيق الخارجي')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مساعدة عاجلة',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.emergency_share_rounded,
                    color: AppColors.danger, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('خط الطوارئ متاح 24/7',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.danger)),
                      SizedBox(height: 4),
                      Text(
                        'للحالات الحرجة فقط: مشاكل في المطار، أزمات السكن، موعد السفارة الغد.',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('تواصل فوري مع مسؤول الطوارئ',
              style: AppTextStyles.sectionLabel),
          const SizedBox(height: 14),
          _EmergencyButton(
            icon: Icons.phone_rounded,
            label: 'اتصل بمسؤول الطوارئ',
            subtitle: _phone,
            color: AppColors.success,
            onTap: () => _launch(context, 'tel:$_phone'),
          ),
          const SizedBox(height: 12),
          _EmergencyButton(
            icon: Icons.chat_rounded,
            label: 'تواصل عبر واتساب',
            subtitle: 'ردّ فوري خلال دقائق',
            color: const Color(0xFF25D366),
            onTap: () => _launch(context, _whatsapp),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          const Text('بديل: تذكرة دعم عاجلة',
              style: AppTextStyles.sectionLabel),
          const SizedBox(height: 8),
          const Text(
            'إذا لم تستطع الاتصال، أرسل تذكرة دعم وسيرد عليك الفريق فور رؤيتها.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'إرسال تذكرة عاجلة',
            icon: Icons.confirmation_number_outlined,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    const NewSupportTicketScreen(initialSubject: '[عاجل] '))),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('أو تحدّث مع فريقك', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.message_outlined),
            label: const Text('فتح المحادثة الداخلية'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConversationThreadScreen())),
          ),
        ],
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _EmergencyButton(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white60, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
