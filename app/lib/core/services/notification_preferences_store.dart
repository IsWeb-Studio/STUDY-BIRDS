import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesStore {
  static const categories = [
    'payments',
    'admission',
    'documents',
    'consultations',
    'visa',
    'support',
    'announcements',
    'community'
  ];
  static Map<String, bool> defaults() =>
      {for (final key in categories) key: true};
  static String key(String owner, String category) =>
      'notif_pref_v2:${Uri.encodeComponent(owner)}:$category';

  static Future<Map<String, bool>> read(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    // Legacy unscoped keys cannot safely be attributed to this account.
    return {
      for (final category in categories)
        category: prefs.getBool(key(owner, category)) ?? true
    };
  }

  static Future<void> save(String owner, Map<String, bool> values) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in values.entries) {
      if (categories.contains(entry.key)) {
        await prefs.setBool(key(owner, entry.key), entry.value);
      }
    }
  }
}
