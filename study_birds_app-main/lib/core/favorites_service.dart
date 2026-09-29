import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_session.dart';

/// Favorites — local-first with API sync.
/// Adapts to the server's FavoriteItem format:
///   GET /students/favorites → List of { itemType, university: {_id,...}, program: {_id,...} }
///   POST /students/favorites/toggle → { itemType, universityId|programId }
///                                   → { removed: true, id } | full FavoriteItem
class FavoritesService {
  FavoritesService._();
  static final instance = FavoritesService._();

  static const _keyUniversities = 'favs_universities';
  static const _keyPrograms = 'favs_programs';

  String? get _token => AuthSession.instance.token;

  // ── Local cache helpers ───────────────────────────────────────────────────

  Future<Set<String>> _localLoad(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key)?.toSet() ?? {};
  }

  Future<void> _localSave(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids.toList());
  }

  /// Parses the server's FavoriteItem list and updates local cache.
  Future<void> _cacheFromServerList(List<dynamic> list) async {
    final unis = <String>{};
    final progs = <String>{};
    for (final item in list.whereType<Map<String, dynamic>>()) {
      final type = item['itemType'] as String?;
      if (type == 'university') {
        final id = (item['university'] as Map<String, dynamic>?)?['_id']?.toString();
        if (id != null && id.isNotEmpty) unis.add(id);
      } else if (type == 'program') {
        final id = (item['program'] as Map<String, dynamic>?)?['_id']?.toString();
        if (id != null && id.isNotEmpty) progs.add(id);
      }
    }
    await _localSave(_keyUniversities, unis);
    await _localSave(_keyPrograms, progs);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<bool> isFavorite(String id, {required bool university}) async {
    final set = await _localLoad(university ? _keyUniversities : _keyPrograms);
    return set.contains(id);
  }

  /// Toggles favorite. Returns true if item is now a favorite, false if removed.
  Future<bool> toggle(String id, {required bool university}) async {
    final key = university ? _keyUniversities : _keyPrograms;
    final set = await _localLoad(key);
    final wasIn = set.contains(id);

    // Optimistic local update
    if (wasIn) { set.remove(id); } else { set.add(id); }
    await _localSave(key, set);

    // Background sync with server
    final token = _token;
    if (token != null) {
      try {
        final body = university
            ? {'itemType': 'university', 'universityId': id}
            : {'itemType': 'program', 'programId': id};
        final res = await ApiClient.instance.post(
          '/students/favorites/toggle',
          token: token,
          body: body,
        ) as Map<String, dynamic>;
        // { removed: true } means item was deleted → not a favorite
        // anything else means it was added → is a favorite
        return res['removed'] != true;
      } catch (_) {
        // Server error — local optimistic state stands
      }
    }
    return !wasIn;
  }

  Future<Set<String>> getAllUniversityIds() => _getAllIds(university: true);
  Future<Set<String>> getAllProgramIds() => _getAllIds(university: false);

  Future<Set<String>> _getAllIds({required bool university}) async {
    final token = _token;
    if (token != null) {
      try {
        final res = await ApiClient.instance.get('/students/favorites', token: token);
        final list = res as List<dynamic>;
        await _cacheFromServerList(list);
        final type = university ? 'university' : 'program';
        return list
            .whereType<Map<String, dynamic>>()
            .where((item) => item['itemType'] == type)
            .map((item) {
              final ref = item[type] as Map<String, dynamic>?;
              return ref?['_id']?.toString() ?? '';
            })
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (_) {
        // Fall through to local cache
      }
    }
    return _localLoad(university ? _keyUniversities : _keyPrograms);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUniversities);
    await prefs.remove(_keyPrograms);
  }
}
