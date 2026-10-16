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
  final int points, days, loves;
  final bool posted;
  final String state, timeZone;
  final DateTime? resetsAt;
  const StoryProgress(
      {this.playedToday = false,
      this.scoreEmoji = '🔥',
      this.points = 0,
      this.days = 0,
      this.loves = 0,
      this.posted = false,
      this.state = 'inactive',
      this.timeZone = 'Europe/Istanbul',
      this.resetsAt});
  factory StoryProgress.fromJson(Map<String, dynamic> j) => StoryProgress(
      playedToday: j['playedToday'] == true,
      scoreEmoji: scoreEmojis.contains(j['scoreEmoji'])
          ? j['scoreEmoji'] as String
          : '🔥',
      points: (j['total_points'] as num?)?.toInt() ?? 0,
      days: (j['streak_days'] as num?)?.toInt() ?? 0,
      loves: (j['dailyLoveCount'] as num?)?.toInt() ?? 0,
      posted: j['postedToday'] == true,
      state: j['state'] as String? ?? 'inactive',
      timeZone: j['timeZone'] as String? ?? 'Europe/Istanbul',
      resetsAt: DateTime.tryParse(j['resetsAt'] as String? ?? ''));
}

class StudentStory {
  final String videoUrl;
  final double videoDuration;
  final String id, text, imageUrl, authorId, name, avatar;
  final int authorPoints, loveCount;
  final bool seen, loved;
  final DateTime expiresAt;
  StudentStory.fromJson(Map<String, dynamic> j)
      : videoUrl = j['videoUrl'] as String? ?? '',
        videoDuration = (j['videoDuration'] as num?)?.toDouble() ?? 0,
        id = j['id'] as String,
        text = j['text'] as String? ?? '',
        imageUrl = j['imageUrl'] as String? ?? '',
        authorId = j['author']['id'] as String,
        name = j['author']['name'] as String? ?? '',
        avatar = j['author']['avatar'] as String? ?? '',
        authorPoints = (j['author']['total_points'] as num?)?.toInt() ?? 0,
        loveCount = (j['loveCount'] as num?)?.toInt() ?? 0,
        seen = j['seen'] == true,
        loved = j['loved'] == true,
        expiresAt = DateTime.parse(j['expiresAt'] as String);
}

class StoriesRepository {
  StoriesRepository._();
  static final instance = StoriesRepository._();
  final _api = ApiClient.instance;
  String? get _token => AuthSession.instance.token;
  Future<Map<String, dynamic>> updates(List<String> ids) async =>
      Map<String, dynamic>.from(await _api.get(
          '/stories/updates?ids=${ids.take(120).join(',')}',
          token: _token,
          cached: false));
  Future<StoryProgress> progress() async =>
      StoryProgress.fromJson(Map<String, dynamic>.from(
          await _api.get('/stories/progress', token: _token, cached: false)));
  Future<StoryProgress> setScoreEmoji(String emoji) async =>
      StoryProgress.fromJson(Map<String, dynamic>.from(await _api.put(
          '/stories/preferences',
          token: _token,
          body: {'scoreEmoji': emoji})));
  Future<({List<StudentStory> stories, String? nextCursor})> feed(
      [String? before]) async {
    final j = await _api.get(
        '/stories${before == null ? '' : '?before=$before'}',
        token: _token,
        cached: false);
    return (
      stories: (j['stories'] as List)
          .map((e) => StudentStory.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      nextCursor: j['nextCursor'] as String?
    );
  }

  Future<void> seen(String id) async {
    await _api.post('/stories/$id/seen', token: _token);
  }

  Future<Map<String, dynamic>> love(String id) async =>
      Map<String, dynamic>.from(
          await _api.post('/stories/$id/love', token: _token));
  Future<String> upload(List<int> bytes, String name) async {
    final j = await _api.postMultipart('/stories/image',
        token: _token, fileBytes: bytes, fileName: name);
    return j['imageUrl'] as String;
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
      required String operationId}) async {
    final j = await _api.post('/stories', token: _token, body: {
      'text': text,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'operationId': operationId,
    });
    return StoryProgress.fromJson(Map<String, dynamic>.from(j['progress']));
  }
}
