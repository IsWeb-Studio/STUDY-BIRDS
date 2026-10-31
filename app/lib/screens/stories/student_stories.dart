import 'story_photo_editor.dart';
import '../profile_account/my_streak.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/community_terms.dart';
import '../../core/widgets/gallery_access.dart';
import '../../core/widgets/current_user_avatar.dart';
import '../community/student_profile_link.dart';
import '../community/contact_profile_screen.dart';
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
import '../../core/widgets/verified_admin_badge.dart';
import 'friends_screen.dart';
import '../community/student_community_hub.dart';
import '../../core/repositories/friends_repository.dart';
import 'story_viewer.dart';
import 'story_loading_indicator.dart';
export 'story_viewer.dart' show StoryViewer;

bool _storyIsArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _storyText(BuildContext context, String arabic, String english) =>
    _storyIsArabic(context) ? arabic : english;

bool _canPublishCommunityStory(UserRole? role) =>
    role != null && role != UserRole.agent;

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
                      color: seen ? Colors.grey : AppColors.navy, width: 2.5)),
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
  final bool compact;
  const StudentStories(
      {super.key,
      this.isActive = true,
      this.showCommunityButton = true,
      this.compact = false});
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
  StreamSubscription<String>? _reactionSub;
  bool _openingFriends = false;
  bool _publishingStory = false;
  bool _reloadAfterFriends = false;
  bool _reloadAfterAccountChange = false;
  String? _accountId;
  bool get _canPublishStories =>
      _canPublishCommunityStory(AuthSession.instance.currentUser?.role);
  @override
  void initState() {
    super.initState();
    _accountId = AuthSession.instance.currentUser?.id;
    AuthSession.instance.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    final cached = _repo.cachedFeed();
    if (cached != null) {
      _stories = cached.stories;
      _cursor = cached.nextCursor;
      _loading = false;
    }
    _load();
    _reactionSub = _repo.reactionChanges.listen((id) {
      final reaction = _repo.reactionFor(id);
      if (mounted && reaction != null) {
        setState(() => _liveCounts[id] = reaction.count);
      }
    });
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
    AuthSession.instance.removeListener(_accountChanged);
    _timer?.cancel();
    _liveTimer?.cancel();
    _friendsSub?.cancel();
    _reactionSub?.cancel();
    super.dispose();
  }

  void _accountChanged() {
    final nextId = AuthSession.instance.currentUser?.id;
    if (nextId == _accountId) return;
    _accountId = nextId;
    _stories.clear();
    _seen.clear();
    _liveCounts.clear();
    _cursor = null;
    _progress = null;
    _error = null;
    _loading = true;
    if (_refreshing) {
      _reloadAfterAccountChange = true;
    } else {
      unawaited(_load());
    }
    if (mounted) setState(() {});
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
    final requestToken = AuthSession.instance.token;
    final requested = _stories.take(120).map((s) => s.id).toSet();
    try {
      final data = await _repo.updates(requested.toList());
      if (!mounted || !_visible || requestToken != AuthSession.instance.token) {
        return;
      }
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
      if (_reloadAfterAccountChange) {
        _reloadAfterAccountChange = false;
        return _load(quiet: quiet, more: false);
      }
      return;
    }
    if (quiet && !_visible) {
      return;
    }
    _refreshing = true;
    final requestAccountId = AuthSession.instance.currentUser?.id;
    _loadDone = Completer<void>();
    try {
      // The feed already contains author scores; do not wait for a profile call.
      final page = await _repo.feed(more ? _cursor : null);
      if (!mounted ||
          requestAccountId != AuthSession.instance.currentUser?.id) {
        return;
      }
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
      if (_reloadAfterAccountChange && mounted) {
        _reloadAfterAccountChange = false;
        unawaited(_load());
      }
    }
  }

  Future<void> _compose() async {
    if (!_canPublishStories || _publishingStory) return;
    final posted = AuthSession.instance.currentUser?.role == UserRole.admin
        ? await Navigator.of(context).push<StoryProgress>(
            MaterialPageRoute(builder: (_) => const StoryComposer()))
        : await _publishPhoto();
    if (posted != null && mounted) {
      await _load();
      if (!mounted) return;
      final earned = posted.awardedPoints;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(earned > 0
            ? _storyText(
                context,
                'تم نشر الستوري وإضافة $earned نقطة إلى رصيدك.',
                'Story posted. $earned points were added to your balance.')
            : _storyText(
                context,
                'تم نشر الستوري. وصلت إلى حد نقاط القصص اليومي؛ سيُحتسب نشاطها غدًا.',
                'Story posted. You reached today’s story-points limit; points are available again tomorrow.')),
      ));
    }
  }

  Future<StoryProgress?> _publishPhoto() async {
    setState(() => _publishingStory = true);
    final owner = AuthSession.instance.currentUser?.id;
    bool valid() => mounted && owner == AuthSession.instance.currentUser?.id;
    try {
      if (!await requireCommunityTerms(context) || !valid()) return null;
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 2000,
          imageQuality: 85);
      if (image == null || !valid()) return null;
      final length = await image.length();
      if (!mounted || !valid()) return null;
      if (length > 5 * 1024 * 1024) {
        throw Exception(_storyText(context, 'حجم الصورة أكبر من 5 ميجابايت',
            'Choose an image smaller than 5 MB.'));
      }
      final original = await image.readAsBytes();
      if (!mounted || !valid()) return null;
      final edited = await Navigator.of(context).push<EditedStoryPhoto>(
          MaterialPageRoute(
              builder: (_) =>
                  StoryPhotoEditor(bytes: original, publishOnConfirm: true)));
      if (edited == null || !valid()) return null;
      final bytes = edited.image;
      final operation = ApiClient.newOperationId();
      String? url;
      String? audioUrl;
      while (valid()) {
        try {
          url ??= await _repo.upload(bytes, edited.imageName);
          if (edited.audio != null) {
            audioUrl ??=
                await _repo.uploadAudio(edited.audio!, edited.audioName!);
          }
          if (!valid()) return null;
          return await _repo.post(
              text: '',
              imageUrl: url,
              audioUrl: audioUrl ?? '',
              operationId: operation);
        } catch (error) {
          if (!mounted || !valid()) return null;
          final retry = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: Text(_storyText(context, 'تعذر نشر الستوري',
                        'Could not publish story')),
                    content: Text(mediaPickerError(error)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(_storyText(context, 'إلغاء', 'Cancel'))),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                              _storyText(context, 'إعادة المحاولة', 'Retry'))),
                    ],
                  ));
          if (retry != true) return null;
        }
      }
    } catch (error) {
      if (mounted && valid()) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mediaPickerError(error))));
      }
    } finally {
      if (mounted) setState(() => _publishingStory = false);
    }
    return null;
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
    final canPublishStories = _canPublishStories;
    final groups = <String, List<StudentStory>>{};
    for (final s
        in _stories.where((s) => s.expiresAt.isAfter(DateTime.now()))) {
      groups.putIfAbsent(s.authorId, () => []).add(s);
    }
    for (final stories in groups.values) {
      stories.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    }
    return Padding(
        padding: EdgeInsets.fromLTRB(16, widget.compact ? 0 : 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!widget.compact)
            Row(children: [
              Expanded(
                  child: Text(
                      _storyText(context, 'الستوريات المنشورة', 'Stories'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17))),
            ]),
          if (!widget.compact &&
              !_loading &&
              _error == null &&
              _stories.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    _storyText(
                        context,
                        canPublishStories
                            ? 'لا توجد ستوريات منشورة حاليًا. انشر أول ستوري!'
                            : 'لا توجد ستوريات منشورة حاليًا.',
                        canPublishStories
                            ? 'No stories yet. Share the first one!'
                            : 'No stories have been posted yet.'),
                    style: const TextStyle(color: AppColors.textSecondary))),
          if (!widget.compact)
            Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                    icon: const Icon(Icons.people_outline),
                    label: Text(_storyText(context, 'الأصدقاء وطلبات الصداقة',
                        'Friends and requests')),
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
                child: Text(_storyText(
                    context,
                    'تعذر تحميل الستوريز. اضغط للمحاولة.',
                    'Could not load stories. Tap to retry.'))),
          SizedBox(
              height: 122,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                if (canPublishStories)
                  SizedBox(
                      width: 78,
                      child: InkWell(
                          onTap: _publishingStory ? null : _compose,
                          borderRadius: BorderRadius.circular(16),
                          child: Column(children: [
                            const SizedBox(height: 5),
                            CircleAvatar(
                                radius: 29,
                                backgroundColor: AppColors.greenSoft,
                                child: _publishingStory
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : widget.compact
                                        ? const Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                                CurrentUserAvatar(radius: 29),
                                                Positioned(
                                                    bottom: -2,
                                                    left: -2,
                                                    child: CircleAvatar(
                                                        radius: 10,
                                                        backgroundColor:
                                                            Colors.white,
                                                        child: Icon(Icons.add,
                                                            size: 16,
                                                            color: AppColors
                                                                .navy))),
                                              ])
                                        : const Icon(Icons.add,
                                            size: 30, color: AppColors.navy)),
                            const SizedBox(height: 9),
                            Text(
                                _storyText(context, 'ستوري جديدة', 'New story'),
                                style: const TextStyle(fontSize: 11)),
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
                                    ? (_progress?.points ??
                                        stories.first.authorPoints)
                                    : stories.first.authorPoints,
                                child: _StoryAvatar(
                                    name: stories.first.name,
                                    url: stories.first.avatar)),
                            const SizedBox(height: 6),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: stories.first.authorRole == 'student'
                                        ? StudentProfileLink(
                                            studentId: stories.first.authorId,
                                            child: Text(stories.first.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 11)))
                                        : ContactProfileLink(
                                            userId: stories.first.authorId,
                                            communityMode: true,
                                            child: Text(stories.first.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 11))),
                                  ),
                                  if (stories.first.authorRole == 'admin') ...[
                                    const SizedBox(width: 3),
                                    const VerifiedAdminBadge(
                                        role: 'admin', size: 13),
                                  ],
                                ]),
                            const SizedBox(height: 3),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.favorite,
                                      size: 12, color: Colors.pinkAccent),
                                  const SizedBox(width: 3),
                                  Text(
                                      '${stories.fold<int>(0, (sum, story) => sum + (_repo.reactionFor(story.id)?.count ?? _liveCounts[story.id] ?? story.loveCount))}',
                                      key: ValueKey(
                                          'story-loves-${stories.first.authorId}'),
                                      style: const TextStyle(fontSize: 11)),
                                ]),
                          ]))),
                if (_cursor != null)
                  Center(
                      child: TextButton(
                          onPressed: () => _load(more: true),
                          child: Text(_storyText(context, 'المزيد', 'More')))),
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
        color: AppColors.greenSoft,
        child: Center(
            child: Text(name.isEmpty ? '؟' : name.characters.first,
                style: const TextStyle(fontSize: 23, color: AppColors.navy))));
    return url.isEmpty
        ? fallback
        : AppNetworkImage(url,
            width: 66, height: 66, fit: BoxFit.cover, errorWidget: fallback);
  }
}

class StoryProgressSheet extends StatelessWidget {
  final StoryProgress progress;
  final VoidCallback onPost;
  const StoryProgressSheet(
      {super.key, required this.progress, required this.onPost});
  @override
  Widget build(BuildContext context) => StreakRulesSheet(
        timeZone: progress.timeZone,
        isGameActivity:
            AuthSession.instance.currentUser?.role != UserRole.student,
      );
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
  EditedStoryPhoto? _editedPhoto;
  String _audioUrl = '';
  String _videoUrl = '';
  bool _isVideo = false, _picking = false;
  double _uploadProgress = 0;
  VideoPlayerController? _preview;
  Uint8List? _bytes;
  String? _name, _error;
  bool _busy = false, _notifyAudience = false;
  String? _audience;
  bool get _isAdmin => AuthSession.instance.currentUser?.role == UserRole.admin;
  bool get _canPublishStory =>
      _canPublishCommunityStory(AuthSession.instance.currentUser?.role);

  @override
  void initState() {
    super.initState();
    // Give admins a useful, narrow audience by default so the required
    // audience choice does not silently block their first publication.
    if (_isAdmin) _audience = 'students';
  }

  @override
  void dispose() {
    _preview?.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (!_canPublishStory || _picking || _busy) return;
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
      var bytes = await image.readAsBytes();
      EditedStoryPhoto? edited;
      if (!video && mounted) {
        edited = await Navigator.of(context).push<EditedStoryPhoto>(
            MaterialPageRoute(builder: (_) => StoryPhotoEditor(bytes: bytes)));
        if (edited == null) return;
        bytes = edited.image;
      }
      if (mounted) {
        final old = _preview;
        setState(() {
          _preview = candidate;
          candidate = null;
          _isVideo = video;
          _videoUrl = '';
          _error = null;
          _bytes = bytes;
          _name = video ? image.name : edited!.imageName;
          _editedPhoto = edited;
          _audioUrl = '';
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
    if (!_canPublishStory ||
        _busy ||
        _picking ||
        (_text.text.trim().isEmpty && _bytes == null)) {
      return;
    }
    if (_isAdmin && _audience == null) {
      setState(() => _error = _storyText(context, 'اختر جمهور الستوري أولاً.',
          'Choose a story audience first.'));
      return;
    }
    if (!await requireCommunityTerms(context) || !mounted) return;
    if (_isAdmin && _audience == 'allEligible') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_storyText(
              context, 'نشر رسمي للجميع', 'Official story for all users')),
          content: Text(_storyText(
            context,
            'ستظهر هذه الستوري لجميع المستخدمين المؤهلين في COVEY. هل تريد نشرها؟',
            'This story will be visible to all eligible COVEY users.${_notifyAudience ? ' They will also receive a community notification if their preferences allow it.' : ''} Publish?',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_storyText(context, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_storyText(context, 'نشر', 'Publish')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
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
      if (_editedPhoto?.audio != null && _audioUrl.isEmpty) {
        _audioUrl = await repo.uploadAudio(
            _editedPhoto!.audio!, _editedPhoto!.audioName!);
      }
      final progress = await repo.post(
          text: _text.text.trim(),
          imageUrl: _imageUrl,
          videoUrl: _videoUrl,
          audioUrl: _audioUrl,
          operationId: _operationId,
          audience: _isAdmin ? _audience : null,
          notifyAudience: _isAdmin ? _notifyAudience : null);
      if (mounted) Navigator.pop(context, progress);
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
  Widget build(BuildContext context) {
    if (!_canPublishStory) {
      final role = AuthSession.instance.currentUser?.role;
      final explanation = role == null
          ? _storyText(context, 'سجّل الدخول بحساب طالب لنشر ستوري.',
              'Sign in with a student account to publish a story.')
          : _storyText(
              context,
              'نشر الستوري متاح لحسابات المجتمع ما عدا الوكيل. ستريك حسابك يُحتسب من المشاركة في اللعب الأونلاين.',
              'Story publishing is available to community accounts except agents. Your streak is counted through online play.');
      return Scaffold(
        appBar: AppBar(title: Text(_storyText(context, 'القصص', 'Stories'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline_rounded, size: 36),
              const SizedBox(height: 12),
              Text(explanation, textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
              title: Text(_storyText(context, 'ستوري جديدة', 'New story'))),
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(
                _storyText(context, 'شارك يومك مع زملائك',
                    'Share an update with your community'),
                style:
                    const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_storyText(
                context,
                AuthSession.instance.currentUser?.role == UserRole.student
                    ? 'الستوري متاحة لمدة 24 ساعة. أول ستوري في اليوم تكسبك 100 نقطة.'
                    : 'الستوري متاحة لمدة 24 ساعة. نشاط السلسلة يُحتسب من اللعب الأونلاين.',
                AuthSession.instance.currentUser?.role == UserRole.student
                    ? 'Stories last 24 hours. Your first story each day earns 100 points.'
                    : 'Stories last 24 hours. Your streak activity is counted through online play.')),
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
                  icon: Icon(_preview!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow),
                  label: Text(
                      _storyText(context, 'معاينة الفيديو', 'Preview video'))),
            ] else if (_bytes != null)
              ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child:
                      Image.memory(_bytes!, height: 280, fit: BoxFit.contain)),
            if (_isAdmin) ...[
              Row(children: [
                const VerifiedAdminBadge(role: 'admin', size: 20),
                const SizedBox(width: 7),
                Text(
                  _storyText(
                      context, 'قصة رسمية من COVEY', 'Official COVEY story'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ]),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const ValueKey('admin-story-audience'),
                initialValue: _audience,
                decoration: InputDecoration(
                  labelText:
                      _storyText(context, 'الجمهور المستهدف', 'Story audience'),
                  helperText: _storyText(
                      context,
                      'اختر من يمكنه مشاهدة هذه القصة.',
                      'Choose which eligible accounts can view this story.'),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'students',
                      child: Text(
                          _storyText(context, 'الطلاب فقط', 'Students only'))),
                  DropdownMenuItem(
                      value: 'guardians',
                      child: Text(_storyText(
                          context, 'أولياء الأمور فقط', 'Guardians only'))),
                  DropdownMenuItem(
                      value: 'universities',
                      child: Text(_storyText(
                          context, 'الجامعات فقط', 'Universities only'))),
                  DropdownMenuItem(
                      value: 'employees',
                      child: Text(_storyText(
                          context, 'الموظفون فقط', 'Employees only'))),
                  DropdownMenuItem(
                      value: 'allEligible',
                      child: Text(_storyText(context, 'كل المستخدمين المؤهلين',
                          'All eligible users'))),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _audience = value;
                          _error = null;
                        }),
              ),
              if (_audience != null) ...[
                const SizedBox(height: 8),
                Text(
                  _audience == 'allEligible'
                      ? _storyText(
                          context,
                          'ستظهر للمستخدمين النشطين المؤهلين من الطلاب وأولياء الأمور والجامعات والموظفين والأدمن. الوكلاء غير مشمولين.',
                          'Visible to active eligible students, guardians, universities, employees and admins. Agents are excluded.')
                      : _storyText(
                          context,
                          'ستظهر فقط للحسابات النشطة المؤهلة ضمن الجمهور المحدد.',
                          'Visible only to active eligible accounts in the selected audience.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (_isAdmin)
              CheckboxListTile(
                key: const ValueKey('admin-story-notify-audience'),
                contentPadding: EdgeInsets.zero,
                value: _notifyAudience,
                onChanged: _busy
                    ? null
                    : (value) =>
                        setState(() => _notifyAudience = value == true),
                title: Text(_storyText(
                    context, 'إبلاغ الجمهور', 'Notify this audience')),
                subtitle: Text(_storyText(
                    context,
                    'إشعار اختياري مع مراعاة تفضيلات المجتمع وحدّ النشر.',
                    'Optional inbox and push notice, respecting community preferences and a three-notices-per-hour limit.')),
              ),
            TextField(
                controller: _text,
                enabled: !_busy,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) {
                  _operationId = ApiClient.newOperationId();
                },
                decoration: InputDecoration(
                    hintText: _storyText(context, 'ما إنجازك اليوم؟',
                        'What would you like to share?'))),
            OutlinedButton.icon(
                onPressed: _busy || _picking ? null : () => _pick(),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_storyText(context, 'اختيار صورة أو فيديو',
                    'Choose a photo or video'))),
            Text(
                _storyText(
                    context,
                    'فيديو MP4 أو MOV • حتى دقيقة واحدة و25 ميجابايت',
                    'MP4 or MOV video • up to 1 minute and 25 MB'),
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
                            _audioUrl = '';
                            _editedPhoto = null;
                            _isVideo = false;
                            final old = _preview;
                            _preview = null;
                            old?.dispose();
                            _operationId = ApiClient.newOperationId();
                          }),
                  child: Text(_isVideo
                      ? _storyText(context, 'إزالة الفيديو', 'Remove video')
                      : _storyText(context, 'إزالة الصورة', 'Remove image'))),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _busy || _picking ? null : _post,
                child: _busy
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        StoryLoadingIndicator(
                            label: _storyText(context, 'جارٍ نشر الستوري…',
                                'Publishing story…')),
                        const SizedBox(width: 10),
                        Text(_storyText(context, 'جارٍ النشر…', 'Publishing…'))
                      ])
                    : Text(
                        _storyText(context, 'نشر الستوري', 'Publish story'))),
          ])),
        ));
  }
}
