import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'analytics_service.dart';
import 'push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'secure_data_cache.dart';
import 'notification_scheduler.dart';
import '../../app_shell.dart';
import '../../screens/roles/parent_dashboard_screen.dart';
import '../../screens/roles/agent_dashboard_screen.dart';
import '../../screens/roles/university_dashboard_screen.dart';
import '../../screens/roles/employee_dashboard_screen.dart';

/// Central role enum — the single source of truth for role names across the
/// app. Never compare against raw strings like 'Student'/'student' elsewhere;
/// always go through this enum to avoid the inconsistent-casing problem.
///
/// NOTE: these names are the app's own vocabulary (kept for UI/UX
/// continuity — "agent"/"employee" read better in-app than the backend's
/// internal "partner"/"admin"). The backend's real role strings are
/// different; see [UserRoleWire] below for the mapping both ways.
enum UserRole { student, parent, agent, university, employee, admin }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.student:
        return 'طالب';
      case UserRole.parent:
        return 'ولي أمر';
      case UserRole.agent:
        return 'وكيل';
      case UserRole.university:
        return 'جامعة';
      case UserRole.employee:
        return 'موظف';
      case UserRole.admin:
        return 'مدير النظام';
    }
  }

  /// Serialized form used for local persistence (SharedPreferences) — stable
  /// and explicit, independent of enum declaration order.
  String get key => name;

  static UserRole? fromKey(String? key) {
    for (final r in UserRole.values) {
      if (r.key == key) return r;
    }
    return null;
  }
}

/// Maps between the app's UserRole and the REAL role strings the backend
/// uses ("student" | "admin" | "partner" | "parent" | "university" — see
/// server/src/models/User.js). This is the ONLY place that mapping lives.
extension UserRoleWire on UserRole {
  String get wireValue {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.parent:
        return 'parent';
      case UserRole.agent:
        return 'partner';
      case UserRole.university:
        return 'university';
      case UserRole.employee:
        return 'employee';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole? fromWire(String? wire) {
    switch (wire) {
      case 'student':
        return UserRole.student;
      case 'parent':
        return UserRole.parent;
      case 'partner':
        return UserRole.agent;
      case 'university':
        return UserRole.university;
      case 'employee':
        return UserRole.employee;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }
}

/// The authenticated account, parsed directly from the backend's
/// `/api/auth/login`, `/api/auth/register`, and `/api/auth/me` responses.
/// The role and permissions ALWAYS come from here, never from whatever the
/// person tapped on the "Who Are You?" screen.
class AuthUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? employeeRole; // e.g. 'admission', 'finance', 'super_admin'
  final Set<String> permissions;
  final String? linkedUniversityId;
  final String? avatar;
  final String? verifiedPhone;
  final bool emailVerified;
  final String? authProvider;
  final bool hasPassword;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.employeeRole,
    this.permissions = const {},
    this.linkedUniversityId,
    this.avatar,
    this.verifiedPhone,
    this.emailVerified = false,
    this.authProvider,
    this.hasPassword = true,
  });

  /// Parses the `user` object exactly as returned by the backend's
  /// serializeUser() (see server/src/controllers/authController.js).
  factory AuthUser.fromGoogleJson(Map<String, dynamic> json) {
    // Older Google endpoints omit both provider and password status.
    // An unknown password status must keep the setup gate closed.
    return AuthUser.fromJson({
      ...json,
      'authProvider': json['authProvider'] ?? 'google',
      'hasPassword': json['hasPassword'] == true,
    });
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = UserRoleWire.fromWire(json['role'] as String?);
    if (role == null) {
      throw ApiException(
          0, 'Unknown role "${json['role']}" returned by server');
    }

    final rawPermissions = json['permissions'];
    final linked = json['linkedUniversity'];

    return AuthUser(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: role,
      employeeRole: json['employeeRole'] as String?,
      permissions: rawPermissions is List
          ? rawPermissions.map((e) => e.toString()).toSet()
          : const {},
      linkedUniversityId: linked is String
          ? linked
          : (linked is Map ? linked['_id'] as String? : null),
      avatar: json['avatar'] as String?,
      verifiedPhone: json['verifiedPhone'] as String?,
      emailVerified: json['emailVerified'] == true,
      authProvider: json['authProvider'] as String?,
      hasPassword: json['hasPassword'] is bool
          ? json['hasPassword'] as bool
          : json['authProvider'] != 'google',
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'email': email,
        'role': role.wireValue,
        if (employeeRole != null) 'employeeRole': employeeRole,
        'permissions': permissions.toList(),
        if (linkedUniversityId != null) 'linkedUniversity': linkedUniversityId,
        if (avatar != null) 'avatar': avatar,
        if (verifiedPhone != null) 'verifiedPhone': verifiedPhone,
        'emailVerified': emailVerified,
        'hasPassword': hasPassword,
        if (authProvider != null) 'authProvider': authProvider,
      };
}

/// Real backend authentication — talks to the Study Birds API on Render.
/// See server/src/routes/authRoutes.js for the exact endpoints.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<AuthUser> _restoredUser(Map<String, dynamic> json) async {
    if (json['hasPassword'] is! bool) {
      final cached = await const FlutterSecureStorage().read(key: 'cached_user');
      if (cached != null) {
        try {
          final saved = jsonDecode(cached)['user'] as Map<String, dynamic>;
          final id = json['_id'] ?? json['id'];
          if (id != null && id == (saved['_id'] ?? saved['id'])) {
            json = {
              ...json,
              if (saved['hasPassword'] is bool)
                'hasPassword': saved['hasPassword'],
              'authProvider': json['authProvider'] ?? saved['authProvider'],
            };
          }
        } on FormatException catch (_) {
          // Invalid cached JSON must not prevent server-authenticated restore.
        } on TypeError catch (_) {}
      }
    }
    return AuthUser.fromJson(json);
  }

  /// Returns the authenticated user on success, or null on bad credentials
  /// / any request failure. Callers that need the specific failure reason
  /// can call [loginOrThrow] instead.
  Future<AuthUser?> login(String email, String password) async {
    try {
      return (await loginOrThrow(email, password)).user;
    } catch (_) {
      return null;
    }
  }

  /// Same as [login] but throws [ApiException] with the backend's own
  /// message on failure (e.g. "Invalid credentials") instead of swallowing
  /// it — use this where the UI can show a specific error.
  Future<({AuthUser user, String token, String? refreshToken})> loginOrThrow(
      String email, String password,
      {String? twoFactorCode}) async {
    final data = await ApiClient.instance.post('/auth/login', body: {
      'email': email.trim(),
      'password': password,
      if (twoFactorCode != null) 'twoFactorCode': twoFactorCode,
    });
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;
    return (user: user, token: token, refreshToken: data['refreshToken'] as String?);
  }

  /// Public registration. Converts the app-side role key (e.g. 'agent') to
  /// the server wire value (e.g. 'partner') before posting.
  Future<({AuthUser user, String token, String? refreshToken})> register({
    required String name,
    required String email,
    required String password,
    String? role,
  }) async {
    // The app uses enum names ('agent', 'employee') but the server stores wire
    // values ('partner', 'admin'). Convert before posting.
    final wireRole = role != null
        ? (UserRoleX.fromKey(role)?.wireValue ?? role)
        : null;
    final data = await ApiClient.instance.post('/auth/register', body: {
      'name': name,
      'email': email.trim(),
      'password': password,
      if (wireRole != null) 'role': wireRole,
    });
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;
    return (user: user, token: token, refreshToken: data['refreshToken'] as String?);
  }

  /// Tries to get a fresh access token using the stored refresh token.
  /// Returns null if the refresh token is missing or invalid.
  Future<({AuthUser user, String token, String? refreshToken})?> tryRefresh(String refreshToken) async {
    try {
      final data = await ApiClient.instance.post('/auth/refresh', body: {'refreshToken': refreshToken});
      final user = await _restoredUser(data['user'] as Map<String, dynamic>);
      final token = data['token'] as String;
      final newRefresh = data['refreshToken'] as String?;
      return (user: user, token: token, refreshToken: newRefresh);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) return null;
      rethrow;
    }
  }

  /// Re-fetches the current user from a previously-stored token — used on
  /// app start to restore the session. Returns null if the token is
  /// invalid/expired, so the caller falls back to the login screen.
  Future<AuthUser?> fetchCurrentUser(String token) async {
    try {
      final data = await ApiClient.instance.get('/auth/me', token: token);
      return await _restoredUser(data['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) return null;
      rethrow;
    }
  }
}

/// Holds the current session in memory and persists the real JWT token, so
/// [ApiClient] calls elsewhere in the app can attach it and the session
/// survives app restarts. On restore, the token is re-validated against the
/// backend (`/api/auth/me`) rather than trusting any locally-cached role.
class AuthSession extends ChangeNotifier {
  AuthSession._() {
    ApiClient.instance.refreshSession = refreshAccessToken;
  }
  static final AuthSession instance = AuthSession._();

  AuthUser? currentUser;
  bool requiresGooglePasswordSetup = false;
  String? token;
  bool _restored = false;
  bool get isRestored => _restored;
  int _revision = 0;
  String? _previousToken;
  Future<String?>? _refreshing;

  Future<void> _cacheUser(AuthUser user) async {
    await const FlutterSecureStorage().write(key: 'cached_user', value: jsonEncode({
      'user': user.toJson(), 'savedAt': DateTime.now().toUtc().toIso8601String(),
    }));
  }

  Future<String?> refreshAccessToken(String failedToken) async {
    if (token != failedToken) return failedToken == _previousToken ? token : null;
    if (_refreshing != null) return _refreshing;
    final operation = _renew(failedToken);
    _refreshing = operation;
    try { return await operation; } finally { _refreshing = null; }
  }

  Future<String?> _renew(String failedToken) async {
    final revision = _revision;
    const storage = FlutterSecureStorage();
    final refresh = await storage.read(key: 'refresh_token');
    if (refresh == null) return null;
    try {
      final result = await AuthService.instance.tryRefresh(refresh);
      if (revision != _revision || token != failedToken) return null;
      if (result == null) {
        await logout(revoke: false);
        return null;
      }
      _previousToken = failedToken;
      token = result.token;
      currentUser = result.user;
      await storage.write(key: 'active_session_token', value: result.token);
      await _cacheUser(result.user);
      if (result.refreshToken != null) await storage.write(key: 'refresh_token', value: result.refreshToken);
      notifyListeners();
      return token;
    } catch (_) {
      // A transport failure must not erase a valid saved session.
      return null;
    }
  }

  Future<void> restore() async {
    if (_restored) return;
    final pendingGoogleSetup = await const FlutterSecureStorage()
        .read(key: 'google_password_setup_required') == 'true';
    if (pendingGoogleSetup) {
      // The email proof expires after ten minutes. A restored unfinished
      // setup must authenticate again rather than reopen an unusable form.
      await logout(revoke: false);
      _restored = true;
      notifyListeners();
      return;
    }
    requiresGooglePasswordSetup = false;
    final prefs = await SharedPreferences.getInstance();
    const storage = FlutterSecureStorage();
    var storedToken = await storage.read(key: 'active_session_token');
    final legacy = prefs.getString('session_token');
    if (storedToken == null && legacy != null) {
      await storage.write(key: 'active_session_token', value: legacy);
      storedToken = legacy;
    }
    await prefs.remove('session_token');

    if (storedToken != null) {
      try {
        final user = await AuthService.instance.fetchCurrentUser(storedToken);
        if (user != null) {
          currentUser = user;
          token = storedToken;
          await _cacheUser(user);
        } else {
          // Access token expired — try refresh token before giving up.
          final storedRefresh = await storage.read(key: 'refresh_token');
          if (storedRefresh != null) {
            final refreshed = await AuthService.instance.tryRefresh(storedRefresh);
            if (refreshed != null) {
              currentUser = refreshed.user;
              token = refreshed.token;
              await storage.write(key: 'active_session_token', value: refreshed.token);
              await _cacheUser(refreshed.user);
              if (refreshed.refreshToken != null) await storage.write(key: 'refresh_token', value: refreshed.refreshToken);
            } else {
              await storage.delete(key: 'active_session_token');
              await storage.delete(key: 'refresh_token');
              await storage.delete(key: 'cached_user');
            }
          } else {
            await storage.delete(key: 'active_session_token');
            await storage.delete(key: 'cached_user');
          }
        }
      } catch (error) {
        if (error is ApiException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          await storage.delete(key: 'active_session_token');
          await storage.delete(key: 'refresh_token');
          await storage.delete(key: 'cached_user');
          _restored = true;
          notifyListeners();
          return;
        }
        // Network or transport error — restore from cached user snapshot so
        // the app can work offline with stale data; the next successful request
        // will re-validate the token via the 401 refresh path.
        final cachedRaw = await storage.read(key: 'cached_user');
        if (cachedRaw != null) {
          try {
            final cached = jsonDecode(cachedRaw) as Map;
            final savedAt = DateTime.tryParse('${cached['savedAt']}');
            final age = savedAt == null ? null : DateTime.now().difference(savedAt);
            final user = AuthUser.fromJson(Map<String, dynamic>.from(cached['user'] as Map));
            // Staff permissions must be verified online before opening tools.
            // Parents (read-only view) are safe to restore offline like students.
            final offlineSafe = user.role == UserRole.student || user.role == UserRole.parent;
            if (offlineSafe && age != null && !age.isNegative && age < const Duration(days: 7)) {
              currentUser = user;
              token = storedToken;
            }
          } catch (_) {
            // A missing/old snapshot is not proof that saved credentials were revoked.
            await storage.delete(key: 'cached_user');
          }
        }
      }
    }

    if (currentUser != null && !currentUser!.hasPassword) {
      await logout(revoke: false);
    }
    final restoredUser = currentUser;
    if (restoredUser != null) {
      PushNotificationService.instance.setUser(restoredUser.id);
    }
    _restored = true;
    notifyListeners();
  }

  /// Instantly marks verifiedPhone on the current user without a network round-trip.
  void patchVerifiedPhone(String phone) {
    final u = currentUser;
    if (u == null) return;
    currentUser = AuthUser(
      id: u.id, name: u.name, email: u.email, role: u.role,
      employeeRole: u.employeeRole, permissions: u.permissions,
      linkedUniversityId: u.linkedUniversityId, avatar: u.avatar,
      verifiedPhone: phone, emailVerified: u.emailVerified,
      authProvider: u.authProvider, hasPassword: u.hasPassword,
    );
    notifyListeners();
    refreshCurrentUser();
  }

  void patchEmailVerified() {
    final u = currentUser;
    if (u == null) return;
    currentUser = AuthUser(
      id: u.id, name: u.name, email: u.email, role: u.role,
      employeeRole: u.employeeRole, permissions: u.permissions,
      linkedUniversityId: u.linkedUniversityId, avatar: u.avatar,
      verifiedPhone: u.verifiedPhone, emailVerified: true,
      authProvider: u.authProvider, hasPassword: u.hasPassword,
    );
    notifyListeners();
    refreshCurrentUser();
  }

  Future<void> patchHasPassword() async {
    await const FlutterSecureStorage().delete(key: 'google_password_setup_required');
    requiresGooglePasswordSetup = false;
    final u = currentUser;
    if (u == null) return;
    currentUser = AuthUser(
      id: u.id, name: u.name, email: u.email, role: u.role,
      employeeRole: u.employeeRole, permissions: u.permissions,
      linkedUniversityId: u.linkedUniversityId, avatar: u.avatar,
      verifiedPhone: u.verifiedPhone, emailVerified: u.emailVerified,
      authProvider: u.authProvider, hasPassword: true,
    );
    ApiClient.instance.clearCache();
    notifyListeners();
    await _cacheUser(currentUser!);
  }

  /// Fetches fresh user data from /auth/me and updates the session in-place.
  Future<void> refreshCurrentUser() async {
    final t = token;
    if (t == null) return;
    try {
      final user = await AuthService.instance.fetchCurrentUser(t);
      if (user != null) {
        currentUser = user;
        await _cacheUser(user);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> login(AuthUser user, {String? authToken, String? refreshToken, bool requireGooglePasswordSetup = false}) async {
    ApiClient.instance.clearCache();
    requiresGooglePasswordSetup = requireGooglePasswordSetup;
    await const FlutterSecureStorage().write(key: 'google_password_setup_required', value: requireGooglePasswordSetup.toString());
    _revision++;
    _previousToken = null;
    final prefs = await SharedPreferences.getInstance();
    final storage = const FlutterSecureStorage();
    if (authToken != null) {
      await storage.write(key: 'active_session_token', value: authToken);
    } else {
      await storage.delete(key: 'active_session_token');
    }
    if (refreshToken != null) {
      await storage.write(key: 'refresh_token', value: refreshToken);
    } else {
      await storage.delete(key: 'refresh_token');
    }
    await _cacheUser(user);
    await prefs.remove('session_token');
    currentUser = user;
    token = authToken;
    PushNotificationService.instance.setUser(user.id);
    AnalyticsService.instance.identify(user.id, traits: {'role': user.role.name, 'name': user.name});
    notifyListeners();
  }

  Future<void> logout({bool revoke = true}) async {
    requiresGooglePasswordSetup = false;
    await const FlutterSecureStorage().delete(key: 'google_password_setup_required');
    _revision++;
    _previousToken = null;
    final owner = currentUser?.id ?? '';
    currentUser = null;
    token = null;
    ApiClient.instance.clearCache();
    notifyListeners();
    const storage = FlutterSecureStorage();
    final refresh = await storage.read(key: 'refresh_token');
    if (revoke && refresh != null) {
      try { await ApiClient.instance.post('/auth/logout', body: {'refreshToken': refresh}); } catch (_) {}
    }
    await SecureDataCache.clear(owner);
    await NotificationScheduler.instance.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    for (final key in ['sb_overview_cache', 'sb_apps_cache', 'sb_docs_cache', 'sb_financials_cache']) {
      await prefs.remove(key);
    }
    await storage.delete(key: 'active_session_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'cached_user');
    PushNotificationService.instance.clearUser();
    AnalyticsService.instance.reset();
    notifyListeners();
  }
}

/// THE single centralized role→home mapping. Every login/registration/
/// session-restore path in the app must call this — never scatter
/// `if (role == ...) Navigator.push(...)` logic across multiple screens.
/// Each destination is wrapped in its own [RoleGuard] so that even if this
/// function is reached some other way (e.g. a future deep link), the guard
/// still re-validates against the REAL authenticated role.
Widget getHomeRouteForUser(AuthUser user) {
  switch (user.role) {
    case UserRole.student:
      return RoleGuard(
          requiredRole: UserRole.student, child: const StudentAppShell());
    case UserRole.parent:
      return RoleGuard(
          requiredRole: UserRole.parent, child: const ParentDashboardScreen());
    case UserRole.agent:
      return RoleGuard(
          requiredRole: UserRole.agent, child: const AgentDashboardScreen());
    case UserRole.university:
      return RoleGuard(
          requiredRole: UserRole.university,
          child: const UniversityDashboardScreen());
    case UserRole.employee:
      return RoleGuard(
          requiredRole: UserRole.employee,
          child: EmployeeDashboardScreen(user: user));
    case UserRole.admin:
      return RoleGuard(
          requiredRole: UserRole.admin,
          child: EmployeeDashboardScreen(user: user));
  }
}

String _employeeRoleLabel(String? employeeRole) {
  switch (employeeRole) {
    case 'educational_consultant':
      return 'مستشار تعليمي';
    case 'sales':
      return 'مبيعات (Sales)';
    case 'admission':
      return 'مسؤول قبول (Admission)';
    case 'admission_manager':
      return 'مدير قبول';
    case 'visa_officer':
      return 'مسؤول تأشيرات';
    case 'travel_coordinator':
      return 'منسق سفر';
    case 'accommodation_officer':
      return 'مسؤول سكن';
    case 'finance':
      return 'مالية (Finance)';
    case 'customer_support':
      return 'دعم فني (Customer Support)';
    case 'branch_manager':
      return 'مدير فرع';
    case 'operations':
      return 'عمليات';
    case 'marketing':
      return 'تسويق';
    case 'university_relations':
      return 'علاقات الجامعات';
    case 'agent_manager':
      return 'مدير الوكلاء';
    case 'content_manager':
      return 'مدير محتوى';
    case 'super_admin':
      return 'مدير النظام (Super Admin)';
    default:
      return 'موظف Study Birds (لم يُحدد دوره بعد)';
  }
}

/// Maps the string key from the "Who Are You?" screen to a [UserRole] for
/// comparison against the REAL authenticated role. This claimed value is
/// used only to decide whether to warn about a mismatch — it never grants
/// any permission by itself.
UserRole? claimedRoleFromKey(String key) {
  switch (key) {
    case 'student':
      return UserRole.student;
    case 'parent':
      return UserRole.parent;
    case 'agent':
      return UserRole.agent;
    case 'university':
      return UserRole.university;
    case 'employee':
      return UserRole.employee;
    default:
      return null;
  }
}

/// Route guard: wrap any role-specific screen with this. If the currently
/// authenticated user's REAL role doesn't match, the screen never renders —
/// an Access Denied screen shows instead. This protects against direct
/// navigation/deep-links bypassing the login flow, independent of whatever
/// was selected on the "Who Are You?" screen.
class RoleGuard extends StatelessWidget {
  final UserRole requiredRole;
  final Widget child;
  final String? requiredPermission;

  const RoleGuard(
      {super.key,
      required this.requiredRole,
      required this.child,
      this.requiredPermission});

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    final roleOk = user != null && user.role == requiredRole;
    final permissionOk = requiredPermission == null ||
        user == null ||
        user.permissions.contains('*') ||
        user.permissions.contains(requiredPermission);

    if (!roleOk || !permissionOk) {
      return const AccessDeniedScreen();
    }
    return child;
  }
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block_rounded,
                    size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text('غير مصرح لك بالوصول لهذه الصفحة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('هذا القسم مخصص لنوع حساب مختلف عن حسابك الحالي.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('الرجوع للبداية'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
