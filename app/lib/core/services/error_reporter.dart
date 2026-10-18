import 'dart:async';
import 'dart:io' show IOException;

import 'package:sentry_flutter/sentry_flutter.dart';

import '../utils/app_error.dart';

/// One place that decides what is worth sending to Sentry.
///
/// Replaces the `catch (_) {}` pattern: the code may still continue (fallback,
/// ignore), but the failure is no longer invisible.
///
/// Rules:
///  * Expected conditions are NOT reported (no network, timeouts, 4xx the user
///    caused such as wrong password / validation / 401 / 404 / 409 / 429).
///  * Unexpected errors (bugs, TypeError from a changed response, 5xx) are.
///  * Every event is de-duplicated and rate-limited, so one broken screen
///    cannot flood the quota.
///  * Text is redacted before leaving the device; only an opaque user id is
///    attached (never e-mail, name or tokens).
class ErrorReporter {
  ErrorReporter._();

  /// Replaced in tests.
  static void Function(Object error, StackTrace? stack, String where,
      Map<String, Object?> extra)? sink;

  static final _lastSent = <String, DateTime>{};
  static final _window = <DateTime>[];
  static const _perKeyCooldown = Duration(minutes: 1);
  static const _maxPerMinute = 30;

  /// Called from catch blocks that intentionally continue.
  static void swallowed(Object error, StackTrace? stack, String where) {
    if (!_shouldReport(error)) return;
    _send(error, stack, where, const {});
  }

  /// For `.catchError(...)` that only needs to be reported.
  static void Function(Object, StackTrace) silent(String where) =>
      (Object error, StackTrace stack) => swallowed(error, stack, where);

  /// For `.catchError(...)`: report, then yield [value] so callers keep a fallback.
  static T Function(Object, StackTrace) fallback<T>(String where, T value) =>
      (Object error, StackTrace stack) {
        swallowed(error, stack, where);
        return value;
      };

  /// A server-side failure (5xx) or an unparseable response.
  static void apiFailure(String method, String path, int status,
      {Object? error}) {
    final route = normalizePath(path);
    addBreadcrumb('api', '$method $route -> $status');
    if (status < 500) return;
    _send(error ?? StateError('HTTP $status'), null, 'api $method $route',
        {'status': status, 'route': route});
  }

  /// Non-fatal trail that is attached to the next real event.
  static void addBreadcrumb(String category, String message) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(
          category: category,
          message: AppError.redact(message),
          level: SentryLevel.info));
    } catch (_) {
      // Monitoring must never break the app.
    }
  }

  /// Opaque account id + role only. No e-mail, no name.
  static void setUser(String? id, {String? role}) {
    try {
      Sentry.configureScope((scope) {
        scope.setUser(id == null ? null : SentryUser(id: id, data: {'role': role}));
      });
    } catch (_) {}
  }

  /// `/applications/64f0c0ffee…/documents/12` -> `/applications/:id/documents/:n`
  static String normalizePath(String path) => path
      .split('?')
      .first
      .replaceAll(RegExp(r'[0-9a-fA-F]{24}'), ':id')
      .replaceAll(RegExp(r'/\d+'), '/:n');

  /// Pure policy, exposed for tests.
  static bool isExpected(Object error) {
    if (error is TimeoutException || error is IOException) return true;
    if (AppError.isConnectivity(error)) return true;
    if (error is UserFacingFailure) {
      // ApiException: user-caused / transient statuses are not bugs.
      final text = error.toString();
      final status = _statusOf(error);
      if (status != null) {
        return status == 0 ||
            status == 408 ||
            (status >= 400 && status < 500 && status != 422);
      }
      return text == AppError.connection;
    }
    return false;
  }

  static int? _statusOf(Object error) {
    try {
      final dynamic e = error;
      final status = e.statusCode;
      return status is int ? status : null;
    } catch (_) {
      return null;
    }
  }

  static bool _shouldReport(Object error) => !isExpected(error);

  static void _send(Object error, StackTrace? stack, String where,
      Map<String, Object?> extra) {
    if (error is FormatException) {
      error = const FormatException('Invalid data format');
    }
    final now = DateTime.now();
    _window.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_window.length >= _maxPerMinute) return;
    final key = '$where|${error.runtimeType}';
    final last = _lastSent[key];
    if (last != null && now.difference(last) < _perKeyCooldown) return;
    _lastSent[key] = now;
    _window.add(now);
    try {
      final custom = sink;
      if (custom != null) {
        custom(error, stack, where, extra);
        return;
      }
      if (!Sentry.isEnabled) return;
      unawaited(Sentry.captureException(error,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('where', where);
            extra.forEach((k, v) => scope.setContexts(k, {'value': v}));
          }));
    } catch (_) {
      // Monitoring must never break the app.
    }
  }

  /// Test helper.
  static void resetForTest() {
    _lastSent.clear();
    _window.clear();
    sink = null;
  }
}
