import '../network/api_client.dart';
import '../services/error_reporter.dart';
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

/// Drop-in, non-throwing replacements for `value as Map/List` casts on server
/// data. A wrong shape yields an empty container (or null for the `…OrNull`
/// forms) and is reported once, instead of crashing the screen with a
/// `TypeError`.
class Json {
  Json._();

  static void _report(Object? value, String expected) {
    // Imported lazily to keep this file dependency-light for pure-Dart tools.
    ErrorReporter.swallowed(
        TypeError(), StackTrace.current, 'json: expected $expected, got ${value.runtimeType}');
  }

  static Map<String, dynamic> map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    _report(value, 'Map');
    return <String, dynamic>{};
  }

  static Map<String, dynamic>? mapOrNull(Object? value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    _report(value, 'Map?');
    return null;
  }

  static Map<dynamic, dynamic> rawMap(Object? value) {
    if (value is Map) return value;
    _report(value, 'Map');
    return <dynamic, dynamic>{};
  }

  static Map<dynamic, dynamic>? rawMapOrNull(Object? value) {
    if (value == null) return null;
    if (value is Map) return value;
    _report(value, 'Map?');
    return null;
  }

  static List<dynamic> list(Object? value) {
    if (value is List) return value;
    _report(value, 'List');
    return <dynamic>[];
  }

  static List<dynamic>? listOrNull(Object? value) {
    if (value == null) return null;
    if (value is List) return value;
    _report(value, 'List?');
    return null;
  }
}
