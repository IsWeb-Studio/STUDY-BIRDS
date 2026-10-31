import '../utils/json_safe.dart';
import '../network/api_client.dart';
import '../services/auth_session.dart';

/// Talks to server/src/routes/partnerRoutes.js. Requires role === 'partner'
/// (the app's UserRole.agent — see UserRoleWire in auth_session.dart).
class AgentRepository {
  AgentRepository._();
  static final AgentRepository instance = AgentRepository._();

  String get _token {
    final token = AuthSession.instance.token;
    if (token == null) throw const ApiException(401, 'لا توجد جلسة دخول نشطة');
    return token;
  }

  Future<Map<String, dynamic>> getOverview() async {
    final data = await ApiClient.instance.get('/partners/overview', token: _token);
    return Json.map(data);
  }

  Future<List<dynamic>> getStudents() async {
    final data = await ApiClient.instance.get('/partners/students', token: _token);
    return Json.list(data);
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
    return Json.map(data);
  }

  Future<Map<String, dynamic>> updateStudent(
      String studentId, Map<String, dynamic> payload) async {
    final data = await ApiClient.instance.put(
      '/partners/students/$studentId',
      token: _token,
      body: payload,
    );
    return Json.map(data);
  }

  Future<void> deleteStudent(String studentId) async {
    await ApiClient.instance.delete('/partners/students/$studentId', token: _token);
  }

  Future<Map<String, dynamic>> uploadStudentDocument({
    required String studentId,
    required List<int> fileBytes,
    required String fileName,
    required String label,
    String? type,
  }) async {
    final data = await ApiClient.instance.postMultipart(
      '/partners/students/$studentId/documents',
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {'label': label, if (type != null) 'type': type},
      token: _token,
    );
    return Json.map(data);
  }

  Future<Map<String, dynamic>> getWallet() async {
    final data = await ApiClient.instance.get('/partners/wallet', token: _token, cached: false);
    return Json.map(data);
  }

  Future<Map<String, dynamic>> requestPayout({required double amount, required String method, required String payoutDetails, String? notes}) async {
    final data = await ApiClient.instance.post('/partners/wallet/payout-requests', token: _token, body: {
      'amount': amount,
      'method': method,
      'payoutDetails': payoutDetails,
      if (notes != null) 'notes': notes,
    });
    return Json.map(data);
  }

  Future<Map<String, dynamic>> getReferralSummary() async {
    final data = await ApiClient.instance.get('/partners/referral', token: _token, cached: false);
    return Json.map(data);
  }

  Future<Map<String, dynamic>> getProfile() async => Json.map(
      await ApiClient.instance.get('/partners/profile', token: _token));

  Future<Map<String, dynamic>> updateProfile(
          Map<String, dynamic> payload) async =>
      Json.map(await ApiClient.instance.put('/partners/profile',
          token: _token, body: payload));

  Future<List<dynamic>> getMarketingAssets() async => Json.list(
      await ApiClient.instance.get('/partners/marketing-assets', token: _token));

  Future<Map<String, dynamic>> getVerification() async => Json.map(
      await ApiClient.instance.get('/partners/verification', token: _token));

  Future<Map<String, dynamic>> uploadVerificationDocument({
    required List<int> fileBytes,
    required String fileName,
    required String type,
  }) async =>
      Json.map(await ApiClient.instance.postMultipart(
        '/partners/verification/documents',
        fileBytes: fileBytes,
        fileName: fileName,
        fields: {'type': type},
        token: _token,
      ));

  Future<List<dynamic>> getSupportTickets() async => Json.list(
      await ApiClient.instance.get('/partners/tickets', token: _token));

  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String message,
    required String category,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final fields = {
      'subject': subject,
      'message': message,
      'category': category,
    };
    final data = fileBytes != null && fileName != null
        ? await ApiClient.instance.postMultipart(
            '/partners/tickets',
            fileBytes: fileBytes,
            fileName: fileName,
            fields: fields,
            token: _token,
          )
        : await ApiClient.instance.post('/partners/tickets',
            token: _token, body: fields);
    return Json.map(data);
  }

  Future<List<dynamic>> getActivityLog() async => Json.list(
      await ApiClient.instance.get('/partners/activity-log', token: _token));

  Future<List<dynamic>> getKnowledgeBase() async => Json.list(
      await ApiClient.instance.get('/partners/knowledge-base', token: _token));

  Future<List<dynamic>> getNotifications() async {
    final data = await ApiClient.instance.get('/partners/notifications', token: _token);
    return Json.list(data);
  }

  Future<void> markNotificationRead(String notificationId) async {
    await ApiClient.instance.patch('/partners/notifications/$notificationId/read', token: _token, body: {});
  }
}
