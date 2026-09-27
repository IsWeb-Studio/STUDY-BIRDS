import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_session.dart';

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

  const DashboardOverview({
    this.home,
    this.nextAction,
    this.journeys,
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
    final progress = json['progress'] as Map<String, dynamic>? ?? {};
    final statsJson = json['stats'] as Map<String, dynamic>? ?? {};
    return DashboardOverview(
      home: json['home'] is Map
          ? Map<String, dynamic>.from(json['home'] as Map)
          : null,
      journeys: (json['journeys'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      nextAction: json['nextAction'] as Map<String, dynamic>?,
      profile: json['profile'] as Map<String, dynamic>?,
      currentStage: progress['currentStage'] as String? ?? 'file-received',
      stages: (progress['stages'] as List<dynamic>? ?? [])
          .map((e) => DashboardStage.fromJson(e as Map<String, dynamic>))
          .toList(),
      stats: DashboardStats.fromJson(statsJson),
      latestNotification: json['latestNotification'] as Map<String, dynamic>?,
      recentApplications: json['recentApplications'] as List<dynamic>? ?? [],
      recentDocuments: json['recentDocuments'] as List<dynamic>? ?? [],
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

  String get _token {
    final token = AuthSession.instance.token;
    if (token == null) {
      throw ApiException(401, 'لا توجد جلسة دخول نشطة');
    }
    return token;
  }

  static const _overviewCacheKey = 'sb_overview_cache';
  static const _appsCacheKey = 'sb_apps_cache';
  static const _docsCacheKey = 'sb_docs_cache';
  static const _financialsCacheKey = 'sb_financials_cache';

  Future<DashboardOverview> getOverview({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_overviewCacheKey);
        if (cached != null) {
          final map = jsonDecode(cached) as Map<String, dynamic>;
          // Try fresh in background; return cache immediately
          _fetchAndCacheOverview().ignore();
          return DashboardOverview.fromJson(map);
        }
      } catch (_) {}
    }
    return _fetchAndCacheOverview();
  }

  Future<DashboardOverview> _fetchAndCacheOverview() async {
    final data =
        await ApiClient.instance.get('/students/overview', token: _token);
    final map = data as Map<String, dynamic>;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_overviewCacheKey, jsonEncode(map));
    } catch (_) {}
    return DashboardOverview.fromJson(map);
  }

  Future<List<dynamic>> _cachedList(String path, String cacheKey, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          _fetchAndCacheList(path, cacheKey).ignore();
          return jsonDecode(cached) as List<dynamic>;
        }
      } catch (_) {}
    }
    return _fetchAndCacheList(path, cacheKey);
  }

  Future<List<dynamic>> _fetchAndCacheList(String path, String cacheKey) async {
    final data = await ApiClient.instance.get(path, token: _token) as List<dynamic>;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data));
    } catch (_) {}
    return data;
  }

  Future<Map<String, dynamic>> getFinancials({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_financialsCacheKey);
        if (cached != null) {
          _fetchAndCacheFinancials().ignore();
          return jsonDecode(cached) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return _fetchAndCacheFinancials();
  }

  Future<Map<String, dynamic>> _fetchAndCacheFinancials() async {
    final data = await ApiClient.instance.get('/students/financials', token: _token) as Map<String, dynamic>;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_financialsCacheKey, jsonEncode(data));
    } catch (_) {}
    return data;
  }

  Future<void> clearOverviewCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_overviewCacheKey);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final data =
        await ApiClient.instance.get('/students/profile', token: _token);
    return data as Map<String, dynamic>?;
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
      'gpa',
      'englishTest',
      'targetCountries',
      'intake',
      'bio',
      'address'
    ];
    await ApiClient.instance.put('/students/profile', token: _token, body: {
      for (final field in fields)
        if (profile.containsKey(field)) field: profile[field],
    });
  }

  Future<List<dynamic>> getApplications({bool forceRefresh = false}) async {
    return _cachedList('/students/applications', _appsCacheKey, forceRefresh: forceRefresh);
  }

  Future<List<dynamic>> getDocuments({bool forceRefresh = false}) async {
    return _cachedList('/students/documents', _docsCacheKey, forceRefresh: forceRefresh);
  }

  /// Uploads a document — matches POST /api/students/documents
  /// (Multer `upload.single("file")`, plus a `type` form field).
  Future<Map<String, dynamic>> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String type,
    // A new version of an existing document, or a certified translation of one.
    String? replaces,
    String? translationOf,
  }) async {
    final data = await ApiClient.instance.postMultipart(
      '/students/documents',
      fileBytes: fileBytes,
      fileName: fileName,
      fields: {
        if (type.isNotEmpty) 'type': type,
        if (replaces != null) 'replaces': replaces,
        if (translationOf != null) 'translationOf': translationOf,
      },
      token: _token,
    );
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getNotifications() async {
    final data =
        await ApiClient.instance.get('/students/notifications', token: _token);
    return data as List<dynamic>;
  }

  Future<void> markNotificationRead(String id) async {
    await ApiClient.instance
        .patch('/students/notifications/$id/read', token: _token);
  }

  /// Real endpoint covering flight + airport pickup + housing + visa/residence
  /// support in ONE consolidated request (see ArrivalServiceRequest.js).
  /// Returns null if the student hasn't submitted one yet.
  Future<Map<String, dynamic>?> getArrivalServices() async {
    final data = await ApiClient.instance
        .get('/students/arrival-services', token: _token);
    return data as Map<String, dynamic>?;
  }

  /// Throws ApiException(400, ...) if the student hasn't reached
  /// final-accepted / travel-and-settlement yet — the backend enforces this.
  Future<Map<String, dynamic>> upsertArrivalServices({
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
    final data = await ApiClient.instance
        .put('/students/arrival-services', token: _token, body: {
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
    });
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSupportTickets() async {
    final data = await ApiClient.instance
        .get('/students/support-tickets', token: _token);
    return data as List<dynamic>;
  }

  /// Categories accepted by the backend (STUDENT_SUPPORT_CATEGORIES in
  /// studentController.js) — free text is rejected with a 400.
  static const List<Map<String, String>> supportCategories = [
    {'key': 'documents', 'label': 'المستندات'},
    {'key': 'application-status', 'label': 'حالة الطلب'},
    {'key': 'payment', 'label': 'الدفعات'},
    {'key': 'arrival-services', 'label': 'خدمات الوصول'},
    {'key': 'other', 'label': 'أخرى'},
  ];

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
      return data as Map<String, dynamic>;
    }
    final data = await ApiClient.instance
        .post('/students/support-tickets', token: _token, body: {
      'subject': subject,
      'message': message,
      'category': category,
    });
    return data as Map<String, dynamic>;
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
    return data as Map<String, dynamic>;
  }

  // ---- Favorites ----------------------------------------------------------

  Future<List<dynamic>> getFavorites() async {
    final data =
        await ApiClient.instance.get('/students/favorites', token: _token);
    return data as List<dynamic>;
  }

  /// Toggles a favorite on/off. Returns the raw response — either the
  /// created favorite doc, or `{removed: true, id: ...}` if it was already
  /// favorited (the backend toggles, per toggleStudentFavorite).
  Future<Map<String, dynamic>> toggleFavorite(
      {required String itemType,
      String? universityId,
      String? programId}) async {
    final data = await ApiClient.instance
        .post('/students/favorites/toggle', token: _token, body: {
      'itemType': itemType,
      if (universityId != null) 'universityId': universityId,
      if (programId != null) 'programId': programId,
    });
    return data as Map<String, dynamic>;
  }

  Future<void> removeFavorite(String id) async {
    await ApiClient.instance.delete('/students/favorites/$id', token: _token);
  }

  // ---- Knowledge Base -------------------------------------------------------

  Future<List<dynamic>> getKnowledgeBase() async {
    final data =
        await ApiClient.instance.get('/students/knowledge-base', token: _token);
    return data as List<dynamic>;
  }

  // ---- Orientation Test (a.k.a. "Program Finder") ----------------------------

  /// Returns null if the student hasn't taken the test yet.
  Future<Map<String, dynamic>?> getOrientationTestResult() async {
    final data = await ApiClient.instance
        .get('/students/orientation-test', token: _token);
    return data as Map<String, dynamic>?;
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
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getInsurance() async {
    final data = await ApiClient.instance
        .get('/students/insurance', token: _token);
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getEquivalency() async {
    final data = await ApiClient.instance
        .get('/students/equivalency', token: _token);
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }
}
