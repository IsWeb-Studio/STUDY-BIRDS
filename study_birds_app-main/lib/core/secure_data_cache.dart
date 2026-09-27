import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account-scoped encrypted snapshots. No credentials or cached permissions
/// are used to authorize a server operation.
class SecureDataCache {
  static const _storage = FlutterSecureStorage();
  static const _prefix = 'student_snapshot_v1:';
  static String _key(String owner, String resource) =>
      '$_prefix${Uri.encodeComponent(owner)}:${Uri.encodeComponent(resource)}';

  static Future<void> write(String owner, String resource, Object value) async {
    if (owner.isEmpty) return;
    await _storage.write(key: _key(owner, resource), value: jsonEncode({
      'savedAt': DateTime.now().toUtc().toIso8601String(), 'data': value,
    }));
  }

  static Future<dynamic> read(String owner, String resource) async {
    if (owner.isEmpty) return null;
    final raw = await _storage.read(key: _key(owner, resource));
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map;
    final savedAt = DateTime.tryParse('${value['savedAt']}');
    if (savedAt == null || DateTime.now().difference(savedAt).inDays >= 7) return null;
    return value['data'];
  }

  static Future<void> clear(String owner) async {
    for (final resource in ['overview', 'applications', 'documents', 'financials']) {
      await _storage.delete(key: _key(owner, resource));
    }
  }
}
