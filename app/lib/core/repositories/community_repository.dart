import '../utils/json_safe.dart';
import 'dart:typed_data';
import '../network/api_client.dart';
import '../services/auth_session.dart';

/// Shared community (except partner accounts). Authorized roles read, post,
/// comment and report; moderation remains in the admin panel.
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
  static Map<String, String> topicLabels({bool arabic = true}) => arabic
      ? topics
      : const {
          'experience': 'Experiences',
          'housing': 'Housing',
          'tips': 'Tips',
          'student_life': 'Student life',
          'faq': 'Frequently asked questions',
          'other': 'Other',
        };
  static Map<String, String> reportReasonLabels({bool arabic = true}) => arabic
      ? reportReasons
      : const {
          'spam': 'Spam or repeated content',
          'abuse': 'Abuse or bullying',
          'misinformation': 'Misleading information',
          'privacy': 'Personal information',
          'other': 'Other reason',
        };

  List<Map<String, dynamic>> _rows(dynamic data) => (Json.list(data))
      .map((row) => Map<String, dynamic>.from(Json.rawMap(row)))
      .toList();

  Future<List<Map<String, dynamic>>> posts(
      {String? topic,
      String? country,
      String? university,
      String? studyField,
      bool mine = false,
      bool adminOnly = false}) async {
    final query = <String, String>{
      if (mine) 'mine': '1',
      if (adminOnly) 'admin': '1',
      if (!mine && topic != null) 'topic': topic,
      if (!mine && country != null) 'country': country,
      if (!mine && university != null) 'university': university,
      if (!mine && studyField != null) 'studyField': studyField,
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final rows = _rows(await ApiClient.instance
        .get('/community/posts$suffix', token: _token));
    // Older servers may ignore the author filter. Never show ordinary users'
    // posts in this feed, even if an inconsistent response marks them official.
    if (adminOnly) {
      return rows.where((post) {
        final author = post['author'];
        return author is Map && author['role'] == 'admin';
      }).toList();
    }
    return rows;
  }

  Future<Map<String, dynamic>> thread(String postId) async {
    final data = await ApiClient.instance
        .get('/community/posts/$postId', token: _token);
    return {
      'post': Map<String, dynamic>.from(Json.rawMap(data['post'])),
      'comments': _rows(data['comments']),
    };
  }

  Future<void> createPost(
      {required String title,
      required String body,
      required String topic,
      String? country,
      String? university,
      String? studyField,
      Uint8List? image,
      String? imageName,
      String? operationId}) async {
    final data = <String, String>{
      'title': title.trim(),
      'body': body.trim(),
      'topic': topic,
      if (country != null) 'country': country,
      if (university != null) 'university': university,
      if (studyField != null) 'studyField': studyField,
      if (operationId != null) 'operationId': operationId,
    };
    if (image != null) {
      await ApiClient.instance.postMultipart('/community/posts/image',
          token: _token,
          fileBytes: image,
          fileName: imageName ?? 'post.jpg',
          fields: data);
    } else {
      await ApiClient.instance
          .post('/community/posts', token: _token, body: data);
    }
  }

  Future<Map<String, dynamic>> react(String postId, String? reaction) async =>
      Map<String, dynamic>.from(Json.rawMap(reaction == null
          ? await ApiClient.instance
              .delete('/community/posts/$postId/reaction', token: _token)
          : await ApiClient.instance.put('/community/posts/$postId/reaction',
              token: _token, body: {'reaction': reaction})));

  Future<void> editPost(String postId,
      {required String title, required String body}) async {
    await ApiClient.instance.patch('/community/posts/$postId',
        token: _token, body: {'title': title.trim(), 'body': body.trim()});
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

  Future<void> editComment(String commentId, String body) async {
    await ApiClient.instance.patch('/community/comments/$commentId',
        token: _token, body: {'body': body.trim()});
  }

  Future<Map<String, dynamic>> likePost(String postId) async =>
      Map<String, dynamic>.from(Json.rawMap(await ApiClient.instance.put(
          '/community/posts/$postId/like',
          token: _token,
          body: const {})));

  Future<Map<String, dynamic>> unlikePost(String postId) async =>
      Map<String, dynamic>.from(Json.rawMap(await ApiClient.instance
          .delete('/community/posts/$postId/like', token: _token)));

  /// [type] is 'post' or 'comment'.
  Future<void> report(String type, String id,
      {required String reason, String details = ''}) async {
    await ApiClient.instance.post(
        '/community/${type == 'post' ? 'posts' : 'comments'}/$id/report',
        token: _token,
        body: {'reason': reason, 'details': details.trim()});
  }

  /// {'suspended': bool, 'until': ISO date or null, 'reason': String}
  Future<Map<String, dynamic>> status() async =>
      Map<String, dynamic>.from(Json.rawMap(
          await ApiClient.instance.get('/community/status', token: _token)));

  // ---- Moderation (employees with the 'community' section, and admins) ----

  Future<Map<String, dynamic>> adminOverview() async =>
      Map<String, dynamic>.from(Json.rawMap(await ApiClient.instance
          .get('/admin/community-overview', token: _token, cached: false)));

  Future<List<Map<String, dynamic>>> openReports() async =>
      moderationReports(status: 'open');

  Future<List<Map<String, dynamic>>> moderationReports(
          {String status = 'open'}) async =>
      _rows(await ApiClient.instance.get(
          '/admin/community-reports?status=${Uri.encodeQueryComponent(status)}',
          token: _token));

  Future<List<Map<String, dynamic>>> moderationPosts(
      {String? status, bool reported = false}) async {
    final query = <String, String>{
      if (reported) 'reported': '1',
      if (!reported && status != null && status.isNotEmpty) 'status': status,
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return _rows(await ApiClient.instance
        .get('/admin/community-posts$suffix', token: _token));
  }

  Future<List<Map<String, dynamic>>> moderationLog() async =>
      _rows(await ApiClient.instance
          .get('/admin/community-moderation-log', token: _token));

  Future<Map<String, dynamic>> moderationSettings() async =>
      Map<String, dynamic>.from(Json.rawMap(await ApiClient.instance
          .get('/admin/community-settings', token: _token)));

  Future<List<String>> saveBlockedTerms(List<String> terms) async {
    final data = await ApiClient.instance.put('/admin/community-settings',
        token: _token, body: {'blockedTerms': terms});
    final values = Json.list(Json.rawMap(data)['blockedTerms']);
    return values.map((value) => '$value').toList();
  }

  /// {'post', 'comments' (including hidden), 'reports', 'log'}
  Future<Map<String, dynamic>> moderationDetail(String postId) async {
    final data = await ApiClient.instance
        .get('/admin/community-posts/$postId', token: _token);
    return {
      'post': Map<String, dynamic>.from(Json.rawMap(data['post'])),
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
