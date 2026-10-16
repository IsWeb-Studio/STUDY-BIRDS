import 'student_profile_link.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/repositories/friends_repository.dart';
import '../stories/student_stories.dart';
import '../stories/friends_screen.dart';
import '../services_support/messaging_and_emergency_screens.dart';
import '../services_support/community_screen.dart';

Future<Map<String, dynamic>> communityInbox(
        {String? before, bool summary = false}) async =>
    Map<String, dynamic>.from(await ApiClient.instance.get(
        Uri(path: '/mobile-workspace/conversations', queryParameters: {
          if (before != null) 'before': before,
          if (summary) 'summary': '1',
        }).toString(),
        token: AuthSession.instance.token,
        cached: false));

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
                    backgroundColor: Color(0xFFE4F6EE),
                    child: Icon(Icons.forum_outlined,
                        color: Colors.teal, size: 27))),
            const SizedBox(height: 9),
            const Text('المجتمع', style: TextStyle(fontSize: 11)),
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
    if (!widget.isActive || _busy || _mutating || (more && _cursor == null)) {
      return;
    }
    final revision = _revision;
    _busy = true;
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
            content: Text('رسالة جديدة من ${row['contact']['name']}'),
            action: SnackBarAction(
                label: 'فتح', onPressed: () => _open(row['contact']))));
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
          _error = 'تعذر تحميل المحادثات. اضغط للمحاولة مجددًا';
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _open(dynamic contact) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ConversationThreadScreen(
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
                  title: Text(muted ? 'إلغاء الكتم' : 'كتم الإشعارات'),
                  onTap: () => Navigator.pop(ctx, 'mute')),
              ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('حذف المحادثة',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(ctx, 'delete')),
            ])));
    if (action == null || !mounted || _mutating) return;
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('حذف المحادثة؟'),
                  content: const Text(
                      'ستُحذف من عندك فقط وتظهر من جديد إذا وصلت رسالة جديدة.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف'))
                  ]));
      if (confirmed != true || !mounted) return;
    }
    _mutating = true;
    _revision++;
    try {
      final path = '/mobile-workspace/conversations/${row['contact']['_id']}';
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تنفيذ العملية، حاول مجددًا')));
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
      final friends = await FriendsRepository.instance.list('friends');
      if (!mounted) return;
      final person = await showModalBottomSheet<StudentFriend>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const ListTile(title: Text('محادثة جديدة')),
                Flexible(
                    child: ListView(shrinkWrap: true, children: [
                  for (final friend in friends.people)
                    ListTile(
                        leading: StudentProfileLink(
                            studentId: friend.id,
                            child: const CircleAvatar(
                                child: Icon(Icons.person_outline))),
                        title: Text(friend.name),
                        onTap: () => Navigator.pop(ctx, friend)),
                  ListTile(
                      leading: const Icon(Icons.person_add_alt),
                      title: const Text('البحث عن طالب أو عرض جميع الأصدقاء'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const FriendsScreen()));
                      }),
                ])),
              ])));
      _opening = false;
      if (mounted && person != null) {
        await _open(
            {'_id': person.id, 'name': person.name, 'avatar': person.avatar});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تحميل الأصدقاء، حاول مجددًا')));
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
          appBar: AppBar(title: const Text('المجتمع'), actions: [
            IconButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const StudentCommunityScreen())),
                icon: const Icon(Icons.feed_outlined),
                tooltip: 'المنشورات'),
            IconButton(
                onPressed: _newChat,
                icon: const Icon(Icons.edit_square),
                tooltip: 'محادثة جديدة')
          ]),
          body: RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    StudentStories(
                        showCommunityButton: false, isActive: widget.isActive),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          const Expanded(
                              child: Text('المحادثات',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold))),
                          TextButton.icon(
                              onPressed: _newChat,
                              icon: const Icon(Icons.add_comment_outlined),
                              label: const Text('محادثة جديدة'))
                        ])),
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null)
                      TextButton(
                          onPressed: () => _load(), child: Text(_error!)),
                    if (!_loading && _error == null && _rows.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                              'لا توجد محادثات بعد. ابحث عن طالب وابدأ محادثة معه.',
                              textAlign: TextAlign.center)),
                    for (final row in _rows)
                      ListTile(
                          onTap: () => _open(row['contact']),
                          onLongPress: () => _options(row),
                          leading: StudentProfileLink(
                              studentId: '${row['contact']['_id']}',
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
                                  ? 'تم حذف الرسالة'
                                  : row['lastMessage']['imagePath'] != null
                                      ? '📷 صورة'
                                      : '${row['lastMessage']['body']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (row['muted'] == true)
                                  const Icon(Icons.notifications_off_outlined,
                                      size: 15, color: Colors.blueGrey),
                                Text(_time(row['lastMessage']['createdAt']),
                                    style: const TextStyle(fontSize: 11)),
                                if ((row['unreadCount'] as num) > 0)
                                  Badge(label: Text('${row['unreadCount']}'))
                              ])),
                    if (_cursor != null)
                      TextButton(
                          onPressed: () => _load(more: true),
                          child: const Text('محادثات أقدم')),
                  ])));
}
