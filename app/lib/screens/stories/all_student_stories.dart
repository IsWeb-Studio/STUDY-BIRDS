import 'package:flutter/material.dart';
import '../../core/repositories/stories_repository.dart';
import '../community/student_profile_link.dart';
import 'story_viewer.dart';

class AllStudentStoriesScreen extends StatefulWidget {
  const AllStudentStoriesScreen({super.key});
  @override
  State<AllStudentStoriesScreen> createState() =>
      _AllStudentStoriesScreenState();
}

class _AllStudentStoriesScreenState extends State<AllStudentStoriesScreen> {
  List<StudentStory> _stories = [];
  String? _cursor, _error;
  bool _loading = true, _busy = false, _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy || (more && _cursor == null)) return;
    _busy = true;
    try {
      final page = await StoriesRepository.instance.feed(more ? _cursor : null);
      if (!mounted) return;
      setState(() {
        _stories = more
            ? [
                ..._stories,
                ...page.stories
                    .where((s) => !_stories.any((old) => old.id == s.id))
              ]
            : page.stories;
        _cursor = page.nextCursor;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل الستوريات. اضغط للمحاولة مجددًا';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(StudentStory story) async {
    if (_opening) return;
    _opening = true;
    try {
      final active =
          _stories.where((s) => s.expiresAt.isAfter(DateTime.now())).toList();
      final start = active.indexWhere((s) => s.id == story.id);
      if (start < 0) {
        await _load();
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StoryViewer(
              stories: active.skip(start).toList(), onSeen: (_) {})));
    } finally {
      _opening = false;
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('كل الستوريات'), actions: [
        IconButton(
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث')
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const Text('الستوريات المنشورة خلال آخر 24 ساعة',
                        style: TextStyle(color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    if (_error != null)
                      TextButton(
                          onPressed: () => _load(), child: Text(_error!)),
                    if (_error == null && _stories.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('لا توجد ستوريات منشورة حاليًا',
                              textAlign: TextAlign.center)),
                    for (final story in _stories)
                      Card(
                          clipBehavior: Clip.antiAlias,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: StudentIdentity(
                                        id: story.authorId,
                                        name: story.name,
                                        avatar: story.avatar)),
                                InkWell(
                                    onTap: () => _open(story),
                                    child: SizedBox(
                                        height: 240,
                                        child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              if (story.imageUrl.isNotEmpty)
                                                Image.network(story.imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error, stack) =>
                                                        const ColoredBox(
                                                            color: Color(
                                                                0xFFE8EEFC),
                                                            child:
                                                                Icon(Icons.image_outlined,
                                                                    size: 48)))
                                              else
                                                Container(
                                                    color:
                                                        const Color(0xFF173B70),
                                                    padding: const EdgeInsets.all(
                                                        24),
                                                    alignment: Alignment.center,
                                                    child: story.videoUrl.isNotEmpty
                                                        ? const Icon(Icons.play_circle_outline,
                                                            size: 64,
                                                            color: Colors.white)
                                                        : Text(story.text,
                                                            textAlign:
                                                                TextAlign.center,
                                                            maxLines: 6,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(color: Colors.white, fontSize: 22))),
                                              const Positioned(
                                                  bottom: 12,
                                                  left: 12,
                                                  child: Chip(
                                                      label:
                                                          Text('عرض الستوري'),
                                                      avatar: Icon(
                                                          Icons.play_arrow,
                                                          size: 18))),
                                            ]))),
                              ])),
                    if (_cursor != null)
                      TextButton(
                          onPressed: _busy ? null : () => _load(more: true),
                          child: const Text('تحميل المزيد')),
                  ])));
}
