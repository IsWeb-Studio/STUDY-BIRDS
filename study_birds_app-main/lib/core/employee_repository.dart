import 'api_client.dart';
import 'auth_session.dart';

/// Talks to the general admin endpoints in server/src/routes/adminRoutes.js.
/// IMPORTANT: the real backend has no concept of "tasks assigned to me" or
/// "students assigned to me" for an individual employee — "admin" is one
/// undifferentiated role that can see the whole platform. Every method here
/// is intentionally platform-wide, not personal, and the UI must label it
/// that way rather than pretending it's scoped to the logged-in employee.
class EmployeeRepository {
  EmployeeRepository._();
  static final EmployeeRepository instance = EmployeeRepository._();

  String get _token {
    final token = AuthSession.instance.token;
    if (token == null) throw ApiException(401, 'لا توجد جلسة دخول نشطة');
    return token;
  }

  Future<Map<String, dynamic>> getOverview() async {
    final data = await ApiClient.instance.get('/admin/overview', token: _token);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyKpis() async {
    final data = await ApiClient.instance.get('/admin/my-kpis', token: _token);
    return data as Map<String, dynamic>;
  }

  /// All students on the platform (not scoped to this employee — the
  /// backend has no per-employee assignment concept).
  Future<List<dynamic>> getAllStudents() async {
    final data = await ApiClient.instance.get('/admin/students', token: _token);
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getAllApplications() async {
    final data = await ApiClient.instance.get('/admin/applications', token: _token);
    return data as List<dynamic>;
  }

  // ---- Parent links (requires the 'parent-links' section) -----------------

  Future<List<dynamic>> getParentLinks() async {
    final data = await ApiClient.instance.get('/admin/parent-links', token: _token);
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateParentLinkStatus(String id, {required String status, String? adminNote}) async {
    final data = await ApiClient.instance.patch('/admin/parent-links/$id', token: _token, body: {
      'status': status,
      if (adminNote != null) 'adminNote': adminNote,
    });
    return data as Map<String, dynamic>;
  }

  // ---- University accounts (requires the 'university-accounts' section) --

  Future<List<dynamic>> getUniversityAccounts() async {
    final data = await ApiClient.instance.get('/admin/university-accounts', token: _token);
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createUniversityAccount({
    required String name,
    required String email,
    required String password,
    required String universityId,
  }) async {
    final data = await ApiClient.instance.post('/admin/university-accounts', token: _token, body: {
      'name': name,
      'email': email,
      'password': password,
      'universityId': universityId,
    });
    return data as Map<String, dynamic>;
  }

  // ---- General users & access (role="admin" only — matches the backend's
  // "User/employee management stays admin-only" rule) -----------------------

  Future<List<dynamic>> getAllUsers() async {
    final data = await ApiClient.instance.get('/admin/users', token: _token);
    return data as List<dynamic>;
  }

  /// Generic account update — role change, activation, linking a university,
  /// or (for role="employee") the granted section permissions. Mirrors the
  /// web's adminService.updateUser exactly (PATCH /api/admin/users/:id).
  Future<Map<String, dynamic>> updateUser(
    String id, {
    String? role,
    bool? isActive,
    String? linkedUniversity,
    List<String>? permissions,
  }) async {
    final data = await ApiClient.instance.patch('/admin/users/$id', token: _token, body: {
      if (role != null) 'role': role,
      if (isActive != null) 'isActive': isActive,
      if (linkedUniversity != null) 'linkedUniversity': linkedUniversity,
      if (permissions != null) 'permissions': permissions,
    });
    return data as Map<String, dynamic>;
  }
}
