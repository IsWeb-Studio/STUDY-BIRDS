import 'api_client.dart';
import 'auth_session.dart';

/// Talks to server/src/routes/parentRoutes.js. Requires role === 'parent'.
class ParentRepository {
  ParentRepository._();
  static final ParentRepository instance = ParentRepository._();

  String get _token {
    final token = AuthSession.instance.token;
    if (token == null) throw ApiException(401, 'لا توجد جلسة دخول نشطة');
    return token;
  }

  Future<List<dynamic>> getChildren() async {
    final data = await ApiClient.instance.get('/parents/children', token: _token);
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getLinkRequests() async {
    final data = await ApiClient.instance.get('/parents/link-requests', token: _token);
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createLinkRequest({required String studentEmail, String? relationship, String? note}) async {
    final data = await ApiClient.instance.post('/parents/link-requests', token: _token, body: {
      'studentEmail': studentEmail,
      if (relationship != null) 'relationship': relationship,
      if (note != null) 'note': note,
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getChildOverview(String studentId) async {
    final data = await ApiClient.instance.get('/parents/children/$studentId/overview', token: _token);
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getChildPayments(String studentId) async {
    final data = await ApiClient.instance.get('/parents/children/$studentId/payments', token: _token);
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> uploadPaymentProof({
    required String studentId,
    required String invoiceId,
    required List<int> fileBytes,
    required String fileName,
    String? note,
  }) async {
    final data = await ApiClient.instance.postMultipart(
      '/parents/children/$studentId/invoices/$invoiceId/pay',
      token: _token,
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {if (note != null && note.isNotEmpty) 'note': note},
    );
    return data as Map<String, dynamic>;
  }
}
