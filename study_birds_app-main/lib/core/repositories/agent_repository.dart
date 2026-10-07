import '../network/api_client.dart';
import '../services/auth_session.dart';

/// Talks to server/src/routes/partnerRoutes.js. Requires role === 'partner'
/// (the app's UserRole.agent — see UserRoleWire in auth_session.dart).
class AgentRepository {
  AgentRepository._();
  static final AgentRepository instance = AgentRepository._();

  String get _token {
    final token = AuthSession.instance.token;
    if (token == null) throw ApiException(401, 'لا توجد جلسة دخول نشطة');
    return token;
  }

  Future<Map<String, dynamic>> getOverview() async {
    final data = await ApiClient.instance.get('/partners/overview', token: _token);
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getStudents() async {
    final data = await ApiClient.instance.get('/partners/students', token: _token);
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createStudent({
    required String name,
    required String email,
    required String phone,
    String? passportNumber,
    String? studyPreferences,
    String? desiredUniversity,
    String? desiredProgram,
    String? notes,
    String? country,
    String? applicationStage,
  }) async {
    final data = await ApiClient.instance.post('/partners/students', token: _token, body: {
      'name': name,
      'email': email,
      'phone': phone,
      if (passportNumber != null) 'passportNumber': passportNumber,
      if (studyPreferences != null) 'studyPreferences': studyPreferences,
      if (desiredUniversity != null) 'desiredUniversity': desiredUniversity,
      if (desiredProgram != null) 'desiredProgram': desiredProgram,
      if (notes != null) 'notes': notes,
      if (country != null && country.isNotEmpty) 'country': country,
      if (applicationStage != null) 'applicationStage': applicationStage,
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadStudentDocument({
    required String studentId,
    required List<int> fileBytes,
    required String fileName,
    required String label,
  }) async {
    final data = await ApiClient.instance.postMultipart(
      '/partners/students/$studentId/documents',
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {'label': label},
      token: _token,
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWallet() async {
    final data = await ApiClient.instance.get('/partners/wallet', token: _token);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> requestPayout({required double amount, required String method, required String payoutDetails, String? notes}) async {
    final data = await ApiClient.instance.post('/partners/wallet/payout-requests', token: _token, body: {
      'amount': amount,
      'method': method,
      'payoutDetails': payoutDetails,
      if (notes != null) 'notes': notes,
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReferralSummary() async {
    final data = await ApiClient.instance.get('/partners/referral', token: _token);
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getNotifications() async {
    final data = await ApiClient.instance.get('/partners/notifications', token: _token);
    return data as List<dynamic>;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await ApiClient.instance.patch('/partners/notifications/$notificationId/read', token: _token, body: {});
  }
}
