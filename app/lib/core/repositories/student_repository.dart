import '../utils/json_safe.dart';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../services/error_reporter.dart';
import '../services/secure_data_cache.dart';
import '../network/api_client.dart';
import '../utils/passport_scan.dart';
import '../services/auth_session.dart';
import '../services/realtime_sync_service.dart';

String documentFileHash(List<int> bytes) => sha256.convert(bytes).toString();

/// One stage in the backend's authoritative journey progress
/// (STUDENT_DASHBOARD_STAGES in server/src/controllers/studentController.js).
/// This is the REAL 6-stage list, with real Arabic copy from the server —
/// prefer this over any locally-invented stage text.
class DashboardStage {
  final String key;
  final String titleAr;
  final String descriptionAr;
  final String status; // 'completed' | 'current' | 'upcoming'

  const DashboardStage({
    required this.key,
    required this.titleAr,
    required this.descriptionAr,
    required this.status,
  });

  factory DashboardStage.fromJson(Map<String, dynamic> json) => DashboardStage(
        key: json['key'] as String? ?? '',
        titleAr: json['titleAr'] as String? ?? '',
        descriptionAr: json['descriptionAr'] as String? ?? '',
        status: json['status'] as String? ?? 'upcoming',
      );
}

class DashboardStats {
  final int currentApplications;
  final int acceptedDocuments;
  final int rejectedDocuments;
  final int pendingPayments;
  final int unreadNotifications;

  const DashboardStats({
    required this.currentApplications,
    required this.acceptedDocuments,
    required this.rejectedDocuments,
    required this.pendingPayments,
    required this.unreadNotifications,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        currentApplications: json['currentApplications'] as int? ?? 0,
        acceptedDocuments: json['acceptedDocuments'] as int? ?? 0,
        rejectedDocuments: json['rejectedDocuments'] as int? ?? 0,
        pendingPayments: json['pendingPayments'] as int? ?? 0,
        unreadNotifications: json['unreadNotifications'] as int? ?? 0,
      );
}

/// Full response of GET /api/students/overview.
class DashboardOverview {
  final List<Map<String, dynamic>>? journeys;
  final Map<String, dynamic>? nextAction;
  final Map<String, dynamic>?
      profile; // raw — includes journeyStage (14-value, new field)
  final String currentStage; // legacy 6-value key, e.g. 'applying'
  final List<DashboardStage>
      stages; // the real 6 stages with server-provided copy
  final DashboardStats stats;
  final Map<String, dynamic>? latestNotification;
  final List<dynamic> recentApplications;
  final List<dynamic> recentDocuments;

  /// Context-aware home payload (server utils/studentHome.js); null on older
  /// servers, in which case the home screen keeps its previous layout.
  final Map<String, dynamic>? home;

  /// Study Birds recognitions / accreditations shown on the home slider.
  /// Each entry: { _id, title, image, link }
  final List<Map<String, dynamic>> recognitions;

  const DashboardOverview({
    this.home,
    this.nextAction,
    this.journeys,
    this.recognitions = const [],
    required this.profile,
    required this.currentStage,
    required this.stages,
    required this.stats,
    required this.latestNotification,
    required this.recentApplications,
    required this.recentDocuments,
  });

  /// The new 14-value granular stage, if present (raw StudentProfile field —
  /// the /overview endpoint doesn't compute progress from it yet, but it IS
  /// included since `profile` is returned in full).
  String? get journeyStage => profile?['journeyStage'] as String?;

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    final progress = Json.mapOrNull(json['progress']) ?? {};
    final statsJson = Json.mapOrNull(json['stats']) ?? {};
    return DashboardOverview(
      home: json['home'] is Map
          ? Map<String, dynamic>.from(Json.rawMap(json['home']))
          : null,
      journeys: (Json.listOrNull(json['journeys']))
          ?.map((e) => Map<String, dynamic>.from(Json.rawMap(e)))
          .toList(),
      nextAction: Json.mapOrNull(json['nextAction']),
      profile: Json.mapOrNull(json['profile']),
      currentStage: progress['currentStage'] as String? ?? 'file-received',
      stages: (Json.listOrNull(progress['stages']) ?? [])
          .map((e) => DashboardStage.fromJson(Json.map(e)))
          .toList(),
      stats: DashboardStats.fromJson(statsJson),
      latestNotification: Json.mapOrNull(json['latestNotification']),
      recentApplications: Json.listOrNull(json['recentApplications']) ?? [],
      recentDocuments: Json.listOrNull(json['recentDocuments']) ?? [],
      recognitions: (Json.listOrNull(json['recognitions']) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}

/// The 14-value granular journey stages, in order — matches
/// constants/roles.js JOURNEY_STAGES on the backend exactly. Used to render
/// the detailed Journey Tracker from the raw `journeyStage` string.
const List<Map<String, String>> kJourneyStageOrder = [
  {'key': 'file-received', 'title': 'استلام الملف'},
  {'key': 'documents-review', 'title': 'مراجعة المستندات'},
  {'key': 'university-selection', 'title': 'اختيار الجامعة'},
  {'key': 'applying', 'title': 'التقديم'},
  {'key': 'university-review', 'title': 'مراجعة الجامعة'},
  {'key': 'preliminary-accepted', 'title': 'القبول المبدئي'},
  {'key': 'first-payment', 'title': 'الدفع'},
  {'key': 'final-accepted', 'title': 'القبول النهائي'},
  {'key': 'visa', 'title': 'التأشيرة'},
  {'key': 'travel', 'title': 'السفر'},
  {'key': 'reception', 'title': 'الاستقبال'},
  {'key': 'accommodation', 'title': 'السكن'},
  {'key': 'university-registration', 'title': 'التسجيل في الجامعة'},
  {'key': 'studies-started', 'title': 'بدء الدراسة'},
];

/// Talks to the real Study Birds backend for everything under
/// server/src/routes/studentRoutes.js. Every call requires a valid session
/// token (student or partner role, per the backend's `protect` middleware).
class StudentRepository {
  StudentRepository._();
  static final StudentRepository instance = StudentRepository._();
  final _documentChanges = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get documentChanges => _documentChanges.stream;
  final _documentUploads = <String, Future<Map<String, dynamic>>>{};
  String? _documentOwner;
  List<dynamic> _documents = [];
  int _documentRevision = 0;

  void _publishDocuments(List<dynamic> documents, String session) {
    if (AuthSession.instance.token != session) return;
    _documentOwner = session;
    _documents = documents;
    _documentChanges.add(List.unmodifiable(documents));
  }

  String get _token {
    final token = AuthSession.instance.token;
    if (token == null) {
      throw ApiException(401, 'لا توجد جلسة دخول نشطة');
    }
    return token;
  }

  Future<dynamic> _loadSnapshot(String resource,
      {bool forceRefresh = false}) async {
    final owner = AuthSession.instance.currentUser?.id ?? '';
    final sessionToken = _token;
    try {
      final data = await ApiClient.instance.get('/students/$resource',
          token: sessionToken, cached: !forceRefresh);
      // A response from the account that just signed out must not refill its cache.
      if (owner.isNotEmpty &&
          AuthSession.instance.currentUser?.id == owner &&
          AuthSession.instance.token != null) {
        try {
          await SecureDataCache.write(owner, resource, data as Object);
        } catch (swallowedError, swallowedStack) {
          ErrorReporter.swallowed(swallowedError, swallowedStack,
              'core/repositories/student_repository.dart:166');
        }
      }
      return data;
    } catch (error) {
      if (error is ApiException &&
          error.statusCode < 500 &&
          error.statusCode != 0) rethrow;
      if (!forceRefresh && AuthSession.instance.currentUser?.id == owner) {
        try {
          final cached = await SecureDataCache.read(owner, resource);
          if (cached != null) return cached;
        } catch (swallowedError, swallowedStack) {
          ErrorReporter.swallowed(swallowedError, swallowedStack,
              'core/repositories/student_repository.dart:175');
        }
      }
      rethrow;
    }
  }

  Future<DashboardOverview> getOverview({bool forceRefresh = false}) async =>
      DashboardOverview.fromJson(Json.map(
          await _loadSnapshot('overview', forceRefresh: forceRefresh)));

  Future<Map<String, dynamic>> getFinancials(
          {bool forceRefresh = false}) async =>
      Json.map(await _loadSnapshot('financials', forceRefresh: forceRefresh));

  Future<void> clearOverviewCache() async {
    await SecureDataCache.clear(AuthSession.instance.currentUser?.id ?? '');
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final data =
        await ApiClient.instance.get('/students/profile', token: _token);
    return Json.mapOrNull(data);
  }

  Future<void> updateProfile(Map<String, dynamic> profile) async {
    const fields = [
      'phone',
      'englishFullName',
      'passportNumber',
      'dateOfBirth',
      'nationality',
      'currentEducation',
      'currentEducationLevel',
      'currentResidenceCountry',
      'currentResidenceRegion',
      'gpa',
      'englishTest',
      'targetCountries',
      'intake',
      'bio',
      'address',
      'parentInfo',
      'emergencyContact',
      'nativeLanguage',
      'otherLanguages',
    ];
    await ApiClient.instance.put('/students/profile', token: _token, body: {
      for (final field in fields)
        if (profile.containsKey(field)) field: profile[field],
    });
    // Invalidate cached GET so the next getProfile() fetches fresh data.
    ApiClient.instance.clearCache();
  }

  Future<List<dynamic>> getApplications({bool forceRefresh = false}) async {
    return Json.list(
        await _loadSnapshot('applications', forceRefresh: forceRefresh));
  }

  Future<List<dynamic>> getDocuments({bool forceRefresh = false}) async {
    final session = _token;
    final revision = _documentRevision;
    final documents =
        Json.list(await _loadSnapshot('documents', forceRefresh: forceRefresh));
    if (revision != _documentRevision && _documentOwner == session) {
      final owner = AuthSession.instance.currentUser?.id;
      if (owner != null) {
        unawaited(SecureDataCache.write(owner, 'documents', _documents)
            .catchError(
                ErrorReporter.silent('documents.cache.stale-response')));
      }
      return List.unmodifiable(_documents);
    }
    _publishDocuments(documents, session);
    return documents;
  }

  /// Uploads a document — matches POST /api/students/documents
  /// (Multer `upload.single("file")`, plus a `type` form field).
  Future<Map<String, dynamic>> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String type,
    String? replaces,
    String? translationOf,
    void Function(double)? onProgress,
    UploadCancellation? cancellation,
    void Function()? onPassportValidated,
    Map<String, Object>? passportReview,
  }) async {
    final session = _token;
    final hash = await compute(documentFileHash, fileBytes);
    if (AuthSession.instance.token != session) {
      throw const ApiException(401, 'Session changed');
    }
    final key = '$session:$type:$hash:${translationOf ?? ''}:${replaces ?? ''}';
    final pending = _documentUploads[key];
    if (pending != null) return pending;
    final upload = _uploadLibraryDocument(
        fileBytes: fileBytes,
        fileName: fileName,
        type: type,
        replaces: replaces,
        translationOf: translationOf,
        onProgress: onProgress,
        cancellation: cancellation,
        onPassportValidated: onPassportValidated,
        passportReview: passportReview,
        hash: hash,
        session: session);
    _documentUploads[key] = upload;
    try {
      return await upload;
    } finally {
      _documentUploads.remove(key);
    }
  }

  Future<Map<String, dynamic>> _uploadLibraryDocument({
    required List<int> fileBytes,
    required String fileName,
    required String type,
    required String hash,
    required String session,
    String? replaces,
    String? translationOf,
    void Function(double)? onProgress,
    UploadCancellation? cancellation,
    void Function()? onPassportValidated,
    Map<String, Object>? passportReview,
  }) async {
    if (cancellation?.cancelled == true)
      throw const ApiException(499, 'Upload cancelled');
    Map<String, dynamic>? existing;
    try {
      final lookup = await ApiClient.instance
          .post('/students/documents/lookup', token: session, body: {
        'fileHash': hash,
        'size': fileBytes.length,
        'type': translationOf != null ? 'translation' : type,
        if (translationOf != null) 'translationOf': translationOf
      });
      existing = Json.mapOrNull(lookup['document']);
    } on ApiException catch (error) {
      // Older servers remain compatible. Other failures must not start an
      // uncertain extra upload; the user can safely retry instead.
      if (error.statusCode != 404) rethrow;
    }
    if (cancellation?.cancelled == true)
      throw const ApiException(499, 'Upload cancelled');
    if (existing != null && !(type == 'passport' && passportReview != null && existing['passportReview'] == null)) {
      _documentConfirmed({...existing, 'reused': true}, session);
      return {...existing, 'reused': true};
    }
    if (type == 'passport' && translationOf == null) {
      await PassportScan.validate(fileBytes);
      if (cancellation?.cancelled == true) {
        throw const ApiException(499, 'Upload cancelled');
      }
      onPassportValidated?.call();
    }
    final data = await ApiClient.instance.postMultipart(
      '/students/documents',
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {
        if (type.isNotEmpty) 'type': type,
        if (replaces != null) 'replaces': replaces,
        if (translationOf != null) 'translationOf': translationOf,
        if (passportReview != null)
          'passportReview': jsonEncode(passportReview),
      },
      token: session,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    final document = Json.map(data);
    _documentConfirmed(document, session);
    return document;
  }

  void _documentConfirmed(Map<String, dynamic> document, String session) {
    if (AuthSession.instance.token != session) return;
    _documentRevision++;
    final current = _documentOwner == session ? _documents : <dynamic>[];
    final replaced = document['replaces'];
    _publishDocuments([
      document,
      for (final item in current)
        if (item['_id'] != document['_id'])
          if (replaced != null && item['_id'] == replaced)
            {
              ...Json.map(item),
              'supersededBy': document['_id'],
              'isLatest': false
            }
          else
            item
    ], session);
    // Only server-confirmed metadata is published or persisted.
    final owner = AuthSession.instance.currentUser?.id;
    if (owner != null) {
      unawaited(SecureDataCache.write(owner, 'documents', _documents)
          .catchError(ErrorReporter.silent('documents.cache.confirmed')));
    }
    RealtimeSyncService.instance.forceSync();
  }

  Future<void> archiveDocument(String id) async {
    final session = _token;
    await ApiClient.instance
        .patch('/students/documents/$id/archive', token: session);
    if (_documentOwner == session) {
      _documentRevision++;
      _publishDocuments([
        for (final item in _documents)
          if (item['_id'] == id)
            {...Json.map(item), 'archivedAt': DateTime.now().toIso8601String()}
          else
            item
      ], session);
      final owner = AuthSession.instance.currentUser?.id;
      if (owner != null && AuthSession.instance.token == session) {
        unawaited(SecureDataCache.write(owner, 'documents', _documents)
            .catchError(ErrorReporter.silent('documents.cache.archived')));
      }
    }
    RealtimeSyncService.instance.forceSync();
  }

  Future<List<dynamic>> getNotifications() async {
    final data = await ApiClient.instance
        .get('/students/notifications', token: _token, cached: false);
    return Json.list(data);
  }

  Future<void> markNotificationRead(String id) async {
    await ApiClient.instance
        .patch('/students/notifications/$id/read', token: _token);
  }

  Future<void> markAllNotificationsRead() async {
    await ApiClient.instance
        .patch('/students/notifications/read-all', token: _token);
  }

  /// Real endpoint covering flight + airport pickup + housing + visa/residence
  /// support in ONE consolidated request (see ArrivalServiceRequest.js).
  /// Returns null if the student hasn't submitted one yet.
  Future<List<dynamic>> getArrivalServices() async {
    final data = await ApiClient.instance
        .get('/students/arrival-services', token: _token);
    if (data is List) return data;
    if (data is Map) return [data]; // backward compat
    return [];
  }

  Map<String, dynamic> _arrivalBody({
    String? arrivalDate,
    String? arrivalTime,
    String? flightNumber,
    String? airport,
    String? notes,
    required bool airportPickup,
    required bool studentHousing,
    required bool residencePermitSupport,
    required bool visaSupport,
  }) =>
      {
        if (arrivalDate != null) 'arrivalDate': arrivalDate,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (flightNumber != null) 'flightNumber': flightNumber,
        if (airport != null) 'airport': airport,
        if (notes != null) 'notes': notes,
        'services': {
          'airportPickup': airportPickup,
          'studentHousing': studentHousing,
          'residencePermitSupport': residencePermitSupport,
          'visaSupport': visaSupport,
        },
      };

  Future<Map<String, dynamic>> createArrivalService({
    String? applicationId,
    String? arrivalDate,
    String? arrivalTime,
    String? flightNumber,
    String? airport,
    String? notes,
    required bool airportPickup,
    required bool studentHousing,
    required bool residencePermitSupport,
    required bool visaSupport,
  }) async {
    final body = _arrivalBody(
      arrivalDate: arrivalDate,
      arrivalTime: arrivalTime,
      flightNumber: flightNumber,
      airport: airport,
      notes: notes,
      airportPickup: airportPickup,
      studentHousing: studentHousing,
      residencePermitSupport: residencePermitSupport,
      visaSupport: visaSupport,
    );
    if (applicationId != null) body['applicationId'] = applicationId;
    final data = await ApiClient.instance
        .post('/students/arrival-services', token: _token, body: body);
    return Json.map(data);
  }

  /// Throws ApiException(400, ...) if the student hasn't reached
  /// final-accepted / travel-and-settlement yet — the backend enforces this.
  Future<Map<String, dynamic>> upsertArrivalServices({
    String? id,
    String? arrivalDate,
    String? arrivalTime,
    String? flightNumber,
    String? airport,
    String? notes,
    required bool airportPickup,
    required bool studentHousing,
    required bool residencePermitSupport,
    required bool visaSupport,
  }) async {
    final path = id != null
        ? '/students/arrival-services/$id'
        : '/students/arrival-services';
    final data = await ApiClient.instance.put(path,
        token: _token,
        body: _arrivalBody(
          arrivalDate: arrivalDate,
          arrivalTime: arrivalTime,
          flightNumber: flightNumber,
          airport: airport,
          notes: notes,
          airportPickup: airportPickup,
          studentHousing: studentHousing,
          residencePermitSupport: residencePermitSupport,
          visaSupport: visaSupport,
        ));
    return Json.map(data);
  }

  Future<List<Map<String, dynamic>>> getSupportTeam() async {
    final data = await ApiClient.instance.get('/students/support-team', token: _token);
    return Json.list(data).map(Json.map).toList();
  }

  Future<List<dynamic>> getSupportTickets() async {
    final data = await ApiClient.instance
        .get('/students/support-tickets', token: _token);
    return Json.list(data);
  }

  /// Categories accepted by the backend (STUDENT_SUPPORT_CATEGORIES in
  /// studentController.js) — free text is rejected with a 400.
  static const List<Map<String, String>> supportCategories = [
    {'key': 'technical-issue', 'label': 'مشكلة في التطبيق'},
    {'key': 'documents', 'label': 'المستندات'},
    {'key': 'application-status', 'label': 'حالة الطلب'},
    {'key': 'payment', 'label': 'الدفعات'},
    {'key': 'arrival-services', 'label': 'خدمات الوصول'},
    {'key': 'other', 'label': 'أخرى'},
  ];

  Future<Map<String, dynamic>> replyToSupportTicket({
    required String ticketId,
    required String message,
  }) async {
    final data = await ApiClient.instance.patch(
      '/students/support-tickets/$ticketId/reply',
      token: _token,
      body: {'message': message},
    );
    return Json.map(data);
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String message,
    required String category,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes != null && fileName != null) {
      final data = await ApiClient.instance.postMultipart(
        '/students/support-tickets',
        fileBytes: fileBytes,
        fileName: fileName,
        fields: {'subject': subject, 'message': message, 'category': category},
        token: _token,
      );
      return Json.map(data);
    }
    final data = await ApiClient.instance
        .post('/students/support-tickets', token: _token, body: {
      'subject': subject,
      'message': message,
      'category': category,
    });
    return Json.map(data);
  }

  /// Uploads a payment proof against a specific invoice — matches
  /// POST /api/students/financials/invoices/:id/payment-proof.
  Future<Map<String, dynamic>> uploadPaymentProof({
    required String invoiceId,
    required List<int> fileBytes,
    required String fileName,
    double? amount,
    String? note,
  }) async {
    final data = await ApiClient.instance.postMultipart(
      '/students/financials/invoices/$invoiceId/payment-proof',
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {
        if (amount != null) 'amount': amount.toString(),
        if (note != null) 'note': note,
      },
      token: _token,
    );
    return Json.map(data);
  }

  // ---- Favorites ----------------------------------------------------------

  Future<List<dynamic>> getFavorites() async {
    final data =
        await ApiClient.instance.get('/students/favorites', token: _token);
    return Json.list(data);
  }

  /// Toggles a favorite on/off. Returns the raw response — either the
  /// created favorite doc, or `{removed: true, id: ...}` if it was already
  /// favorited (the backend toggles, per toggleStudentFavorite).
  Future<Map<String, dynamic>> toggleFavorite(
      {required String itemType,
      String? universityId,
      String? programId,
      String? articleSlug,
      String? articleTitle}) async {
    final data = await ApiClient.instance
        .post('/students/favorites/toggle', token: _token, body: {
      'itemType': itemType,
      if (universityId != null) 'universityId': universityId,
      if (programId != null) 'programId': programId,
      if (articleSlug != null) 'articleSlug': articleSlug,
      if (articleTitle != null) 'articleTitle': articleTitle,
    });
    return Json.map(data);
  }

  Future<void> removeFavorite(String id) async {
    await ApiClient.instance.delete('/students/favorites/$id', token: _token);
  }

  // ---- Knowledge Base -------------------------------------------------------

  Future<List<dynamic>> getKnowledgeBase() async {
    final data =
        await ApiClient.instance.get('/students/knowledge-base', token: _token);
    return Json.list(data);
  }

  // ---- Orientation Test (a.k.a. "Program Finder") ----------------------------

  /// Returns null if the student hasn't taken the test yet.
  Future<Map<String, dynamic>?> getOrientationTestResult() async {
    final data = await ApiClient.instance
        .get('/students/orientation-test', token: _token);
    return Json.mapOrNull(data);
  }

  Future<Map<String, dynamic>> submitOrientationTest({
    List<String>? favoriteSubjects,
    List<String>? interestedFields,
    String? studyStyle,
    String? preferredLanguage,
    String? preferredCountry,
    String? approximateBudget,
    String? desiredDegreeLevel,
    List<String>? avoidFields,
  }) async {
    final data = await ApiClient.instance
        .post('/students/orientation-test', token: _token, body: {
      if (favoriteSubjects != null) 'favoriteSubjects': favoriteSubjects,
      if (interestedFields != null) 'interestedFields': interestedFields,
      if (studyStyle != null) 'studyStyle': studyStyle,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
      if (preferredCountry != null) 'preferredCountry': preferredCountry,
      if (approximateBudget != null) 'approximateBudget': approximateBudget,
      if (desiredDegreeLevel != null) 'desiredDegreeLevel': desiredDegreeLevel,
      if (avoidFields != null) 'avoidFields': avoidFields,
    });
    return Json.map(data);
  }

  Future<Map<String, dynamic>?> getInsurance() async {
    final data =
        await ApiClient.instance.get('/students/insurance', token: _token);
    if (data == null) return null;
    return Json.map(data);
  }

  Future<Map<String, dynamic>?> getEquivalency() async {
    final data =
        await ApiClient.instance.get('/students/equivalency', token: _token);
    if (data == null) return null;
    return Json.map(data);
  }
}
