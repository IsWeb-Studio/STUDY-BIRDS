import '../../core/widgets/bird_points.dart';
import '../../core/widgets/gallery_access.dart';
import '../../core/widgets/state_widgets.dart';
import '../community/student_profile_link.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/auth_session.dart';
import '../../core/widgets/student_achievements.dart';
import '../../core/widgets/streak_restore.dart';
import 'friends_screen.dart';
import '../community/student_community_hub.dart';
import '../../core/repositories/friends_repository.dart';
import 'story_viewer.dart';
import 'story_loading_indicator.dart';
export 'story_viewer.dart' show StoryViewer;

/// The outer achievement ring is independent from the inner viewing ring.
class StoryRing extends StatelessWidget {
  final bool seen;
  final int points;
  final Widget child;
  final double size;
  const StoryRing(
      {super.key,
      required this.seen,
      required this.points,
      required this.child,
      this.size = 66});
  @override
  Widget build(BuildContext context) => Stack(children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: points >= 10000
                  ? Border.all(
                      color: studentAchievementRing(points)!,
                      width: points >= 100000 ? 3.5 : 2.5)
                  : null),
          child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: seen ? Colors.grey : Colors.blue, width: 2.5)),
              child: ClipOval(child: child)),
        ),
        if (points >= 200000)
          Positioned(
              right: 0,
              bottom: 0,
              child: StudentAchievementMark(points: points)),
      ]);
}

class StudentStories extends StatefulWidget {
  final bool isActive;
  final bool showCommunityButton;
  const StudentStories(
      {super.key, this.isActive = true, this.showCommunityButton = true});
  @override
  State<StudentStories> createState() => StudentStoriesState();
}

class StudentStoriesState extends State<StudentStories>
    with WidgetsBindingObserver {
  final _repo = StoriesRepository.instance;
  StoryProgress? _progress;
  List<StudentStory> _stories = [];
  String? _cursor, _error;
  bool _loading = true, _refreshing = false;
  Completer<void>? _loadDone;
  Future<void> refresh() => _load();
  final _seen = <String>{};
  Timer? _timer;
  Timer? _liveTimer;
  bool _liveRefreshing = false;
  final _liveCounts = <String, int>{};
  StreamSubscription<void>? _friendsSub;
  bool _openingFriends = false;
  bool _reloadAfterFriends = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cached = _repo.cachedFeed();
    if (cached != null) {
      _stories = cached.stories;
      _cursor = cached.nextCursor;
      _loading = false;
    }
    _load();
    _friendsSub = FriendsRepository.instance.changes.listen((_) {
      if (_refreshing) {
        _reloadAfterFriends = true;
      } else {
        _load();
      }
    });
    _timer =
        Timer.periodic(const Duration(minutes: 1), (_) => _load(quiet: true));
    _liveTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _refreshLive());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _liveTimer?.cancel();
    _friendsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(quiet: true);
  }

  @override
  void didUpdateWidget(covariant StudentStories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load(quiet: true);
  }

  bool get _visible =>
      widget.isActive &&
      (ModalRoute.isCurrentOf(context) ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  Future<void> _refreshLive() async {
    if (!mounted ||
        !_visible ||
        _liveRefreshing ||
        _refreshing ||
        _stories.isEmpty) {
      return;
    }
    _liveRefreshing = true;
    final requested = _stories.take(120).map((s) => s.id).toSet();
    try {
      final data = await _repo.updates(requested.toList());
      if (!mounted || !_visible) return;
      final updates = (data['updates'] as List).cast<Map<String, dynamic>>();
      final available = updates.map((s) => s['id'] as String).toSet();
      setState(() {
        _progress =
            StoryProgress.fromJson(Map<String, dynamic>.from(data['progress']));
        _stories.removeWhere(
            (s) => requested.contains(s.id) && !available.contains(s.id));
        for (final update in updates) {
          final id = update['id'] as String;
          _liveCounts[id] = (update['loveCount'] as num).toInt();
          if (update['seen'] == true) _seen.add(id);
        }
      });
    } catch (_) {
      /* A short-lived refresh failure keeps the last visible data. */
    } finally {
      _liveRefreshing = false;
    }
  }

  Future<void> _load({bool quiet = false, bool more = false}) async {
    if (_refreshing) {
      await _loadDone?.future;
      return;
    }
    if (quiet && !_visible) {
      return;
    }
    _refreshing = true;
    _loadDone = Completer<void>();
    try {
      // The feed already contains author scores; do not wait for a profile call.
      final page = await _repo.feed(more ? _cursor : null);
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (!quiet) _error = e.toString();
        });
      }
    } finally {
      _refreshing = false;
      _loadDone?.complete();
      _loadDone = null;
      if (_reloadAfterFriends && mounted) {
        _reloadAfterFriends = false;
        unawaited(_load());
      }
    }
  }

  Future<void> _compose() async {
    final posted = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const StoryComposer()));
    if (posted == true && mounted) await _load();
  }

  Future<void> _open(List<StudentStory> stories) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StoryViewer(
              stories: stories,
              onSeen: (id) {
                if (mounted) setState(() => _seen.add(id));
              },
            )));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<StudentStory>>{};
    for (final s
        in _stories.where((s) => s.expiresAt.isAfter(DateTime.now()))) {
      groups.putIfAbsent(s.authorId, () => []).add(s);
    }
    for (final stories in groups.values) {
      stories.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    }
    final p = _progress;
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('الستوريات المنشورة',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          ]),
          if (!_loading && _error == null && _stories.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا توجد ستوريات منشورة حاليًا. انشر أول ستوري!',
                    style: TextStyle(color: Colors.blueGrey))),
          Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                  icon: const Icon(Icons.people_outline),
                  label: const Text('الأصدقاء وطلبات الصداقة'),
                  onPressed: () async {
                    if (_openingFriends) return;
                    _openingFriends = true;
                    try {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const FriendsScreen()));
                      if (mounted) await _load();
                    } finally {
                      _openingFriends = false;
                    }
                  })),
          if (_error != null)
            TextButton(
                onPressed: () => _load(),
                child: Text('تعذر تحميل الستوريز. اضغط للمحاولة: $_error')),
          if (p != null && p.recoverableDays > 0)
            StreakRestore(
                progress: p,
                onRestored: (value) => setState(() => _progress = value)),
          SizedBox(
              height: 122,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                SizedBox(
                    width: 78,
                    child: InkWell(
                        onTap: _compose,
                        borderRadius: BorderRadius.circular(16),
                        child: const Column(children: [
                          SizedBox(height: 5),
                          CircleAvatar(
                              radius: 29,
                              backgroundColor: Color(0xFFEAF2FF),
                              child: Icon(Icons.add,
                                  size: 30, color: Colors.blue)),
                          SizedBox(height: 9),
                          Text('ستوري جديدة', style: TextStyle(fontSize: 11)),
                        ]))),
                if (widget.showCommunityButton)
                  CommunityEntry(isActive: widget.isActive),
                if (_loading)
                  for (var i = 0; i < 4; i++)
                    const SizedBox(
                        width: 78,
                        child: Column(children: [
                          SkeletonBox(width: 66, height: 66, borderRadius: 33),
                          SizedBox(height: 9),
                          SkeletonBox(width: 48, height: 10),
                        ])),
                for (final stories in groups.values)
                  SizedBox(
                      width: 78,
                      child: InkWell(
                          onTap: () => _open(stories),
                          borderRadius: BorderRadius.circular(16),
                          child: Column(children: [
                            StoryRing(
                                seen: stories.every(
                                    (s) => s.seen || _seen.contains(s.id)),
                                points: stories.first.authorId ==
                                        AuthSession.instance.currentUser?.id
                                    ? (p?.points ?? stories.first.authorPoints)
                                    : stories.first.authorPoints,
                                child: _StoryAvatar(
                                    name: stories.first.name,
                                    url: stories.first.avatar)),
                            const SizedBox(height: 6),
                            StudentProfileLink(
                                studentId: stories.first.authorId,
                                child: Text(stories.first.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11))),
                            const SizedBox(height: 3),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.favorite,
                                      size: 12, color: Colors.pinkAccent),
                                  const SizedBox(width: 3),
                                  Text(
                                      '${stories.fold<int>(0, (sum, story) => sum + (_liveCounts[story.id] ?? story.loveCount))}',
                                      style: const TextStyle(fontSize: 11)),
                                ]),
                          ]))),
                if (_cursor != null)
                  Center(
                      child: TextButton(
                          onPressed: () => _load(more: true),
                          child: const Text('المزيد'))),
              ])),
        ]));
  }
}

class _StoryAvatar extends StatelessWidget {
  final String name, url;
  const _StoryAvatar({required this.name, required this.url});
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
        color: const Color(0xFFEAF2FF),
        child: Center(
            child: Text(name.isEmpty ? '؟' : name.characters.first,
                style:
                    const TextStyle(fontSize: 23, color: Color(0xFF173459)))));
    return url.isEmpty
        ? fallback
        : Image.network(url,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
  }
}

class StoryProgressSheet extends StatefulWidget {
  final StoryProgress progress;
  final VoidCallback onPost;
  const StoryProgressSheet(
      {super.key, required this.progress, required this.onPost});
  @override
  State<StoryProgressSheet> createState() => _StoryProgressSheetState();
}

class _StoryProgressSheetState extends State<StoryProgressSheet> {
  StoryProgress? _restored;
  @override
  Widget build(BuildContext context) {
    final p = _restored ?? widget.progress;
    return SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  p.state == 'ice_cold'
                      ? Icons.ac_unit
                      : Icons.local_fire_department,
                  size: 48,
                  color: p.state == 'ice_cold'
                      ? Colors.lightBlue
                      : Colors.deepOrange),
              Text('${p.days}',
                  style: const TextStyle(
                      fontSize: 58, fontWeight: FontWeight.bold)),
              const Text('أيام متتالية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              StreakRestore(
                  progress: p,
                  onRestored: (value) => setState(() => _restored = value)),
              if (p.state == 'ice_cold')
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                        'الستريك متجمّد ❄️ انشر قبل ${p.resetsAt?.toLocal().toString().substring(0, 16) ?? ''} للحفاظ عليه.',
                        textAlign: TextAlign.center)),
              const SizedBox(height: 22),
              Text(
                  p.points >= 200000
                      ? 'فتحت شارة الإنجاز الزرقاء ✓'
                      : p.points >= 100000
                          ? 'فتحت الحلقة البنفسجية 💜'
                          : p.points >= 10000
                              ? 'فتحت الحلقة البرتقالية 🟠'
                              : 'اجمع 10,000 لفتح الحلقة البرتقالية',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                  value: (p.points / 10000).clamp(0.0, 1.0),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.orange),
              const SizedBox(height: 10),
              BirdPoints('${p.points} / 10,000',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              if (p.points >= 10000)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (p.points < 200000)
                        BirdPoints(
                            '${p.points} / ${p.points >= 100000 ? '200,000' : '100,000'}'),
                      Text(
                          p.points >= 200000
                              ? 'شارة إنجاز شكلية للمميزين بالنقاط'
                              : p.points >= 100000
                                  ? 'الشارة الشكلية القادمة'
                                  : 'الحلقة البنفسجية القادمة',
                          textAlign: TextAlign.center)
                    ])),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      p.posted ? Icons.check_circle : Icons.add_circle_outline,
                      color: Colors.blue),
                  title: const Text('انشر ستوري اليوم'),
                  subtitle: const Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [BirdPoints('+100'), Text('لأول ستوري فقط')]),
                  trailing: p.posted
                      ? const Text('تم ✓')
                      : TextButton(
                          onPressed: widget.onPost, child: const Text('انشر'))),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.favorite, color: Colors.pink),
                  title: const Text('اعمل لاف لزمايلك'),
                  subtitle: const Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        BirdPoints('+5'),
                        Text('لكل لاف • أول 10 يوميًا')
                      ]),
                  trailing: Text('${p.loves} / 10')),
              const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.favorite_border, color: Colors.orange),
                  title: Text('استقبل لاف من زميل'),
                  subtitle: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        BirdPoints('+50'),
                        Text('لكل طالب مختلف على نفس الستوري')
                      ])),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sports_esports,
                      color: Colors.deepPurple),
                  title: const Text('العب الغمّازة اليوم'),
                  subtitle: const Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        BirdPoints('+10'),
                        Text('مرة واحدة يوميًا عند بدء اللعب')
                      ]),
                  trailing: Text(p.playedToday ? 'تم ✓' : '+10')),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.emoji_events, color: Colors.orange),
                  title: const Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [Text('بونص الاستمرارية'), BirdPoints('+300')]),
                  subtitle: Text(
                      'كل 7 أيام متتالية • ${p.days % 7} / 7 للدورة القادمة')),
              const SizedBox(height: 8),
              Text(
                  'اليوم حسب ${p.timeZone}. تجميد بعد 24 ساعة من آخر نشر، وتصفير الستريك بعد 36 ساعة. نقاطك تفضل محفوظة.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ])));
  }
}

class StoryComposer extends StatefulWidget {
  const StoryComposer({super.key});
  @override
  State<StoryComposer> createState() => _StoryComposerState();
}

class _StoryComposerState extends State<StoryComposer> {
  final _text = TextEditingController();
  String _operationId = ApiClient.newOperationId();
  String _imageUrl = '';
  String _videoUrl = '';
  bool _isVideo = false, _picking = false;
  double _uploadProgress = 0;
  VideoPlayerController? _preview;
  Uint8List? _bytes;
  String? _name, _error;
  bool _busy = false;
  @override
  void dispose() {
    _preview?.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    VideoPlayerController? candidate;
    try {
      if (!await confirmGalleryAccess(context) || !mounted) return;
      final image = await ImagePicker()
          .pickMedia(maxWidth: 1600, maxHeight: 2000, imageQuality: 85);
      if (image == null) return;
      final video = (image.mimeType ?? '').startsWith('video/') ||
          RegExp(r'\.(mp4|mov|m4v|webm|3gp|mkv|avi)$', caseSensitive: false)
              .hasMatch(image.name);
      if (video &&
          !RegExp(r'\.(mp4|mov)$', caseSensitive: false).hasMatch(image.name)) {
        throw Exception('اختر فيديو بصيغة MP4 أو MOV');
      }
      if (await image.length() > (video ? 25 : 5) * 1024 * 1024) {
        throw Exception(video
            ? 'حجم الفيديو أكبر من 25 ميجابايت'
            : 'حجم الصورة أكبر من 5 ميجابايت');
      }
      if (video) {
        candidate = VideoPlayerController.file(File(image.path));
        await candidate.initialize().timeout(const Duration(seconds: 20));
        if (candidate.value.duration <= Duration.zero ||
            candidate.value.duration > const Duration(seconds: 60)) {
          throw Exception('اختر فيديو لا تتجاوز مدته دقيقة واحدة');
        }
      }
      final bytes = await image.readAsBytes();
      if (mounted) {
        final old = _preview;
        setState(() {
          _preview = candidate;
          candidate = null;
          _isVideo = video;
          _videoUrl = '';
          _error = null;
          _bytes = bytes;
          _name = image.name;
          _imageUrl = '';
          _operationId = ApiClient.newOperationId();
        });
        await old?.dispose();
      }
    } catch (e) {
      if (mounted) setState(() => _error = mediaPickerError(e));
    } finally {
      await candidate?.dispose();
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _post() async {
    if (_busy || _picking || (_text.text.trim().isEmpty && _bytes == null)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _uploadProgress = 0;
    });
    try {
      final repo = StoriesRepository.instance;
      await _preview?.pause();
      if (_bytes != null && _isVideo && _videoUrl.isEmpty) {
        _videoUrl =
            await repo.uploadVideo(_bytes!, _name!, onProgress: (value) {
          if (mounted) setState(() => _uploadProgress = value);
        });
      } else if (_bytes != null && !_isVideo && _imageUrl.isEmpty) {
        _imageUrl = await repo.upload(_bytes!, _name!, onProgress: (value) {
          if (mounted) setState(() => _uploadProgress = value);
        });
      }
      await repo.post(
          text: _text.text.trim(),
          imageUrl: _imageUrl,
          videoUrl: _videoUrl,
          operationId: _operationId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('ستوري جديدة')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('شارك يومك مع زمايلك',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
              'الستوري متاحة للطلاب لمدة 24 ساعة. أول ستوري في اليوم تكسبك 100 نقطة.'),
          const SizedBox(height: 20),
          if (_isVideo && _preview != null) ...[
            AspectRatio(
                aspectRatio: _preview!.value.aspectRatio,
                child: VideoPlayer(_preview!)),
            TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (_preview!.value.isPlaying) {
                          await _preview!.pause();
                        } else {
                          await _preview!.play();
                        }
                        if (mounted) setState(() {});
                      },
                icon: Icon(
                    _preview!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                label: const Text('معاينة الفيديو')),
          ] else if (_bytes != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(_bytes!, height: 280, fit: BoxFit.contain)),
          TextField(
              controller: _text,
              enabled: !_busy,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) {
                _operationId = ApiClient.newOperationId();
              },
              decoration:
                  const InputDecoration(hintText: 'إيه إنجازك النهارده؟')),
          OutlinedButton.icon(
              onPressed: _busy || _picking ? null : () => _pick(),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('اختيار صورة أو فيديو')),
          const Text('فيديو MP4 أو MOV • حتى دقيقة واحدة و25 ميجابايت',
              textAlign: TextAlign.center),
          if (_picking) const LinearProgressIndicator(),
          if (_busy)
            LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null),
          if (_bytes != null)
            TextButton(
                onPressed: _busy || _picking
                    ? null
                    : () => setState(() {
                          _bytes = null;
                          _imageUrl = '';
                          _videoUrl = '';
                          _isVideo = false;
                          final old = _preview;
                          _preview = null;
                          old?.dispose();
                          _operationId = ApiClient.newOperationId();
                        }),
                child: Text(_isVideo ? 'إزالة الفيديو' : 'إزالة الصورة')),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _busy || _picking ? null : _post,
              child: _busy
                  ? const Row(mainAxisSize: MainAxisSize.min, children: [
                      StoryLoadingIndicator(label: 'جارٍ نشر الستوري…'),
                      SizedBox(width: 10),
                      Text('جارٍ النشر…')
                    ])
                  : const Text('نشر الستوري')),
        ])),
      ));
}
