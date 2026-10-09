import '../network/api_client.dart';
import '../services/auth_session.dart';

/// Covers server/src/controllers/adminStudentModulesController.js and
/// adminAgentController.js — the "student modules" and "partner/agent
/// modules" employee sections. Each method's doc comment names the exact
/// section key it corresponds to in employeeSections.json.
class AdminModulesRepository {
  AdminModulesRepository._();
  static final AdminModulesRepository instance = AdminModulesRepository._();

  String get _token {
    final token = AuthSession.instance.token;
    if (token == null) throw ApiException(401, 'لا توجد جلسة دخول نشطة');
    return token;
  }

  // ---- applications ---------------------------------------------------
  Future<List<dynamic>> getApplications() async =>
      await ApiClient.instance.get('/admin/applications', token: _token) as List<dynamic>;

  // ---- student-documents ------------------------------------------------
  Future<List<dynamic>> getStudentDocuments() async =>
      await ApiClient.instance.get('/admin/student-documents', token: _token) as List<dynamic>;

  // ---- student-financials -------------------------------------------------
  Future<Map<String, dynamic>> getStudentFinancials() async =>
      await ApiClient.instance.get('/admin/student-financials', token: _token) as Map<String, dynamic>;

  Future<Map<String, dynamic>> createInvoice({
    required String studentId,
    required String description,
    required num amount,
  }) async =>
      await ApiClient.instance.post('/admin/student-financials/invoices', token: _token, body: {
        'student': studentId,
        'description': description,
        'amount': amount,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateInvoice(String id, {String? status, String? description, num? amount}) async =>
      await ApiClient.instance.patch('/admin/student-financials/invoices/$id', token: _token, body: {
        if (status != null) 'status': status,
        if (description != null) 'description': description,
        if (amount != null) 'amount': amount,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> reviewPaymentProof(String id, {required String status, String? note}) async =>
      await ApiClient.instance.patch('/admin/student-financials/payment-proofs/$id', token: _token, body: {
        'status': status,
        if (note != null) 'note': note,
      }) as Map<String, dynamic>;

  // ---- student-arrivals -------------------------------------------------
  Future<List<dynamic>> getArrivalRequests() async =>
      await ApiClient.instance.get('/admin/student-arrival-requests', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> updateArrivalRequest(String id, {required String status, String? note}) async =>
      await ApiClient.instance.patch('/admin/student-arrival-requests/$id', token: _token, body: {
        'status': status,
        if (note != null) 'note': note,
      }) as Map<String, dynamic>;

  // ---- support (support-tickets) -----------------------------------------
  Future<List<dynamic>> getSupportTickets() async =>
      await ApiClient.instance.get('/admin/support-tickets', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> replySupportTicket(String id, {required String message, String? status}) async =>
      await ApiClient.instance.patch('/admin/support-tickets/$id/reply', token: _token, body: {
        'message': message,
        if (status != null) 'status': status,
      }) as Map<String, dynamic>;

  // ---- student-notifications ------------------------------------------
  Future<List<dynamic>> getStudentNotifications() async =>
      await ApiClient.instance.get('/admin/student-notifications', token: _token) as List<dynamic>;

  // ---- student-favorites (read-only) -------------------------------------
  Future<List<dynamic>> getStudentFavorites() async =>
      await ApiClient.instance.get('/admin/student-favorites', token: _token) as List<dynamic>;

  // ---- knowledge-base -----------------------------------------------------
  Future<List<dynamic>> getKnowledgeBase() async =>
      await ApiClient.instance.get('/admin/knowledge-base', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createKnowledgeBaseItem({required String title, required String body, String? resourceType}) async =>
      await ApiClient.instance.post('/admin/knowledge-base', token: _token, body: {
        'title': title,
        'body': body,
        if (resourceType != null) 'resourceType': resourceType,
      }) as Map<String, dynamic>;

  Future<void> deleteKnowledgeBaseItem(String id) async {
    await ApiClient.instance.delete('/admin/knowledge-base/$id', token: _token);
  }

  // ---- student-orientation ------------------------------------------------
  Future<List<dynamic>> getOrientationResults() async =>
      await ApiClient.instance.get('/admin/student-orientation-results', token: _token) as List<dynamic>;

  // ---- agency-requests ------------------------------------------------------
  Future<List<dynamic>> getAgencyRequests() async =>
      await ApiClient.instance.get('/admin/agency-requests', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> updateAgencyRequestStatus(String id, {required String status, String? adminNote}) async =>
      await ApiClient.instance.patch('/admin/agency-requests/$id', token: _token, body: {
        'status': status,
        if (adminNote != null) 'adminNote': adminNote,
      }) as Map<String, dynamic>;

  // ---- agents (partner profiles) -------------------------------------------
  Future<List<dynamic>> getPartners() async =>
      await ApiClient.instance.get('/admin/partners', token: _token) as List<dynamic>;

  // ---- partner-students -----------------------------------------------------
  Future<List<dynamic>> getAllPartnerStudents() async =>
      await ApiClient.instance.get('/admin/partner-students', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> updatePartnerStudentStatus(String studentId, {required String applicationStatus}) async =>
      await ApiClient.instance.patch('/admin/partner-students/$studentId', token: _token, body: {
        'applicationStatus': applicationStatus,
      }) as Map<String, dynamic>;

  // ---- marketing-assets (read + delete only from the app for now; upload
  // needs a file, offered from Documents-style pickers if needed later) ----
  Future<List<dynamic>> getMarketingAssets() async =>
      await ApiClient.instance.get('/admin/marketing-assets', token: _token) as List<dynamic>;

  Future<void> deleteMarketingAsset(String id) async {
    await ApiClient.instance.delete('/admin/marketing-assets/$id', token: _token);
  }

  // ---- verification (agent verification documents) -----------------------
  Future<List<dynamic>> getVerificationQueue() async =>
      await ApiClient.instance.get('/admin/verification-documents', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> reviewVerificationDocument(String id, {required String status, String? note}) async =>
      await ApiClient.instance.patch('/admin/verification-documents/$id', token: _token, body: {
        'status': status,
        if (note != null) 'note': note,
      }) as Map<String, dynamic>;

  // ---- payouts --------------------------------------------------------------
  Future<List<dynamic>> getPayoutRequests() async =>
      await ApiClient.instance.get('/admin/payout-requests', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> updatePayoutRequestStatus(String id, {required String status, String? note}) async =>
      await ApiClient.instance.patch('/admin/payout-requests/$id', token: _token, body: {
        'status': status,
        if (note != null) 'note': note,
      }) as Map<String, dynamic>;

  // ======================================================================
  // Content-management sections (web-parity batch 2). Image fields are
  // plain URL strings on the backend (logo/image/heroImage/etc) — the app
  // lets the admin paste a URL rather than upload from the device, to keep
  // 11 different content types tractable. Full device-upload can be added
  // per-section later if needed.
  // ======================================================================

  // ---- universities -----------------------------------------------------
  Future<Map<String, dynamic>> createUniversity(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/universities', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateUniversity(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/universities/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteUniversity(String id) async {
    await ApiClient.instance.delete('/universities/$id', token: _token);
  }

  // ---- programs -----------------------------------------------------------
  Future<Map<String, dynamic>> createProgram(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/programs', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateProgram(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/programs/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteProgram(String id) async {
    await ApiClient.instance.delete('/programs/$id', token: _token);
  }

  // ---- content: countries --------------------------------------------------
  Future<List<dynamic>> getCountries() async =>
      await ApiClient.instance.get('/admin/countries', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createCountry(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/countries', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateCountry(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/countries/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteCountry(String id) async {
    await ApiClient.instance.delete('/admin/countries/$id', token: _token);
  }

  // ---- content: study fields ------------------------------------------------
  Future<List<dynamic>> getStudyFields() async =>
      await ApiClient.instance.get('/admin/study-fields', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createStudyField(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/study-fields', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateStudyField(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/study-fields/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteStudyField(String id) async {
    await ApiClient.instance.delete('/admin/study-fields/$id', token: _token);
  }

  // ---- site-settings (singleton) -------------------------------------------
  Future<Map<String, dynamic>> getSiteSettings() async =>
      await ApiClient.instance.get('/admin/site-settings', token: _token) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateSiteSettings(Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/site-settings', token: _token, body: payload) as Map<String, dynamic>;

  // ---- testimonials -----------------------------------------------------
  Future<List<dynamic>> getTestimonials() async =>
      await ApiClient.instance.get('/admin/testimonials', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createTestimonial(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/testimonials', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateTestimonial(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/testimonials/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteTestimonial(String id) async {
    await ApiClient.instance.delete('/admin/testimonials/$id', token: _token);
  }

  // ---- recognitions ---------------------------------------------------------
  Future<List<dynamic>> getRecognitions() async =>
      await ApiClient.instance.get('/admin/recognitions', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createRecognition(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/recognitions', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateRecognition(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/recognitions/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteRecognition(String id) async {
    await ApiClient.instance.delete('/admin/recognitions/$id', token: _token);
  }

  // ---- services (our-services) ---------------------------------------------
  Future<List<dynamic>> getServices() async =>
      await ApiClient.instance.get('/admin/our-services', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createService(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/our-services', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateService(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/our-services/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteService(String id) async {
    await ApiClient.instance.delete('/admin/our-services/$id', token: _token);
  }

  // ---- faqs -------------------------------------------------------------------
  Future<List<dynamic>> getFaqs() async =>
      await ApiClient.instance.get('/admin/faqs', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createFaq(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/faqs', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateFaq(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/faqs/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteFaq(String id) async {
    await ApiClient.instance.delete('/admin/faqs/$id', token: _token);
  }

  // ---- our-story (singleton) -------------------------------------------------
  Future<Map<String, dynamic>> getOurStory() async =>
      await ApiClient.instance.get('/admin/our-story', token: _token) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateOurStory(Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/our-story', token: _token, body: payload) as Map<String, dynamic>;

  // ---- events: upcoming (singleton) + past (list) + registrations (read) ----
  Future<Map<String, dynamic>> getUpcomingEvent() async =>
      await ApiClient.instance.get('/admin/upcoming-event', token: _token) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateUpcomingEvent(Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/upcoming-event', token: _token, body: payload) as Map<String, dynamic>;

  Future<List<dynamic>> getPastEvents() async =>
      await ApiClient.instance.get('/admin/past-events', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createPastEvent(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/past-events', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updatePastEvent(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/past-events/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deletePastEvent(String id) async {
    await ApiClient.instance.delete('/admin/past-events/$id', token: _token);
  }

  Future<List<dynamic>> getEventRegistrations() async =>
      await ApiClient.instance.get('/admin/event-registrations', token: _token) as List<dynamic>;

  // ---- exhibitions --------------------------------------------------------------
  Future<List<dynamic>> getExhibitions() async =>
      await ApiClient.instance.get('/admin/exhibitions', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createExhibition(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/exhibitions', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateExhibition(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/exhibitions/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteExhibition(String id) async {
    await ApiClient.instance.delete('/admin/exhibitions/$id', token: _token);
  }

  // ---- banners ----------------------------------------------------------------
  Future<List<dynamic>> getBanners() async =>
      await ApiClient.instance.get('/admin/banners', token: _token) as List<dynamic>;

  Future<Map<String, dynamic>> createBanner(Map<String, dynamic> payload) async =>
      await ApiClient.instance.post('/admin/banners', token: _token, body: payload) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateBanner(String id, Map<String, dynamic> payload) async =>
      await ApiClient.instance.put('/admin/banners/$id', token: _token, body: payload) as Map<String, dynamic>;

  Future<void> deleteBanner(String id) async {
    await ApiClient.instance.delete('/admin/banners/$id', token: _token);
  }

  // ---- generic image upload (Cloudinary via the backend's multer routes) --
  /// Returns the uploaded file's URL. Handles both response shapes used
  /// across the backend: `{url}` for single-file endpoints and
  /// `{urls:[...]}` for the university multi-image endpoint (first URL is
  /// used there, matching the single "logo" field this app exposes).
  Future<String> uploadImage(String path, {required List<int> fileBytes, required String fileName, String fileFieldName = 'file'}) async {
    final data = await ApiClient.instance.postMultipart(path, fileBytes: fileBytes, fileName: fileName, fileFieldName: fileFieldName, token: _token);
    final map = data as Map<String, dynamic>;
    if (map['url'] is String) return map['url'] as String;
    if (map['urls'] is List && (map['urls'] as List).isNotEmpty) return (map['urls'] as List).first as String;
    throw ApiException(0, 'Unexpected upload response');
  }
}
