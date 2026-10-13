import '../network/api_client.dart';
import 'app_error.dart';

/// Defensive access to server JSON.
///
/// A direct `data['user'] as Map<String, dynamic>` throws a `TypeError` as soon
/// as the server changes a field or returns an unexpected shape. These helpers
/// turn that into a normal [ApiException] (502, "service unavailable"), which
/// the UI already knows how to present and which is reported once to Sentry,
/// instead of an opaque crash deep inside a screen.
class JsonSafe {
  JsonSafe._();

  static ApiException _bad() => const ApiException(502, AppError.unavailable);

  /// `data[field]` as a JSON object; throws [ApiException] when missing/wrong.
  static Map<String, dynamic> object(dynamic data, String field) {
    final value = data is Map ? data[field] : null;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw _bad();
  }

  /// `data[field]` as a non-empty string; throws [ApiException] otherwise.
  static String string(dynamic data, String field) {
    final value = data is Map ? data[field] : null;
    if (value is String && value.isNotEmpty) return value;
    throw _bad();
  }

  /// A string when the value is a string, otherwise null (never throws).
  static String? optString(dynamic value) => value is String ? value : null;

  /// A list when the value is a list, otherwise an empty list.
  static List<dynamic> list(dynamic value) => value is List ? value : const [];
}
