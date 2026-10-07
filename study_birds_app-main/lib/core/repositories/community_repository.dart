import '../network/api_client.dart';
import '../services/auth_session.dart';

/// Student community (PRD item 55). Students read, post, comment and report;
/// moderation happens on the website's admin panel.
class CommunityRepository {
  CommunityRepository._();
  static final instance = CommunityRepository._();
  String? get _token => AuthSession.instance.token;

  static const topics = {
    'experience': 'تجارب',
    'housing': 'السكن',
    'tips': 'نصائح',
    'student_life': 'الحياة الطلابية',
    'faq': 'أسئلة شائعة',
    'other': 'أخرى',
  };
  static const reportReasons = {
    'spam': 'إعلان أو محتوى متكرر',
    'abuse': 'إساءة أو تنمر',
    'misinformation': 'معلومات مضللة',
    'privacy': 'نشر معلومات شخصية',
    'other': 'سبب آخر',
  };

  List<Map<String, dynamic>> _rows(dynamic data) => (data as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  Future<List<Map<String, dynamic>>> posts(
      {String? topic,
      String? country,
      String? university,
      String? studyField,
      bool mine = false}) async {
    final query = <String, String>{
      if (mine) 'mine': '1',
      if (!mine && topic != null) 'topic': topic,
      if (!mine && country != null) 'country': country,
      if (!mine && university != null) 'university': university,
      if (!mine && studyField != null) 'studyField': studyField,
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return _rows(
        await ApiClient.instance.get('/community/posts$suffix', token: _token));
  }

  Future<Map<String, dynamic>> thread(String postId) async {
    final data =
        await ApiClient.instance.get('/community/posts/$postId', token: _token);
    return {
      'post': Map<String, dynamic>.from(data['post'] as Map),
      'comments': _rows(data['comments']),
    };
  }

  Future<void> createPost(
      {required String title,
      required String body,
      required String topic,
      String? country,
      String? university,
      String? studyField}) async {
    await ApiClient.instance.post('/community/posts', token: _token, body: {
      'title': title.trim(),
      'body': body.trim(),
      'topic': topic,
      if (country != null) 'country': country,
      if (university != null) 'university': university,
      if (studyField != null) 'studyField': studyField,
    });
  }

  Future<void> comment(String postId, String body) async {
    await ApiClient.instance.post('/community/posts/$postId/comments',
        token: _token, body: {'body': body.trim()});
  }

  Future<void> deletePost(String postId) async {
    await ApiClient.instance.delete('/community/posts/$postId', token: _token);
  }

  Future<void> deleteComment(String commentId) async {
    await ApiClient.instance
        .delete('/community/comments/$commentId', token: _token);
  }

  /// [type] is 'post' or 'comment'.
  Future<void> report(String type, String id,
      {required String reason, String details = ''}) async {
    await ApiClient.instance.post(
        '/community/${type == 'post' ? 'posts' : 'comments'}/$id/report',
        token: _token,
        body: {'reason': reason, 'details': details.trim()});
  }

  /// {'suspended': bool, 'until': ISO date or null, 'reason': String}
  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(
      await ApiClient.instance.get('/community/status', token: _token) as Map);

  // ---- Moderation (employees with the 'community' section, and admins) ----

  Future<List<Map<String, dynamic>>> openReports() async =>
      _rows(await ApiClient.instance
          .get('/admin/community-reports?status=open', token: _token));

  /// {'post', 'comments' (including hidden), 'reports', 'log'}
  Future<Map<String, dynamic>> moderationDetail(String postId) async {
    final data = await ApiClient.instance
        .get('/admin/community-posts/$postId', token: _token);
    return {
      'post': Map<String, dynamic>.from(data['post'] as Map),
      'comments': _rows(data['comments']),
      'reports': _rows(data['reports']),
      'log': _rows(data['log']),
    };
  }

  /// [type] is 'post' or 'comment'; [status] is 'published' or 'hidden'.
  Future<void> moderate(String type, String id,
      {required String status, String note = ''}) async {
    await ApiClient.instance.patch(
        '/admin/community-${type == 'post' ? 'posts' : 'comments'}/$id',
        token: _token,
        body: {'status': status, 'moderationNote': note.trim()});
  }

  Future<List<Map<String, dynamic>>> suspensions() async =>
      _rows(await ApiClient.instance
          .get('/admin/community-suspensions', token: _token));

  /// [days] null = until a moderator lifts it.
  Future<void> suspend(String userId,
      {required String reason, int? days}) async {
    await ApiClient.instance.post('/admin/community-suspensions',
        token: _token,
        body: {'user': userId, 'reason': reason.trim(), 'days': days});
  }

  Future<void> liftSuspension(String userId) async {
    await ApiClient.instance
        .delete('/admin/community-suspensions/$userId', token: _token);
  }

  /// Filter/tag lookups. Each is optional: a failed lookup only hides that
  /// filter, it never blocks the community itself.
  Future<List<Map<String, dynamic>>> countries() async =>
      _rows(await ApiClient.instance.get('/content/countries'));
  Future<List<Map<String, dynamic>>> universities() async =>
      _rows(await ApiClient.instance.get('/universities'));
  Future<List<Map<String, dynamic>>> studyFields() async =>
      _rows(await ApiClient.instance.get('/content/study-fields'));
}
