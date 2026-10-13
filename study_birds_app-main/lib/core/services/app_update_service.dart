import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/api_client.dart';
import '../utils/json_safe.dart';
import 'error_reporter.dart';

/// What the server asks of this installed version.
class UpdateRequirement {
  final String message;
  final String? storeUrl;
  const UpdateRequirement({required this.message, this.storeUrl});
}

/// Forced-update gate.
///
/// The server (`GET /mobile/app-config`) publishes the minimum version it still
/// supports per platform. If the installed version is older, the app shows a
/// blocking "please update" screen instead of failing in confusing ways against
/// an API it no longer understands.
///
/// Safe by design: any failure (offline, 404 on an older server, bad data)
/// means "no restriction" - this can never lock users out by accident.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService({Future<String> Function()? installedVersion})
      : _installedVersion = installedVersion ?? _packageVersion;

  static final AppUpdateService instance = AppUpdateService();

  static const defaultMessage =
      'يتوفر إصدار أحدث من التطبيق ولم يعد هذا الإصدار مدعومًا. حدّث التطبيق للمتابعة.';

  final Future<String> Function() _installedVersion;
  UpdateRequirement? _required;
  UpdateRequirement? get required => _required;

  static Future<String> _packageVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Fetches the config and updates [required]. Never throws.
  Future<void> check({TargetPlatform? platform}) async {
    try {
      final data = await ApiClient.instance.get('/mobile/app-config', cached: false);
      final installed = await _installedVersion();
      final next = evaluate(
        installed: installed,
        config: data,
        platform: platform ?? defaultTargetPlatform,
      );
      if (next?.message != _required?.message ||
          next?.storeUrl != _required?.storeUrl) {
        _required = next;
        notifyListeners();
      }
    } catch (error, stack) {
      // Offline or an older server without the endpoint: no restriction.
      ErrorReporter.swallowed(error, stack, 'app_update_service.check');
    }
  }

  /// Pure decision, exposed for tests.
  static UpdateRequirement? evaluate({
    required String installed,
    required dynamic config,
    required TargetPlatform platform,
  }) {
    if (config is! Map) return null;
    final key = switch (platform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    if (key == null) return null;
    final min = JsonSafe.optString(Json.map(config['minVersion'])[key]);
    if (min == null || min.trim().isEmpty) return null;
    if (compareVersions(installed, min) >= 0) return null;
    final message = JsonSafe.optString(config['message']);
    final url = JsonSafe.optString(Json.map(config['storeUrl'])[key]);
    return UpdateRequirement(
      message: (message == null || message.trim().isEmpty) ? defaultMessage : message,
      storeUrl: (url == null || url.trim().isEmpty) ? null : url,
    );
  }

  /// Compares dotted versions numerically ("1.10.0" > "1.9.9"); build metadata
  /// after '+' or a pre-release suffix after '-' is ignored. Unparseable
  /// parts count as 0, so garbage can never look "older" than a real minimum.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split(RegExp(r'[+-]'))
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final l = i < x.length ? x[i] : 0;
      final r = i < y.length ? y[i] : 0;
      if (l != r) return l < r ? -1 : 1;
    }
    return 0;
  }
}
