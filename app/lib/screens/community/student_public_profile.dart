import '../../core/widgets/bird_points.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/friends_repository.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/auth_session.dart';
import '../../core/widgets/student_achievements.dart';
import '../stories/student_stories.dart';
import '../services_support/messaging_and_emergency_screens.dart';

class StudentPublicProfileScreen extends StatefulWidget {
  final String studentId;
  const StudentPublicProfileScreen({super.key, required this.studentId});
  @override
  State<StudentPublicProfileScreen> createState() =>
      _StudentPublicProfileScreenState();
}

class _StudentPublicProfileScreenState
    extends State<StudentPublicProfileScreen> {
  Map<String, dynamic>? _profile;
  List<StudentStory> _stories = [];
  final _seen = <String>{};
  String? _cursor, _error;
  bool _loading = true, _busy = false, _opening = false;
  int _generation = 0;
  Future<void> _load({bool more = false}) async {
    if (more && (_busy || _cursor == null)) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uri = Uri(
          path: '/friends/${widget.studentId}/profile',
          queryParameters: {if (more) 'before': _cursor!});
      final data = Map<String, dynamic>.from(await ApiClient.instance.get(
          uri.toString(),
          token: AuthSession.instance.token,
          cached: false));
      if (!mounted || generation != _generation) return;
      final stories = (data['stories'] as List? ?? [])
          .map((s) => StudentStory.fromJson(Map<String, dynamic>.from(s)))
          .toList();
      setState(() {
        _profile = data;
        _stories = more
            ? [
                ..._stories,
                ...stories.where((s) => !_stories.any((old) => old.id == s.id))
              ]
            : stories;
        _cursor = data['nextStoriesCursor'] as String?;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = error is ApiException && error.statusCode == 404
              ? 'هذا الملف غير متاح حاليًا'
              : 'تعذر تحميل الملف. حاول مجددًا';
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _friendAction(String action) async {
    if (_busy) return;
    if (action == 'remove' && _profile?['relation'] == 'friends') {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('إزالة الصديق؟'),
                  content: const Text(
                      'لن تظهر يومياتكما لبعضكما بعد الإزالة. يمكنكما متابعة المراسلة.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('إزالة'))
                  ]));
      if (confirmed != true || !mounted || _busy) return;
    }
    setState(() => _busy = true);
    try {
      await FriendsRepository.instance.change(widget.studentId, action);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تنفيذ العملية. حاول مجددًا')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _message() async {
    if (_opening || _profile?['canMessage'] != true) return;
    _opening = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ConversationThreadScreen(
              contactId: widget.studentId,
              contactName: '${_profile!['name']}',
              contactAvatar: '${_profile!['avatar'] ?? ''}')));
    } finally {
      _opening = false;
      if (mounted) _load();
    }
  }

  Future<void> _viewStories([int start = 0]) async {
    if (_opening || _stories.isEmpty) return;
    final stories =
        _stories.where((s) => s.expiresAt.isAfter(DateTime.now())).toList();
    if (stories.isEmpty || start >= stories.length) {
      _load();
      return;
    }
    _opening = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StoryViewer(
              stories: stories.skip(start).toList(),
              onSeen: (id) {
                if (mounted) setState(() => _seen.add(id));
              })));
    } finally {
      _opening = false;
      if (mounted) _load();
    }
  }

  Widget _stat(String value, String label, {Widget? icon}) => Expanded(
          child: Column(children: [
        SizedBox(
            height: 32,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[icon, const SizedBox(width: 4)],
                  Text(value,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.bold))
                ]))),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      ]));
  Widget _friendButton(String relation) => switch (relation) {
        'friends' => OutlinedButton.icon(
            onPressed: _busy ? null : () => _friendAction('remove'),
            icon: const Icon(Icons.how_to_reg_outlined),
            label: const Text('أصدقاء')),
        'outgoing' => OutlinedButton.icon(
            onPressed: _busy ? null : () => _friendAction('remove'),
            icon: const Icon(Icons.schedule),
            label: const Text('إلغاء الطلب')),
        'incoming' => Wrap(spacing: 8, children: [
            OutlinedButton.icon(
                onPressed: _busy ? null : () => _friendAction('accept'),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('قبول الصداقة')),
            TextButton(
                onPressed: _busy ? null : () => _friendAction('remove'),
                child: const Text('رفض')),
          ]),
        _ => OutlinedButton.icon(
            onPressed: _busy ? null : () => _friendAction('request'),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('إضافة صديق')),
      };

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final points = (p?['total_points'] as num?)?.toInt() ?? 0;
    final canView = p?['canViewStories'] == true;
    return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(title: const Text('الملف الشخصي'), actions: [
          IconButton(
              onPressed: _busy ? null : () => _load(),
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث')
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : p == null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error ?? 'الملف غير متاح'),
                    TextButton(
                        onPressed: () => _load(),
                        child: const Text('إعادة المحاولة'))
                  ]))
                : RefreshIndicator(
                    onRefresh: () => _load(),
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_busy) const LinearProgressIndicator(),
                          if (_error != null)
                            TextButton(
                                onPressed: () => _load(), child: Text(_error!)),
                          Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24)),
                              child: Column(children: [
                                InkWell(
                                    onTap: _stories.isEmpty
                                        ? null
                                        : () => _viewStories(),
                                    borderRadius: BorderRadius.circular(60),
                                    child: StoryRing(
                                        size: 108,
                                        seen: _stories.isEmpty ||
                                            _stories.every((s) =>
                                                s.seen || _seen.contains(s.id)),
                                        points: points,
                                        child: p['avatar'] is String &&
                                                (p['avatar'] as String)
                                                    .isNotEmpty
                                            ? Image.network(p['avatar'],
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, error,
                                                        stack) =>
                                                    const Icon(Icons.person,
                                                        size: 55,
                                                        color: Colors.blueGrey))
                                            : const ColoredBox(
                                                color: Color(0xFFE8EEFC),
                                                child: Icon(
                                                    Icons.person_outline,
                                                    size: 55,
                                                    color: Colors.blueGrey)))),
                                const SizedBox(height: 14),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                          child: Text('${p['name']}',
                                              style: const TextStyle(
                                                  fontSize: 23,
                                                  fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.center)),
                                      const SizedBox(width: 6),
                                      StudentAchievementMark(points: points)
                                    ]),
                                const SizedBox(height: 6),
                                const Text('طالب في مجتمع Study Birds',
                                    style: TextStyle(color: Colors.blueGrey)),
                                if (p['relation'] == 'self')
                                  const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Chip(label: Text('ملفك العام'))),
                                const SizedBox(height: 22),
                                Row(children: [
                                  _stat('$points', 'السكور',
                                      icon: const BirdPointsIcon()),
                                  _stat('${p['streak_days'] ?? 0}',
                                      'أيام متتالية'),
                                  _stat('${p['friendCount'] ?? 0}', 'الأصدقاء')
                                ]),
                                if (p['relation'] != 'self') ...[
                                  const SizedBox(height: 22),
                                  Wrap(
                                      spacing: 10,
                                      runSpacing: 6,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        if (p['canMessage'] == true)
                                          FilledButton.icon(
                                              onPressed: _message,
                                              icon: const Icon(
                                                  Icons.chat_bubble_outline),
                                              label: const Text('مراسلة')),
                                        _friendButton('${p['relation']}'),
                                      ]),
                                ],
                              ])),
                          const SizedBox(height: 24),
                          Row(children: [
                            const Icon(Icons.auto_stories_outlined, size: 21),
                            const SizedBox(width: 8),
                            const Expanded(
                                child: Text('اليوميات',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 19))),
                            if (canView)
                              Text('${p['storyCount'] ?? _stories.length}',
                                  style:
                                      const TextStyle(color: Colors.blueGrey))
                          ]),
                          const SizedBox(height: 12),
                          if (!canView)
                            const _ProfileNotice(
                                icon: Icons.lock_outline,
                                text:
                                    'أضف هذا الطالب كصديق لتشاهد يومياته بعد قبول الطلب.')
                          else if (_stories.isEmpty)
                            const _ProfileNotice(
                                icon: Icons.auto_stories_outlined,
                                text: 'لا توجد يوميات متاحة حاليًا')
                          else
                            GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _stories.length,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 180,
                                        childAspectRatio: .78,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10),
                                itemBuilder: (context, index) {
                                  final story = _stories[index];
                                  return InkWell(
                                      onTap: () => _viewStories(index),
                                      borderRadius: BorderRadius.circular(18),
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                if (story.imageUrl.isNotEmpty)
                                                  Image.network(story.imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (ctx, error, stack) => const ColoredBox(
                                                          color:
                                                              Color(0xFFDDE6F7),
                                                          child: Icon(Icons
                                                              .image_outlined)))
                                                else
                                                  Container(
                                                      color: story.videoUrl.isNotEmpty
                                                          ? const Color(
                                                              0xFF24385C)
                                                          : const Color(
                                                              0xFF4169E1),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      alignment:
                                                          Alignment.center,
                                                      child: story.videoUrl.isNotEmpty
                                                          ? const Icon(Icons.play_circle_outline,
                                                              size: 42,
                                                              color:
                                                                  Colors.white)
                                                          : Text(story.text,
                                                              maxLines: 5,
                                                              overflow: TextOverflow
                                                                  .ellipsis,
                                                              textAlign: TextAlign.center,
                                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                                                Positioned(
                                                    bottom: 6,
                                                    left: 6,
                                                    child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 7,
                                                                vertical: 3),
                                                        decoration: BoxDecoration(
                                                            color:
                                                                Colors.black54,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                        child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .favorite,
                                                                  size: 12,
                                                                  color: Colors
                                                                      .pinkAccent),
                                                              const SizedBox(
                                                                  width: 3),
                                                              Text(
                                                                  '${story.loveCount}',
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          11))
                                                            ]))),
                                              ])));
                                }),
                          if (_cursor != null)
                            TextButton(
                                onPressed:
                                    _busy ? null : () => _load(more: true),
                                child: const Text('يوميات أكثر')),
                        ])));
  }
}

class _ProfileNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProfileNotice({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Icon(icon, color: Colors.blueGrey, size: 34),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey))
      ]));
}
