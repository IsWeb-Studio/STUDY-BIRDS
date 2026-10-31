import 'dart:async';
import '../network/api_client.dart';
import '../services/auth_session.dart';

class StoryProgress {
  static const scoreEmojis = [
    '🔥',
    '⭐',
    '🌟',
    '🏆',
    '🚀',
    '💎',
    '🦅',
    '📚',
    '🎯',
    '⚡',
    '❤️',
    '🌱'
  ];
  final String scoreEmoji;
  final bool playedToday;
  final int points, days, loves, awardedPoints;
  final int restoresRemaining, restoreLimit, recoverableDays;
  final bool canRestore;
  final bool posted;
  final String state, timeZone;
  final DateTime? resetsAt;
  final DateTime? serverNow, recoveryExpiresAt, monthResetsAt;
  final Stopwatch? serverClock;
  final int longestStreak;
  final String streakState;
  final List<StreakDay> calendar;
  DateTime? get estimatedServerNow =>
      serverNow?.add(serverClock?.elapsed ?? Duration.zero);
  Duration remainingUntil(DateTime? deadline) {
    final now = estimatedServerNow;
    if (now == null || deadline == null) return Duration.zero;
    final delta = deadline.difference(now);
    return delta.isNegative ? Duration.zero : delta;
  }

  bool get restoreEligible =>
      canRestore &&
      restoresRemaining > 0 &&
      recoverableDays > 0 &&
      serverNow != null &&
      remainingUntil(recoveryExpiresAt) > Duration.zero;
  const StoryProgress(
      {this.playedToday = false,
      this.scoreEmoji = '🔥',
      this.points = 0,
      this.awardedPoints = 0,
      this.days = 0,
      this.restoresRemaining = 0,
      this.restoreLimit = 3,
      this.recoverableDays = 0,
      this.canRestore = false,
      this.loves = 0,
      this.posted = false,
      this.state = 'inactive',
      this.timeZone = 'Europe/Istanbul',
      this.resetsAt,
      this.serverNow,
      this.recoveryExpiresAt,
      this.monthResetsAt,
      this.serverClock,
      this.longestStreak = 0,
      this.streakState = 'empty',
      this.calendar = const []});
  factory StoryProgress.fromJson(Map<String, dynamic> j) => StoryProgress(
      playedToday: j['playedToday'] == true,
      scoreEmoji: scoreEmojis.contains(j['scoreEmoji'])
          ? j['scoreEmoji'] as String
          : '🔥',
      points: (j['total_points'] as num?)?.toInt() ?? 0,
      awardedPoints: (j['awardedPoints'] as num?)?.toInt() ?? 0,
      days: (j['streak_days'] as num?)?.toInt() ?? 0,
      restoresRemaining: (j['streakRestoresRemaining'] as num?)?.toInt() ?? 0,
      restoreLimit: (j['streakRestoreLimit'] as num?)?.toInt() ?? 3,
      recoverableDays: (j['recoverableStreakDays'] as num?)?.toInt() ?? 0,
      canRestore: j['canRestoreStreak'] == true,
      loves: (j['dailyLoveCount'] as num?)?.toInt() ?? 0,
      posted: j['postedToday'] == true,
      state: j['state'] as String? ?? 'inactive',
      timeZone: j['timeZone'] as String? ?? 'Europe/Istanbul',
      resetsAt: DateTime.tryParse(j['resetsAt'] as String? ?? ''),
      serverNow: DateTime.tryParse(j['serverNow'] as String? ?? ''),
      serverClock: Stopwatch()..start(),
      recoveryExpiresAt:
          DateTime.tryParse(j['recoveryExpiresAt'] as String? ?? ''),
      monthResetsAt: DateTime.tryParse(j['monthResetsAt'] as String? ?? ''),
      longestStreak: [
        j['longestStreak'],
        j['streak_days'],
        j['recoverableStreakDays']
      ]
          .whereType<num>()
          .map((v) => v.toInt())
          .fold<int>(0, (a, b) => a > b ? a : b),
      streakState: j['streakState'] as String? ??
          ((j['streak_days'] as num? ?? 0) > 0
              ? (j['state'] == 'ice_cold' ? 'at_risk' : 'active')
              : 'empty'),
      calendar: (j['activityCalendar'] as List? ?? [])
          .whereType<Map>()
          .map((row) =>
              StreakDay(row['day']?.toString() ?? '', row['active'] == true))
          .where((row) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(row.day))
          .toList());
}

class StreakDay {
  final String day;
  final bool active;
  const StreakDay(this.day, this.active);
}

class StudentStory {
  final String videoUrl, audioUrl;
  final double videoDuration, audioDuration;
  final String id, text, imageUrl, authorId, name, avatar, authorRole, audience;
  final int authorPoints, loveCount;
  final int? viewCount;
  final bool seen, loved;
  final DateTime expiresAt;
  StudentStory.fromJson(Map<String, dynamic> j)
      : audioDuration = (j['audioDuration'] as num?)?.toDouble() ?? 0,
        audioUrl = j['audioUrl'] as String? ?? '',
        videoUrl = j['videoUrl'] as String? ?? '',
        videoDuration = (j['videoDuration'] as num?)?.toDouble() ?? 0,
        id = j['id'] as String,
        text = j['text'] as String? ?? '',
        imageUrl = j['imageUrl'] as String? ?? '',
        authorId = j['author']['id'] as String,
        name = j['author']['name'] as String? ?? '',
        avatar = j['author']['avatar'] as String? ?? '',
        authorRole = j['author']['role'] as String? ?? 'student',
        audience = j['audience'] as String? ?? 'allEligible',
        authorPoints = (j['author']['total_points'] as num?)?.toInt() ?? 0,
        loveCount = (j['loveCount'] as num?)?.toInt() ?? 0,
        viewCount = (j['viewCount'] as num?)?.toInt(),
        seen = j['seen'] == true,
        loved = j['loved'] == true,
        expiresAt = DateTime.parse(j['expiresAt'] as String);
}

class StoriesRepository {
  StoriesRepository._();
  static final instance = StoriesRepository._();
  final _api = ApiClient.instance;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  void notifyProgressChanged() => _changes.add(null);
  final _hidden = <String, Set<String>>{};
  final _deleting = <String, Future<void>>{};
  String get _scope => AuthSession.instance.currentUser?.id ?? _token ?? '';
  bool isHidden(String id) => _hidden[_scope]?.contains(id) ?? false;
  bool isDeleting(String id) => _deleting.containsKey('$_scope:$id');
  String? get _token => AuthSession.instance.token;
  final _reactionChanges = StreamController<String>.broadcast();
  Stream<String> get reactionChanges => _reactionChanges.stream;
  final _reactions = <String, ({int count, bool loved})>{};
  String? _reactionScope;
  int _reactionRevision = 0;
  final _pendingReactions = <String, Future<Map<String, dynamic>>>{};

  String _syncReactionScope() {
    final scope = '${AuthSession.instance.currentUser?.id ?? ''}:$_token';
    if (_reactionScope != scope) {
      _reactionScope = scope;
      _reactions.clear();
      _reactionRevision++;
    }
    return scope;
  }

  ({int count, bool loved})? reactionFor(String id) {
    _syncReactionScope();
    return _reactions[id];
  }

  void _rememberReaction(String id, int count, bool loved) {
    _reactions.remove(id);
    _reactions[id] = (count: count, loved: loved);
    while (_reactions.length > 240) {
      _reactions.remove(_reactions.keys.first);
    }
  }

  Future<Map<String, dynamic>> updates(List<String> ids) async {
    final scope = _syncReactionScope(), revision = _reactionRevision;
    final data = Map<String, dynamic>.from(await _api.get(
        '/stories/updates?ids=${ids.take(120).join(',')}',
        token: _token,
        cached: false));
    if (scope != _syncReactionScope()) return data;
    data['updates'] = (data['updates'] as List).map((row) {
      final update = Map<String, dynamic>.from(row as Map);
      final id = '${update['id']}';
      final known = _reactions[id];
      // A poll started before a successful like must not undo that like.
      if ((revision != _reactionRevision ||
              _pendingReactions.containsKey('$scope:$id')) &&
          known != null) {
        update['loveCount'] = known.count;
        update['loved'] = known.loved;
      } else if (update['loveCount'] is num) {
        _rememberReaction(
            id, (update['loveCount'] as num).toInt(), update['loved'] == true);
      }
      return update;
    }).toList();
    return data;
  }

  Future<StoryProgress> progress() async =>
      StoryProgress.fromJson(Map<String, dynamic>.from(
          await _api.get('/stories/progress', token: _token)));
  Future<StoryProgress> setScoreEmoji(String emoji) async =>
      StoryProgress.fromJson(Map<String, dynamic>.from(await _api.put(
          '/stories/preferences',
          token: _token,
          body: {'scoreEmoji': emoji})));
  Future<StoryProgress> streakDetails() async {
    try {
      return StoryProgress.fromJson(Map<String, dynamic>.from(await _api
          .get('/stories/streak/details', token: _token, cached: false)));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return progress();
      rethrow;
    }
  }

  Future<StoryProgress> restoreStreak({String? operationId}) async {
    final result = StoryProgress.fromJson(Map<String, dynamic>.from(
        await _api.post('/stories/streak/restore',
            token: _token,
            body: {},
            idempotencyKey: operationId ?? ApiClient.newOperationId())));
    _changes.add(null);
    return result;
  }

  Future<({List<StudentStory> stories, String? nextCursor})> feed(
      [String? before]) async {
    final token = _token;
    final version = _api.snapshotVersion;
    final j = await _api.get(
        '/stories${before == null ? '' : '?before=$before'}',
        token: token,
        cached: false);
    if (before == null) {
      _api.rememberSnapshot('/stories', j, token: token, version: version);
    }
    return _feedPage(j);
  }

  ({List<StudentStory> stories, String? nextCursor})? cachedFeed() {
    final j = _api.snapshot('/stories', token: _token);
    return j is! Map || j['stories'] is! List ? null : _feedPage(j);
  }

  ({List<StudentStory> stories, String? nextCursor}) _feedPage(dynamic j) => (
        stories: (j['stories'] as List)
            .map((e) => StudentStory.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.expiresAt.isAfter(DateTime.now()))
            .toList(),
        nextCursor: j['nextCursor'] as String?
      );

  Future<void> seen(String id) async {
    await _api.post('/stories/$id/seen', token: _token);
  }

  Future<Map<String, dynamic>> viewers(
    String id, {
    String? before,
  }) async =>
      Map<String, dynamic>.from(
        await _api.get(
          '/stories/$id/viewers${before == null ? '' : '?before=${Uri.encodeQueryComponent(before)}'}',
          token: _token,
          cached: false,
        ),
      );

  Future<void> deleteStory(String id) async {
    await _api.delete('/stories/$id', token: _token);
  }

  Future<Map<String, dynamic>> love(String id, {int? previousCount}) {
    final scope = _syncReactionScope();
    final key = '$scope:$id';
    final pending = _pendingReactions[key];
    if (pending != null) return pending;
    final operation = _love(id, scope, key, previousCount);
    _pendingReactions[key] = operation;
    return operation;
  }

  Future<Map<String, dynamic>> _love(
      String id, String scope, String key, int? previousCount) async {
    final previous =
        _reactions[id] ?? (count: previousCount ?? 0, loved: false);
    _reactionRevision++;
    _rememberReaction(id, previous.count + (previous.loved ? 0 : 1), true);
    _reactionChanges.add(id);
    try {
      final result = Map<String, dynamic>.from(
          await _api.post('/stories/$id/love', token: _token));
      if (result['loveCount'] is! num || (result['loveCount'] as num) < 0) {
        throw const FormatException('Invalid story reaction response');
      }
      if (scope == _syncReactionScope() && result['loveCount'] is num) {
        _reactionRevision++;
        _rememberReaction(id, (result['loveCount'] as num).toInt(), true);
        _reactionChanges.add(id);
      }
      return result;
    } catch (_) {
      if (scope == _syncReactionScope()) {
        _reactionRevision++;
        _rememberReaction(id, previous.count, previous.loved);
        _reactionChanges.add(id);
      }
      rethrow;
    } finally {
      _pendingReactions.remove(key);
    }
  }

  Future<String> upload(List<int> bytes, String name,
      {void Function(double)? onProgress}) async {
    final j = await _api.postMultipart('/stories/image',
        token: _token,
        fileBytes: bytes,
        fileName: name,
        onProgress: onProgress);
    return j['imageUrl'] as String;
  }

  Future<String> uploadAudio(List<int> bytes, String name) async {
    final j = await _api.postMultipart('/stories/audio',
        token: _token, fileBytes: bytes, fileName: name);
    return j['audioUrl'] as String;
  }

  Future<String> uploadVideo(List<int> bytes, String name,
      {void Function(double)? onProgress}) async {
    final j = await _api.postMultipart('/stories/video',
        token: _token,
        fileBytes: bytes,
        fileName: name,
        onProgress: onProgress);
    return j['videoUrl'] as String;
  }

  Future<StoryProgress> post(
      {required String text,
      required String imageUrl,
      String videoUrl = '',
      String audioUrl = '',
      required String operationId,
      String? audience,
      bool? notifyAudience}) async {
    final j = await _api.post('/stories', token: _token, body: {
      'text': text,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      if (audioUrl.isNotEmpty) 'audioUrl': audioUrl,
      'operationId': operationId,
      if (audience != null) 'audience': audience,
      if (notifyAudience != null) 'notifyAudience': notifyAudience,
    });
    final progress = Map<String, dynamic>.from(j['progress']);
    progress['awardedPoints'] = j['awarded'];
    final result = StoryProgress.fromJson(progress);
    _changes.add(null);
    return result;
  }
}
