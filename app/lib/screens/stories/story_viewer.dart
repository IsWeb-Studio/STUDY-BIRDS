import '../community/student_profile_link.dart';
import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/auth_session.dart';
import 'story_loading_indicator.dart';
import 'story_viewers_screen.dart';

class StoryViewer extends StatefulWidget {
  final List<StudentStory> stories;
  final ValueChanged<String> onSeen;
  final Duration storyDuration;
  const StoryViewer(
      {super.key,
      required this.stories,
      required this.onSeen,
      this.storyDuration = const Duration(seconds: 5)})
      : assert(stories.length > 0);
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _index = 0;
  bool _closing = false, _ready = false, _held = false, _polling = false;
  bool _foreground = true;
  bool _attached = true;
  bool _deleting = false, _confirmingDelete = false, _showHeart = false;
  final _pendingLoves = <String>{};
  final _deleted = <String>{};
  Timer? _heartTimer;
  String? _pressedLoveId;
  double _dragOffset = 0;

  void _dragStart(DragStartDetails details) {
    _held = true;
    _clock.stop();
    if (_video != null) unawaited(_video!.pause());
  }

  void _dragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset = max(0, _dragOffset + details.delta.dy));
  }

  void _dragEnd(DragEndDetails details) {
    if (_dragOffset > 100 ||
        (_dragOffset > 20 && (details.primaryVelocity ?? 0) > 650)) {
      _closing = true;
      Navigator.of(context).pop();
      return;
    }
    _cancelDrag();
  }

  void _cancelDrag() {
    if (!mounted || !_attached || _closing) return;
    setState(() => _dragOffset = 0);
    _held = false;
    _resume();
  }

  int _loveRevision = 0;
  late final AnimationController _clock;
  Timer? _liveTimer;
  VideoPlayerController? _video;
  bool _videoFailed = false;
  final _loved = <String>{};
  final _counts = <String, int>{};
  final _views = <String, int>{};

  Future<void> _openViewers() async {
    if (_held || _closing) return;
    final id = _story.id;
    _held = true;
    _clock.stop();
    try {
      await _video?.pause();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoryViewersScreen(storyId: id)),
      );
    } finally {
      _held = false;
      if (mounted && !_closing) {
        _resume();
        unawaited(_refreshLive());
      }
    }
  }

  final _seen = <String>{};
  String? _error;
  StudentStory get _story => widget.stories[_index];
  bool get _visible => _foreground && (ModalRoute.isCurrentOf(context) ?? true);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _clock = AnimationController(vsync: this, duration: widget.storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && !_closing) {
          _move(1);
        }
      });
    _liveTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _refreshLive());
    _begin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _resume();
    if (_foreground) _refreshLive();
  }

  @override
  void deactivate() {
    _attached = false;
    _clock.stop();
    if (_video != null) unawaited(_video!.pause());
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _attached = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTimer?.cancel();
    _heartTimer?.cancel();
    _disposeVideo();
    _clock.dispose();
    super.dispose();
  }

  void _resume() {
    if (!mounted || !_attached || _closing) return;
    if (_ready && !_held && _visible) {
      if (_video != null && !_videoFailed) {
        unawaited(_video!.play());
      } else if (!_clock.isAnimating) {
        _clock.forward();
      }
    } else {
      _clock.stop();
      if (_video != null) unawaited(_video!.pause());
    }
  }

  void _disposeVideo() {
    final old = _video;
    _video = null;
    if (old != null) {
      old.removeListener(_videoTick);
      unawaited(old.dispose());
    }
  }

  Future<void> _loadVideo(StudentStory story) async {
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(story.videoUrl));
    _video = controller;
    controller.addListener(_videoTick);
    try {
      await controller.initialize().timeout(const Duration(seconds: 30));
      if (!mounted || _video != controller || _closing) return;
      if (controller.value.duration <= Duration.zero) {
        throw StateError('Empty video');
      }
      setState(() {});
      _contentReady(story.id);
    } catch (_) {
      if (!mounted || _video != controller || _closing) return;
      _failVideo(story.id);
    }
  }

  void _failVideo(String id) {
    if (_videoFailed) return;
    _videoFailed = true;
    _ready = false;
    _clock.reset();
    _clock.duration = widget.storyDuration;
    setState(() {});
    _contentReady(id, viewed: _story.text.isNotEmpty);
  }

  void _videoTick() {
    final controller = _video;
    if (!mounted || _closing || controller == null || _videoFailed) return;
    final value = controller.value;
    if (value.hasError) {
      _failVideo(_story.id);
      return;
    }
    if (!_ready || !value.isInitialized || value.duration.inMilliseconds <= 0) {
      return;
    }
    // Video progress follows decoded playback, so buffering never consumes its time.
    if (value.position >= value.duration) {
      _move(1);
      return;
    }
    _clock.value =
        (value.position.inMilliseconds / value.duration.inMilliseconds)
            .clamp(0.0, .999999);
  }

  void _begin() {
    _disposeVideo();
    _videoFailed = false;
    _clock.duration = widget.storyDuration;
    _clock.reset();
    _ready = false;
    _held = false;
    final story = _story;
    if (story.videoUrl.isNotEmpty && story.expiresAt.isAfter(DateTime.now())) {
      unawaited(_loadVideo(story));
    } else if (story.imageUrl.isEmpty ||
        !story.expiresAt.isAfter(DateTime.now())) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _contentReady(story.id));
    }
  }

  void _contentReady(String id, {bool viewed = true}) {
    if (!mounted || _closing || _story.id != id || _ready) return;
    _ready = true;
    if (viewed) unawaited(_markSeen());
    _resume();
  }

  Future<void> _markSeen() async {
    final story = _story;
    if (_seen.contains(story.id)) return;
    try {
      await StoriesRepository.instance.seen(story.id);
      if (!mounted) return;
      _seen.add(story.id);
      widget.onSeen(story.id);
    } catch (e) {
      if (mounted && _story.id == story.id) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _refreshLive() async {
    if (!mounted || _closing || !_visible || _polling || _deleting) return;
    _polling = true;
    final id = _story.id;
    final revision = _loveRevision;
    try {
      final data = await StoriesRepository.instance.updates([id]);
      if (!mounted || _closing || !_visible || _deleting || _story.id != id)
        return;
      final updates = data['updates'] as List;
      if (updates.isEmpty) {
        _move(1);
        return;
      }
      final views = (updates.first as Map)['viewCount'];
      if (views is num) setState(() => _views[id] = views.toInt());
      if (!_pendingLoves.contains(id) && revision == _loveRevision) {
        final update = updates.first as Map;
        setState(() {
          _counts[id] = max(_counts[id] ?? _story.loveCount,
              (update['loveCount'] as num).toInt());
          if (update['loved'] == true) _loved.add(id);
        });
      }
    } catch (_) {/* Retry quietly on the next visible tick. */} finally {
      _polling = false;
    }
  }

  void _move(int step) {
    if (_closing) return;
    var next = _index + step;
    while (next >= 0 &&
        next < widget.stories.length &&
        _deleted.contains(widget.stories[next].id)) {
      next += step;
    }
    if (next >= widget.stories.length) {
      _closing = true;
      _clock.stop();
      if (_video != null) unawaited(_video!.pause());
      _liveTimer?.cancel();
      Navigator.pop(context);
      return;
    }
    if (next < 0) return;
    setState(() {
      _index = next;
      _showHeart = false;
      _error = null;
      _begin();
    });
  }

  Future<void> _love() async {
    final story = _story;
    if (_pendingLoves.contains(story.id) ||
        _deleting ||
        !story.expiresAt.isAfter(DateTime.now()) ||
        story.loved ||
        _loved.contains(story.id)) {
      return;
    }
    final previous = _counts[story.id] ?? story.loveCount;
    _loveRevision++;
    setState(() {
      _pendingLoves.add(story.id);
      _showHeart = true;
      _error = null;
      _loved.add(story.id);
      _counts[story.id] = previous + 1;
    });
    _heartTimer?.cancel();
    _heartTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showHeart = false);
    });
    try {
      final result = await StoriesRepository.instance.love(story.id);
      if (mounted) {
        setState(() => _counts[story.id] =
            max(previous + 1, (result['loveCount'] as num).toInt()));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loved.remove(story.id);
          _counts[story.id] = previous;
          if (_story.id == story.id) _error = e.toString();
        });
      }
    } finally {
      _loveRevision++;
      if (mounted) setState(() => _pendingLoves.remove(story.id));
    }
  }

  Future<void> _deleteStory() async {
    if (_deleting ||
        _confirmingDelete ||
        _story.authorId != AuthSession.instance.currentUser?.id) return;
    _confirmingDelete = true;
    _held = true;
    _clock.stop();
    final id = _story.id;
    try {
      await _video?.pause();
      if (!mounted) return;
      final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('حذف الستوري؟'),
                content: const Text(
                    'ستختفي الستوري من عند الجميع. نقاطك المكتسبة ستبقى محفوظة.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف')),
                ],
              ));
      if (confirm != true || !mounted) return;
      setState(() => _deleting = true);
      await StoriesRepository.instance.deleteStory(id);
      if (!mounted) return;
      _deleted.add(id);
      _move(1);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر حذف الستوري. حاول مجدداً.');
    } finally {
      _deleting = false;
      _confirmingDelete = false;
      _held = false;
      if (mounted && !_closing) {
        setState(() {});
        _resume();
      }
    }
  }

  Widget _image(StudentStory story) => Image.network(story.imageUrl,
          key: ValueKey(story.id), fit: BoxFit.contain,
          frameBuilder: (context, child, frame, synchronous) {
        if (synchronous || frame != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _contentReady(story.id));
          return child;
        }
        return const Padding(
            padding: EdgeInsets.all(32),
            child: StoryLoadingIndicator());
      }, errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _contentReady(story.id, viewed: story.text.isNotEmpty));
        return const Padding(
            padding: EdgeInsets.all(24),
            child: Icon(Icons.broken_image_outlined,
                color: Colors.white, size: 64));
      });
  Widget _storyCard(StudentStory story, bool expired) =>
      LayoutBuilder(builder: (context, bounds) {
        final hasMedia = story.imageUrl.isNotEmpty || story.videoUrl.isNotEmpty;
        return Center(
            child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: 430, maxHeight: bounds.maxHeight * .96),
          child: Container(
            key: const ValueKey('story-card'),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF121820),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (expired)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('انتهت صلاحية الستوري',
                        style: TextStyle(color: Colors.white))),
              if (!expired && hasMedia)
                Flexible(
                    flex: 3,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                            width: double.infinity,
                            child: story.imageUrl.isNotEmpty
                                ? _image(story)
                                : _videoFailed
                                    ? const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text('تعذر تشغيل الفيديو',
                                            style:
                                                TextStyle(color: Colors.white)))
                                    : _video?.value.isInitialized == true
                                        ? FittedBox(
                                            fit: BoxFit.contain,
                                            child: SizedBox(
                                                width: _video!.value.size.width,
                                                height:
                                                    _video!.value.size.height,
                                                child: VideoPlayer(_video!)))
                                        : const Padding(
                                            padding: EdgeInsets.all(32),
                                            child: StoryLoadingIndicator())))),
              if (!expired && story.text.isNotEmpty)
                Flexible(
                    child: Padding(
                        padding:
                            EdgeInsets.only(top: hasMedia ? 12 : 8, bottom: 8),
                        child: SingleChildScrollView(
                            child: Text(story.text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 20,
                                    height: 1.5,
                                    color: Colors.white))))),
            ]),
          ),
        ));
      });

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final loved = story.loved || _loved.contains(story.id);
    final expired = !story.expiresAt.isAfter(DateTime.now());
    return Scaffold(
      backgroundColor: const Color(0xFF080C12),
      appBar: AppBar(
          backgroundColor: const Color(0xFF080C12),
          foregroundColor: Colors.white,
          title: StudentIdentity(
              id: story.authorId, name: story.name, avatar: story.avatar),
          actions: [
            if (story.authorId == AuthSession.instance.currentUser?.id)
              IconButton(
                  tooltip: 'حذف الستوري',
                  onPressed: _deleting ? null : _deleteStory,
                  icon: _deleting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.delete_outline_rounded)),
            IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded)),
          ]),
      body: GestureDetector(
          onVerticalDragStart: _dragStart,
          onVerticalDragUpdate: _dragUpdate,
          onVerticalDragEnd: _dragEnd,
          onVerticalDragCancel: _cancelDrag,
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
              child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AnimatedBuilder(
                            animation: _clock,
                            builder: (_, __) => Row(
                                children: List.generate(
                                    widget.stories.length,
                                    (i) => Expanded(
                                        child: Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: LinearProgressIndicator(
                                                key: ValueKey('story-timer-$i'),
                                                value: i < _index
                                                    ? 1
                                                    : i == _index
                                                        ? _clock.value
                                                        : 0,
                                                minHeight: 5,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                backgroundColor: Colors.white24,
                                                color: Colors.pinkAccent))))))),
                    Expanded(
                        child: LayoutBuilder(
                            builder: (context, bounds) => GestureDetector(
                                key: const ValueKey('story-content'),
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (tap) => _move(
                                    tap.localPosition.dx < bounds.maxWidth / 2
                                        ? 1
                                        : -1),
                                onDoubleTap: _love,
                                onLongPressStart: (_) {
                                  _held = true;
                                  _clock.stop();
                                  if (_video != null) {
                                    unawaited(_video!.pause());
                                  }
                                },
                                onLongPressEnd: (_) {
                                  _held = false;
                                  _resume();
                                },
                                onHorizontalDragEnd: (d) => _move(
                                    (d.primaryVelocity ?? 0) < 0 ? 1 : -1),
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      _storyCard(story, expired),
                                      IgnorePointer(
                                          child: AnimatedOpacity(
                                              opacity: _showHeart ? 1 : 0,
                                              duration: const Duration(
                                                  milliseconds: 120),
                                              child: AnimatedScale(
                                                  scale: _showHeart ? 1 : .6,
                                                  duration: const Duration(
                                                      milliseconds: 180),
                                                  child: const Icon(
                                                      Icons.favorite_rounded,
                                                      size: 82,
                                                      color:
                                                          Colors.pinkAccent)))),
                                    ])))),
                    if (_error != null)
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orange)),
                    if (story.authorId == AuthSession.instance.currentUser?.id)
                  TextButton.icon(
                    key: const ValueKey('story-viewers-button'),
                    onPressed: expired ? null : _openViewers,
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.white,
                    ),
                    label: Text(
                      '${_views[story.id] ?? story.viewCount ?? 0} مشاهد',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Tooltip(
                                  message:
                                      loved ? 'أعجبك هذا الستوري' : 'إرسال لاف',
                                  child: Listener(
                                      onPointerDown: (_) {
                                        _pressedLoveId = story.id;
                                        _love();
                                      },
                                      onPointerCancel: (_) =>
                                          _pressedLoveId = null,
                                      onPointerUp: (_) => scheduleMicrotask(
                                          () => _pressedLoveId = null),
                                      child: TextButton.icon(
                                          key: const ValueKey(
                                              'story-love-button'),
                                          style: TextButton.styleFrom(
                                              minimumSize: const Size(144, 72),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 36, vertical: 22),
                                              backgroundColor: Colors.pinkAccent
                                                  .withValues(alpha: .14)),
                                          onPressed: expired ||
                                                  loved ||
                                                  _pendingLoves
                                                      .contains(story.id) ||
                                                  _deleting
                                              ? null
                                              : () {
                                                  if (_pressedLoveId ==
                                                      story.id) return;
                                                  _love();
                                                },
                                          icon: Icon(loved ? Icons.favorite : Icons.favorite_border,
                                              color: Colors.pinkAccent,
                                              size: 20),
                                          label: Text('${_counts[story.id] ?? story.loveCount}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold))))),
                            ])),
                    const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white54, size: 22)),
                  ])))),
    );
  }
}
