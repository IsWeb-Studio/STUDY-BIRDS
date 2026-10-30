import '../../core/config/app_theme.dart';
import '../community/student_profile_link.dart';
import '../../core/widgets/safety_controls.dart';
import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/auth_session.dart';
import 'story_loading_indicator.dart';
import 'story_viewers_screen.dart';

bool _viewerIsArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _viewerText(BuildContext context, String arabic, String english) =>
    _viewerIsArabic(context) ? arabic : english;

String _viewerExpiryText(BuildContext context, DateTime expiresAt) {
  final remaining = expiresAt.difference(DateTime.now());
  if (remaining <= Duration.zero) {
    return _viewerText(context, 'انتهت مدة الستوري', 'Story expired');
  }
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  return _viewerIsArabic(context)
      ? 'تنتهي خلال $hours س و$minutes د'
      : 'Expires in ${hours}h ${minutes}m';
}

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
  bool _confirmingDelete = false, _showHeart = false;
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
  String? _sessionIdentity;
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
          MaterialPageRoute(builder: (_) => StoryViewersScreen(storyId: id)));
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
    _sessionIdentity = _currentSessionIdentity;
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _clock = AnimationController(vsync: this, duration: widget.storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && !_closing) {
          _move(1);
        }
      });
    AuthSession.instance.addListener(_onSessionChanged);
    _liveTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _refreshLive());
    _begin();
  }

  String? get _currentSessionIdentity {
    final user = AuthSession.instance.currentUser;
    return user == null ? null : '${user.id}:${user.role.name}';
  }

  void _onSessionChanged() {
    if (_currentSessionIdentity == _sessionIdentity || _closing) return;
    _closing = true;
    _clock.stop();
    _disposeVideo();
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route == null || !route.isActive || route.isFirst) return;
        final navigator = Navigator.of(context);
        // If the viewers list is open above this route, remove that nested
        // page first, then remove this exact story route without an animation
        // that could reveal cached story content during logout/account switch.
        navigator.popUntil((candidate) => identical(candidate, route));
        if (route.isActive) navigator.removeRoute(route);
      });
    }
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
    AuthSession.instance.removeListener(_onSessionChanged);
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
        setState(() => _error = _viewerText(context,
            'تعذر تحميل محتوى الستوري.', 'Could not load this story.'));
      }
    }
  }

  Future<void> _refreshLive() async {
    if (!mounted || _closing || !_visible || _polling) return;
    _polling = true;
    final id = _story.id;
    final revision = _loveRevision;
    try {
      final data = await StoriesRepository.instance.updates([id]);
      if (!mounted || _closing || !_visible || _story.id != id) return;
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

  void _move(int step, {bool removeDeletedRoute = false}) {
    if (_closing) return;
    var next = _index + step;
    while (next >= 0 &&
        next < widget.stories.length &&
        (_deleted.contains(widget.stories[next].id) ||
            StoriesRepository.instance.isHidden(widget.stories[next].id))) {
      next += step;
    }
    if (next >= widget.stories.length) {
      _closing = true;
      _clock.stop();
      if (_video != null) unawaited(_video!.pause());
      _liveTimer?.cancel();
      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);
      if (removeDeletedRoute && route != null) {
        // The confirmation dialog may still be finishing its pop animation.
        // Remove this exact viewer instead of accidentally popping the dialog.
        navigator.removeRoute(route);
      } else {
        navigator.pop();
      }
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
          if (_story.id == story.id) {
            _error = _viewerText(
                context, 'تعذر تحديث الستوري.', 'Could not update this story.');
          }
        });
      }
    } finally {
      _loveRevision++;
      if (mounted) setState(() => _pendingLoves.remove(story.id));
    }
  }

  Future<void> _deleteStory() async {
    if (_confirmingDelete ||
        _story.authorId != AuthSession.instance.currentUser?.id) {
      return;
    }
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
                title: Text(_viewerText(ctx, 'حذف الستوري؟', 'Delete story?')),
                content: Text(_viewerText(
                    ctx,
                    'ستختفي الستوري من عند الجميع. نقاطك المكتسبة ستبقى محفوظة.',
                    'This story will disappear for everyone. Points you earned will remain.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(_viewerText(ctx, 'إلغاء', 'Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(_viewerText(ctx, 'حذف', 'Delete'))),
                ],
              ));
      if (confirm != true || !mounted) return;
      unawaited(_deleteConfirmed(
          id, ScaffoldMessenger.of(context), _viewerIsArabic(context)));
    } catch (_) {
      if (mounted) {
        setState(() => _error = _viewerText(
            context,
            'تعذر حذف الستوري. حاول مجدداً.',
            'Could not delete the story. Try again.'));
      }
    } finally {
      _confirmingDelete = false;
      _held = false;
      if (mounted && !_closing) {
        setState(() {});
        _resume();
      }
    }
  }

  Future<void> _deleteConfirmed(
      String id, ScaffoldMessengerState messenger, bool isArabic) async {
    final deletion = StoriesRepository.instance.deleteStory(id);
    _deleted.add(id);
    if (mounted && !_closing && _story.id == id) {
      _move(1, removeDeletedRoute: true);
    }
    try {
      await deletion;
    } catch (_) {
      if (mounted && !_closing) setState(() => _deleted.remove(id));
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(isArabic
              ? 'لم يكتمل حذف الستوري. تحقق من الاتصال وحاول مجدداً.'
              : 'The story was not deleted. Check your connection and retry.'),
          action: SnackBarAction(
              label: isArabic ? 'إعادة المحاولة' : 'Retry',
              onPressed: () =>
                  unawaited(_deleteConfirmed(id, messenger, isArabic))),
        ));
      }
    }
  }

  Widget _image(StudentStory story) => Image.network(story.imageUrl,
          key: ValueKey(story.id),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          frameBuilder: (context, child, frame, synchronous) {
        if (synchronous || frame != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _contentReady(story.id));
          return child;
        }
        return const Center(child: StoryLoadingIndicator());
      }, errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _contentReady(story.id, viewed: story.text.isNotEmpty));
        return const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.white, size: 64));
      });

  Widget _surface(StudentStory story, bool expired) {
    Widget content;
    if (expired) {
      content = Center(
          child: Text(
              _viewerText(
                  context, 'انتهت صلاحية الستوري', 'This story has expired'),
              style: const TextStyle(color: Colors.white)));
    } else if (story.imageUrl.isNotEmpty) {
      content = _image(story);
    } else if (story.videoUrl.isNotEmpty) {
      content = _videoFailed
          ? Center(
              child: Text(
                  _viewerText(context, 'تعذر تشغيل الفيديو',
                      'Could not play this video'),
                  style: const TextStyle(color: Colors.white)))
          : _video?.value.isInitialized == true
              ? ClipRect(
                  child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                          width: _video!.value.size.width,
                          height: _video!.value.size.height,
                          child: VideoPlayer(_video!))))
              : const Center(child: StoryLoadingIndicator());
    } else {
      content = Center(
          child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 120),
              child: SingleChildScrollView(
                  child: Text(story.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26, height: 1.5, color: Colors.white)))));
    }
    return SizedBox.expand(key: const ValueKey('story-media'), child: content);
  }

  Widget _loveButton(StudentStory story, bool expired, bool loved) => Tooltip(
      message: loved
          ? _viewerText(context, 'أعجبك هذا الستوري', 'You liked this story')
          : _viewerText(context, 'إرسال لاف', 'Send a like'),
      child: Listener(
        onPointerDown: (_) {
          _pressedLoveId = story.id;
          _love();
        },
        onPointerCancel: (_) => _pressedLoveId = null,
        onPointerUp: (_) => scheduleMicrotask(() => _pressedLoveId = null),
        child: TextButton.icon(
          key: const ValueKey('story-love-button'),
          style: TextButton.styleFrom(
              minimumSize: const Size(144, 72),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
              backgroundColor: Colors.black.withValues(alpha: .45)),
          onPressed: expired || loved || _pendingLoves.contains(story.id)
              ? null
              : () {
                  if (_pressedLoveId == story.id) return;
                  _love();
                },
          icon: Icon(loved ? Icons.favorite : Icons.favorite_border,
              color: Colors.pinkAccent, size: 20),
          label: Text('${_counts[story.id] ?? story.loveCount}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    if (_closing && _currentSessionIdentity != _sessionIdentity) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final story = _story;
    final loved = story.loved || _loved.contains(story.id);
    final expired = !story.expiresAt.isAfter(DateTime.now());
    final hasMedia = story.imageUrl.isNotEmpty || story.videoUrl.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF080C12),
      body: GestureDetector(
        onVerticalDragStart: _dragStart,
        onVerticalDragUpdate: _dragUpdate,
        onVerticalDragEnd: _dragEnd,
        onVerticalDragCancel: _cancelDrag,
        behavior: HitTestBehavior.opaque,
        child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Stack(fit: StackFit.expand, children: [
              LayoutBuilder(
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
                          if (_video != null) unawaited(_video!.pause());
                        },
                        onLongPressEnd: (_) {
                          _held = false;
                          _resume();
                        },
                        onHorizontalDragEnd: (d) =>
                            _move((d.primaryVelocity ?? 0) < 0 ? 1 : -1),
                        child: Stack(fit: StackFit.expand, children: [
                          _surface(story, expired),
                          if (!expired && hasMedia && story.text.isNotEmpty)
                            Positioned(
                                left: 20,
                                right: 20,
                                bottom:
                                    112 + MediaQuery.paddingOf(context).bottom,
                                child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxHeight: bounds.maxHeight * .3),
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: .5),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: SingleChildScrollView(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(story.text,
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    height: 1.5,
                                                    color: Colors.white)))))),
                          Center(
                              child: IgnorePointer(
                                  child: AnimatedOpacity(
                                      opacity: _showHeart ? 1 : 0,
                                      duration:
                                          const Duration(milliseconds: 120),
                                      child: AnimatedScale(
                                          scale: _showHeart ? 1 : .6,
                                          duration:
                                              const Duration(milliseconds: 180),
                                          child: const Icon(
                                              Icons.favorite_rounded,
                                              size: 82,
                                              color: Colors.pinkAccent))))),
                        ]),
                      )),
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ColoredBox(
                      color: Colors.black.withValues(alpha: .4),
                      child: SafeArea(
                          bottom: false,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 6, 12, 0),
                                child: AnimatedBuilder(
                                    animation: _clock,
                                    builder: (_, __) => Row(children: [
                                          for (var i = 0;
                                              i < widget.stories.length;
                                              i++)
                                            if (!_deleted
                                                .contains(widget.stories[i].id))
                                              Expanded(
                                                  child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2),
                                                      child:
                                                          LinearProgressIndicator(
                                                              key: ValueKey(
                                                                  'story-timer-$i'),
                                                              value: i < _index
                                                                  ? 1
                                                                  : i == _index
                                                                      ? _clock
                                                                          .value
                                                                      : 0,
                                                              minHeight: 4,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                              backgroundColor:
                                                                  Colors
                                                                      .white24,
                                                              color: Colors
                                                                  .pinkAccent))),
                                        ]))),
                            Padding(
                                padding: const EdgeInsets.fromLTRB(16, 2, 6, 6),
                                child: IconTheme(
                                    data: const IconThemeData(
                                        color: Colors.white),
                                    child: DefaultTextStyle(
                                        style: const TextStyle(
                                            color: Colors.white),
                                        child: Row(children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                StudentIdentity(
                                                  id: story.authorId,
                                                  name: story.name,
                                                  avatar: story.avatar,
                                                  role: story.authorRole,
                                                  showRoleBadge: story.authorRole == 'admin',
                                                ),
                                                if (story.authorId ==
                                                    AuthSession.instance.currentUser?.id)
                                                  Padding(
                                                    padding: const EdgeInsetsDirectional.only(start: 42, bottom: 3),
                                                    child: Text(
                                                      _viewerExpiryText(context, story.expiresAt),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (story.authorId ==
                                              AuthSession
                                                  .instance.currentUser?.id)
                                            IconButton(
                                                tooltip: _viewerText(
                                                    context,
                                                    'حذف الستوري',
                                                    'Delete story'),
                                                onPressed: _confirmingDelete
                                                    ? null
                                                    : _deleteStory,
                                                icon: const Icon(Icons
                                                    .delete_outline_rounded)),
                                          if (story.authorId != AuthSession.instance.currentUser?.id)
                                            IconButton(
                                              tooltip: _viewerText(context, 'إبلاغ عن الستوري', 'Report story'),
                                              icon: const Icon(Icons.flag_outlined),
                                              onPressed: () async {
                                                _held = true;
                                                _clock.stop();
                                                if (_video != null) await _video!.pause();
                                                if (!context.mounted) return;
                                                await reportUnsafeContent(context, 'Story ID: ${story.id}\nAuthor: ${story.authorId}\n${story.text}');
                                                if (!mounted) return;
                                                _held = false;
                                                _resume();
                                              },
                                            ),
                                          IconButton(
                                              tooltip: _viewerText(
                                                  context, 'إغلاق', 'Close'),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              icon: const Icon(
                                                  Icons.close_rounded)),
                                        ])))),
                          ])))),
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                      top: false,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (_error != null)
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style:
                                      const TextStyle(color: AppColors.greenInk))),
                        if (story.authorId ==
                            AuthSession.instance.currentUser?.id)
                          TextButton.icon(
                              key: const ValueKey('story-viewers-button'),
                              onPressed: expired ? null : _openViewers,
                              icon: const Icon(Icons.visibility_outlined,
                                  color: Colors.white),
                              label: Text(
                                  '${_views[story.id] ?? story.viewCount ?? 0} ${_viewerText(context, 'مشاهد', 'views')}',
                                  style: const TextStyle(color: Colors.white))),
                        _loveButton(story, expired, loved),
                        const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Icon(Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70, size: 22)),
                      ]))),
            ])),
      ),
    );
  }
}
