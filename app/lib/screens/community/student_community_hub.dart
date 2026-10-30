import '../../core/repositories/stories_repository.dart';
import '../../core/config/app_theme.dart';
import 'contact_profile_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../stories/student_stories.dart';
import '../services_support/messaging_and_emergency_screens.dart';
import '../services_support/community_screen.dart';
import 'admin_community_control_center.dart';

bool _hubIsArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _hubText(BuildContext context, String arabic, String english) =>
    _hubIsArabic(context) ? arabic : english;

Future<Map<String, dynamic>> communityInbox(
    {String? before, bool summary = false}) async {
  final token = AuthSession.instance.token;
  final version = ApiClient.instance.snapshotVersion;
  const snapshotKey = '/mobile-workspace/conversations?community=1';
  final data = Map<String, dynamic>.from(await ApiClient.instance.get(
      Uri(path: '/mobile-workspace/conversations', queryParameters: {
        'community': '1',
        if (before != null) 'before': before,
        if (summary) 'summary': '1',
      }).toString(),
      token: token,
      cached: false));
  if (before == null && !summary) {
    ApiClient.instance
        .rememberSnapshot(snapshotKey, data, token: token, version: version);
  }
  return data;
}

Future<void> warmCommunity() async {
  try {
    await Future.wait<dynamic>([
      if (ApiClient.instance.snapshot(
              '/mobile-workspace/conversations?community=1',
              token: AuthSession.instance.token) ==
          null)
        communityInbox(),
      if (StoriesRepository.instance.cachedFeed() == null)
        StoriesRepository.instance.feed(),
    ]);
  } catch (_) {
    /* First visible refresh handles errors; warming never blocks home. */
  }
}

class CommunityEntry extends StatefulWidget {
  final bool isActive;
  const CommunityEntry({super.key, this.isActive = true});
  @override
  State<CommunityEntry> createState() => _CommunityEntryState();
}

class _CommunityEntryState extends State<CommunityEntry> {
  Timer? _timer;
  int _unread = 0;
  bool _busy = false, _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy ||
        !widget.isActive ||
        !(ModalRoute.isCurrentOf(context) ?? true) ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    _busy = true;
    try {
      final data = await communityInbox(summary: true);
      if (mounted) {
        setState(() => _unread = (data['unreadTotal'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {/* Retry on the next visible refresh. */} finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 78,
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (_opening) return;
            _opening = true;
            try {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const StudentCommunityHub()));
              if (mounted) await _refresh();
            } finally {
              _opening = false;
            }
          },
          child: Column(children: [
            const SizedBox(height: 5),
            Badge(
                isLabelVisible: _unread > 0,
                label: Text(_unread > 99 ? '99+' : '$_unread'),
                child: const CircleAvatar(
                    radius: 29,
                    backgroundColor: AppColors.greenSoft,
                    child: Icon(Icons.forum_outlined,
                        color: AppColors.greenInk, size: 27))),
            const SizedBox(height: 9),
            Text(_hubText(context, 'المجتمع', 'Community'),
                style: const TextStyle(fontSize: 11)),
          ])));
}

class StudentCommunityHub extends StatefulWidget {
  final bool isActive;
  const StudentCommunityHub({super.key, this.isActive = true});
  @override
  State<StudentCommunityHub> createState() => _StudentCommunityHubState();
}

class _StudentCommunityHubState extends State<StudentCommunityHub>
    with WidgetsBindingObserver {
  final _storiesKey = GlobalKey<StudentStoriesState>();
  Completer<void>? _loadDone;

  Future<void> _refreshPage() async {
    await Future.wait([
      _load(),
      _storiesKey.currentState?.refresh() ?? Future<void>.value(),
    ]);
  }

  List<Map<String, dynamic>> _rows = [];
  String? _cursor;
  bool _busy = false, _loading = true, _opening = false;
  bool _mutating = false;
  bool _activated = false;
  int _revision = 0;
  String? _error;
  Timer? _timer;
  bool get _visible =>
      widget.isActive &&
      (ModalRoute.isCurrentOf(context) ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activated = widget.isActive;
    final cached = ApiClient.instance.snapshot(
        '/mobile-workspace/conversations?community=1',
        token: AuthSession.instance.token);
    if (cached is Map && cached['conversations'] is List) {
      _rows = (cached['conversations'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      _cursor = cached['nextCursor'] as String?;
      _loading = false;
    }
    if (widget.isActive) _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_visible) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StudentCommunityHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _activated = true;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _load(quiet: true);
    }
  }

  Future<void> _load({bool quiet = false, bool more = false}) async {
    if (_busy) {
      await _loadDone?.future;
      return;
    }
    if (!widget.isActive || _mutating || (more && _cursor == null)) {
      return;
    }
    final revision = _revision;
    _busy = true;
    _loadDone = Completer<void>();
    try {
      final data = await communityInbox(before: more ? _cursor : null);
      if (!mounted || revision != _revision) return;
      final incoming = (data['conversations'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      // Refresh every loaded page so polling does not discard older chats.
      var nextCursor = data['nextCursor'] as String?;
      while (quiet && incoming.length < _rows.length && nextCursor != null) {
        final page = await communityInbox(before: nextCursor);
        if (!mounted || !_visible || revision != _revision) return;
        incoming.addAll((page['conversations'] as List)
            .map((e) => Map<String, dynamic>.from(e)));
        nextCursor = page['nextCursor'] as String?;
      }
      final oldIds = {for (final row in _rows) '${row['lastMessage']['_id']}'};
      final newMessages = incoming.where((r) =>
          r['muted'] != true &&
          r['lastMessage']['deletedAt'] == null &&
          (r['unreadCount'] as num) > 0 &&
          !oldIds.contains('${r['lastMessage']['_id']}'));
      if (quiet && !_loading && newMessages.isNotEmpty && _visible) {
        final row = newMessages.first;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_hubText(
                context,
                'رسالة جديدة من ${row['contact']['name']}',
                'New message from ${row['contact']['name']}')),
            action: SnackBarAction(
                label: _hubText(context, 'فتح', 'Open'),
                onPressed: () => _open(row['contact']))));
      }
      setState(() {
        _rows = more
            ? [
                ..._rows,
                ...incoming.where((r) => !_rows
                    .any((o) => o['contact']['_id'] == r['contact']['_id']))
              ]
            : incoming;
        _cursor = nextCursor;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && (!quiet || _loading)) {
        setState(() {
          _loading = false;
          _error = _hubText(
              context,
              'تعذر تحميل المحادثات. اضغط للمحاولة مجددًا',
              'Could not load conversations. Tap to retry.');
        });
      }
    } finally {
      _busy = false;
      _loadDone?.complete();
      _loadDone = null;
    }
  }

  Future<void> _open(dynamic contact) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ConversationThreadScreen(
              communityMode: true,
              contactId: '${contact['_id']}',
              contactName: '${contact['name']}',
              contactAvatar: '${contact['avatar'] ?? ''}')));
    } finally {
      _opening = false;
      if (mounted) _load();
    }
  }

  Future<void> _options(Map<String, dynamic> row) async {
    if (_mutating) return;
    final muted = row['muted'] == true;
    final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  title: Text('${row['contact']['name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              ListTile(
                  leading: Icon(muted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined),
                  title: Text(muted
                      ? _hubText(ctx, 'إلغاء الكتم', 'Unmute conversation')
                      : _hubText(ctx, 'كتم الإشعارات', 'Mute conversation')),
                  onTap: () => Navigator.pop(ctx, 'mute')),
              ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                      _hubText(ctx, 'حذف المحادثة', 'Delete conversation'),
                      style: const TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(ctx, 'delete')),
            ])));
    if (action == null || !mounted || _mutating) return;
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(
                      _hubText(ctx, 'حذف المحادثة؟', 'Delete conversation?')),
                  content: Text(_hubText(
                      ctx,
                      'ستُحذف من عندك فقط وتظهر من جديد إذا وصلت رسالة جديدة.',
                      'It will leave your inbox and return if a new message arrives.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(_hubText(ctx, 'إلغاء', 'Cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(_hubText(ctx, 'حذف', 'Delete')))
                  ]));
      if (confirmed != true || !mounted) return;
    }
    _mutating = true;
    _revision++;
    try {
      final path =
          '/mobile-workspace/conversations/${row['contact']['_id']}?community=1';
      if (action == 'delete') {
        await ApiClient.instance
            .delete(path, token: AuthSession.instance.token);
      } else {
        await ApiClient.instance.put(path,
            token: AuthSession.instance.token, body: {'muted': !muted});
      }
      if (mounted) {
        setState(() {
          if (action == 'delete') {
            _rows.removeWhere(
                (r) => r['contact']['_id'] == row['contact']['_id']);
          } else {
            row['muted'] = !muted;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_hubText(context, 'تعذر تنفيذ العملية، حاول مجددًا',
                'Could not complete the action. Try again.'))));
      }
    } finally {
      _mutating = false;
      if (mounted) _load(quiet: true);
    }
  }

  Future<void> _newChat() async {
    if (_opening) return;
    _opening = true;
    try {
      final contacts = (await ApiClient.instance.get(
        '/mobile-workspace/contacts?community=1',
        token: AuthSession.instance.token,
        cached: false,
      ) as List)
          .map((person) => Map<String, dynamic>.from(person as Map))
          .toList();
      if (!mounted) return;
      final person = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                    title: Text(
                        _hubText(ctx, 'محادثة جديدة', 'New conversation'))),
                Flexible(
                    child: contacts.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_hubText(
                                ctx,
                                'لا توجد جهات اتصال متاحة لحسابك',
                                'No contacts are available for your account.')),
                          )
                        : ListView(shrinkWrap: true, children: [
                            for (final contact in contacts)
                              ListTile(
                                leading: ContactProfileLink(
                                  userId: '${contact['_id']}',
                                  communityMode: true,
                                  child: CircleAvatar(
                                    backgroundImage:
                                        '${contact['avatar'] ?? ''}'.isEmpty
                                            ? null
                                            : NetworkImage(
                                                '${contact['avatar']}'),
                                    child: '${contact['avatar'] ?? ''}'.isEmpty
                                        ? const Icon(Icons.person_outline)
                                        : null,
                                  ),
                                ),
                                title: Text('${contact['name'] ?? ''}'),
                                onTap: () => Navigator.pop(ctx, contact),
                              ),
                          ])),
              ])));
      if (mounted && person != null) {
        _opening = false;
        await _open(person);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_hubText(context, 'تعذر تحميل جهات الاتصال',
                'Could not load contacts.'))));
      }
    } finally {
      _opening = false;
    }
  }

  String _time(dynamic raw) {
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) => !_activated
      ? const SizedBox.shrink()
      : Scaffold(
          key: const ValueKey('student-community-hub'),
          appBar: AppBar(
              title: Text(_hubText(context, 'المجتمع', 'Community')),
              actions: [
                IconButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const StudentCommunityScreen())),
                    icon: const Icon(Icons.feed_outlined),
                    tooltip: _hubText(context, 'المنشورات', 'Posts')),
              ]),
          body: RefreshIndicator(
              color: AppColors.navy,
              onRefresh: _refreshPage,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (AuthSession.instance.currentUser?.role == UserRole.admin)
                      const AdminCommunityControlCenter(),
                    StudentStories(
                        key: _storiesKey,
                        showCommunityButton: false,
                        isActive: widget.isActive),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  _hubText(context, 'المحادثات', 'Messages'),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold))),
                          TextButton.icon(
                              key: const ValueKey('community-new-chat'),
                              onPressed: _newChat,
                              icon: const Icon(Icons.add_comment_outlined),
                              label: Text(_hubText(
                                  context, 'محادثة جديدة', 'New message')))
                        ])),
                    if (_loading)
                      for (var i = 0; i < 6; i++)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(children: [
                            SkeletonBox(
                                width: 44, height: 44, borderRadius: 22),
                            SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  SkeletonBox(width: 120, height: 12),
                                  SizedBox(height: 9),
                                  SkeletonBox(height: 10),
                                ])),
                            SizedBox(width: 20),
                            SkeletonBox(width: 30, height: 8),
                          ]),
                        ),
                    if (_error != null)
                      TextButton(
                          onPressed: () => _load(), child: Text(_error!)),
                    if (!_loading && _error == null && _rows.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                              _hubText(
                                  context,
                                  'لا توجد محادثات بعد. ابحث عن زميل وابدأ محادثة معه.',
                                  'No conversations yet. Find a community member to start one.'),
                              textAlign: TextAlign.center)),
                    for (final row in _rows)
                      ListTile(
                          onTap: () => _open(row['contact']),
                          onLongPress: () => _options(row),
                          leading: ContactProfileLink(
                              userId: '${row['contact']['_id']}',
                              communityMode: true,
                              child: CircleAvatar(
                                  backgroundImage:
                                      '${row['contact']['avatar'] ?? ''}'
                                              .isEmpty
                                          ? null
                                          : NetworkImage(
                                              '${row['contact']['avatar']}'),
                                  child: '${row['contact']['avatar'] ?? ''}'
                                          .isEmpty
                                      ? const Icon(Icons.person_outline)
                                      : null)),
                          title: Text('${row['contact']['name']}',
                              style: TextStyle(
                                  fontWeight: (row['unreadCount'] as num) > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          subtitle: Text(
                              row['lastMessage']['deletedAt'] != null
                                  ? _hubText(context, 'تم حذف الرسالة',
                                      'Message deleted')
                                  : row['lastMessage']['imagePath'] != null
                                      ? _hubText(context, '📷 صورة', '📷 Photo')
                                      : '${row['lastMessage']['body']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (row['muted'] == true)
                                  const Icon(Icons.notifications_off_outlined,
                                      size: 15, color: AppColors.textSecondary),
                                Text(_time(row['lastMessage']['createdAt']),
                                    style: const TextStyle(fontSize: 11)),
                                if ((row['unreadCount'] as num) > 0)
                                  Badge(label: Text('${row['unreadCount']}'))
                              ])),
                    if (_cursor != null)
                      TextButton(
                          onPressed: () => _load(more: true),
                          child: Text(_hubText(
                              context, 'محادثات أقدم', 'Older conversations'))),
                  ])));
}
