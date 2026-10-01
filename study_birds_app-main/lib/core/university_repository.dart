import 'api_client.dart';
import 'auth_session.dart';

/// Talks to server/src/routes/universityPortalRoutes.js. Requires
/// role === 'university'; every query is scoped server-side to the
/// account's own linkedUniversity (no IDOR across universities).
class UniversityRepository {
  UniversityRepository._();
  static final UniversityRepository instance = UniversityRepository._();

  String get _token {
    final token = AuthSession.instance.token;
    if (token == null) throw ApiException(401, 'لا توجد جلسة دخول نشطة');
    return token;
  }

  Future<List<dynamic>> getApplications({String? status}) async {
    final qs = status != null ? '?status=$status' : '';
    final data = await ApiClient.instance.get('/university-portal/applications$qs', token: _token);
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getApplicationById(String id) async {
    final data = await ApiClient.instance.get('/university-portal/applications/$id', token: _token);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateApplicationStatus(String id, {required String detailedStatus, String? note}) async {
    final data = await ApiClient.instance.patch('/university-portal/applications/$id/status', token: _token, body: {
      'detailedStatus': detailedStatus,
      if (note != null) 'note': note,
    });
    return data as Map<String, dynamic>;
  }

  Future<void> requestDocument(String id, {String? documentType, String? reason}) async {
    await ApiClient.instance.post('/university-portal/applications/$id/request-document', token: _token, body: {
      if (documentType != null) 'documentType': documentType,
      if (reason != null) 'reason': reason,
    });
  }

  Future<int> getFavoritesCount() async {
    final data = await ApiClient.instance.get('/university-portal/favorites-count', token: _token);
    return (data as Map<String, dynamic>)['count'] as int? ?? 0;
  }
}
