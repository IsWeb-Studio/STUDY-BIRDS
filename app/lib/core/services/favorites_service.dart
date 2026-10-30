import '../utils/json_safe.dart';
import 'error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
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

  String _scoped(String key) =>
      '$key:${AuthSession.instance.currentUser?.id ?? 'guest'}';

  String? get _token => AuthSession.instance.token;

  // ── Local cache helpers ───────────────────────────────────────────────────

  Future<Set<String>> _localLoad(String key) async {
    final scoped = _scoped(key);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(scoped)?.toSet() ?? {};
  }

  Future<void> _localSave(String key, Set<String> ids) async {
    final scoped = _scoped(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(scoped, ids.toList());
  }

  /// Parses the server's FavoriteItem list and updates local cache.
  Future<void> _cacheFromServerList(List<dynamic> list) async {
    final unis = <String>{};
    final progs = <String>{};
    for (final item in list.whereType<Map<String, dynamic>>()) {
      final type = item['itemType'] as String?;
      if (type == 'university') {
        final id = (Json.mapOrNull(item['university']))?['_id']?.toString();
        if (id != null && id.isNotEmpty) unis.add(id);
      } else if (type == 'program') {
        final id = (Json.mapOrNull(item['program']))?['_id']?.toString();
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
    final owner = AuthSession.instance.currentUser?.id;

    // Optimistic local update
    if (wasIn) {
      set.remove(id);
    } else {
      set.add(id);
    }
    await _localSave(key, set);

    // Background sync with server
    final token = _token;
    if (token != null) {
      try {
        final body = university
            ? {'itemType': 'university', 'universityId': id}
            : {'itemType': 'program', 'programId': id};
        final res = Json.map(await ApiClient.instance.post(
          '/students/favorites/toggle',
          token: token,
          body: body,
        ));
        // { removed: true } means item was deleted → not a favorite
        // anything else means it was added → is a favorite
        return res['removed'] != true;
      } catch (swallowedError, swallowedStack) {
        ErrorReporter.swallowed(swallowedError, swallowedStack,
            'core/services/favorites_service.dart:81');
        if (AuthSession.instance.currentUser?.id == owner) {
          if (wasIn) {
            set.add(id);
          } else {
            set.remove(id);
          }
          await _localSave(key, set);
        }
        rethrow;
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
        final res =
            await ApiClient.instance.get('/students/favorites', token: token);
        final list = Json.list(res);
        if (token != _token) return <String>{};
        await _cacheFromServerList(list);
        final type = university ? 'university' : 'program';
        return list
            .whereType<Map<String, dynamic>>()
            .where((item) => item['itemType'] == type)
            .map((item) {
              final ref = Json.mapOrNull(item[type]);
              return ref?['_id']?.toString() ?? '';
            })
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (swallowedError, swallowedStack) {
        ErrorReporter.swallowed(swallowedError, swallowedStack,
            'core/services/favorites_service.dart:108');
        // Fall through to local cache
      }
    }
    return _localLoad(university ? _keyUniversities : _keyPrograms);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scoped(_keyUniversities));
    await prefs.remove(_scoped(_keyPrograms));
  }
}
