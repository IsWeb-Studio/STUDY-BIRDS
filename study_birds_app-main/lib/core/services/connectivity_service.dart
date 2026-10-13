import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../network/api_client.dart';

/// What the app can actually do right now — not just which radio is on.
enum NetworkStatus {
  /// The backend answered recently.
  online,

  /// No network interface at all (airplane mode, Wi-Fi off, no data).
  offline,

  /// An interface is up (e.g. captive-portal Wi-Fi) but the backend cannot be
  /// reached: no real internet, DNS failure, or the server itself is down.
  unreachable,
}

/// Single source of truth for connectivity.
///
/// Design notes:
/// * A connected interface is never trusted on its own; going back "online"
///   requires a successful backend probe (or a successful real API call).
/// * "Offline" is debounced so a Wi-Fi <-> mobile hand-over does not flash a
///   banner, and a failed probe must repeat before we report `unreachable`.
/// * While online nothing is polled. Probes run only on interface changes,
///   app resume (after a long pause), and after a real request failed.
/// * While not online, recovery probes use exponential backoff + jitter and
///   stop while the app is in the background.
/// * Requests are never blocked by this status (it may be wrong); it only
///   drives UI and automatic refresh after recovery.
class ConnectivityService extends ChangeNotifier with WidgetsBindingObserver {
  ConnectivityService({
    Stream<List<ConnectivityResult>> Function()? changes,
    Future<List<ConnectivityResult>> Function()? check,
    Future<bool> Function()? probe,
    this.offlineDebounce = const Duration(seconds: 2),
    this.confirmDelay = const Duration(milliseconds: 1500),
    this.minRecoveryDelay = const Duration(seconds: 3),
    this.maxRecoveryDelay = const Duration(seconds: 30),
    this.resumeProbeAfter = const Duration(seconds: 30),
    Random? random,
  })  : _changes = changes ?? (() => Connectivity().onConnectivityChanged),
        _check = check ?? (() => Connectivity().checkConnectivity()),
        _probe = probe ?? _defaultProbe,
        _random = random ?? Random();

  /// Replaceable only so tests can inject a fake radio/probe.
  static ConnectivityService instance = ConnectivityService();

  final Stream<List<ConnectivityResult>> Function() _changes;
  final Future<List<ConnectivityResult>> Function() _check;
  final Future<bool> Function() _probe;
  final Random _random;

  final Duration offlineDebounce;
  final Duration confirmDelay;
  final Duration minRecoveryDelay;
  final Duration maxRecoveryDelay;
  final Duration resumeProbeAfter;

  NetworkStatus _status = NetworkStatus.online;
  bool _started = false;
  bool _foreground = true;
  bool _hasInterface = true;
  bool _disposed = false;
  DateTime? _pausedAt;
  DateTime? _lastVerifyAt;
  int _recoveryAttempt = 0;
  Future<void>? _verifying;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _offlineTimer;
  Timer? _recoveryTimer;
  final _transitions = <DateTime>[];
  final _reconnected = StreamController<void>.broadcast();

  NetworkStatus get status => _status;
  bool get isOnline => _status == NetworkStatus.online;

  /// True when the link flapped several times in a short window.
  bool get isUnstable {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 30));
    return _transitions.where((t) => t.isAfter(cutoff)).length >= 4;
  }

  /// Fires once each time the app goes from not-online to verified online.
  Stream<void> get onReconnected => _reconnected.stream;

  /// Begin monitoring. Safe to call more than once.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      _sub = _changes().listen(_onInterfaces, onError: (_) {});
    } catch (_) {
      // Platform channel unavailable (tests / unsupported platform).
    }
    try {
      _onInterfaces(await _check());
    } catch (_) {}
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _sub = null;
    _offlineTimer?.cancel();
    _recoveryTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _reconnected.close();
    super.dispose();
  }

  // --- Inputs -------------------------------------------------------------

  /// A real API call succeeded: this is the strongest evidence of being online.
  void reportSuccess() {
    if (!_started || _status == NetworkStatus.online) return;
    _hasInterface = true;
    _offlineTimer?.cancel();
    _set(NetworkStatus.online);
  }

  /// A real API call failed at the transport level. Verify before blaming the
  /// network, at most once at a time.
  void reportFailure() {
    if (!_started || _status != NetworkStatus.online) return;
    final last = _lastVerifyAt;
    if (last != null && DateTime.now().difference(last) < confirmDelay) return;
    unawaited(_verify());
  }

  /// User pressed "Try again": verify now and report the result.
  Future<bool> checkNow() async {
    try {
      _onInterfacesSilently(await _check());
    } catch (_) {}
    if (!_hasInterface) {
      _set(NetworkStatus.offline);
      return false;
    }
    await _verify(force: true);
    return isOnline;
  }

  void _onInterfacesSilently(List<ConnectivityResult> r) {
    _hasInterface = r.any((e) => e != ConnectivityResult.none);
  }

  void _onInterfaces(List<ConnectivityResult> results) {
    if (_disposed) return;
    _onInterfacesSilently(results);
    if (!_hasInterface) {
      // Debounce: Wi-Fi <-> mobile hand-over briefly reports `none`.
      _offlineTimer?.cancel();
      _offlineTimer = Timer(offlineDebounce, _confirmOffline);
      return;
    }
    _offlineTimer?.cancel();
    // Interface changed or came back: verify real reachability.
    unawaited(_verify(force: true));
  }

  Future<void> _confirmOffline() async {
    if (_disposed) return;
    try {
      _onInterfacesSilently(await _check());
    } catch (_) {}
    if (_hasInterface) {
      unawaited(_verify(force: true));
      return;
    }
    _set(NetworkStatus.offline);
    _scheduleRecovery();
  }

  // --- Verification -------------------------------------------------------

  Future<void> _verify({bool force = false}) {
    final running = _verifying;
    if (running != null) return running; // single-flight: no probe pile-up
    if (!force) {
      final last = _lastVerifyAt;
      if (last != null && DateTime.now().difference(last) < confirmDelay) {
        return Future.value();
      }
    }
    return _verifying = _doVerify().whenComplete(() => _verifying = null);
  }

  Future<void> _doVerify() async {
    var ok = await _safeProbe();
    if (!ok && !_disposed) {
      // A single failed probe is not enough to declare an outage.
      await Future<void>.delayed(confirmDelay);
      ok = await _safeProbe();
    }
    _lastVerifyAt = DateTime.now();
    if (_disposed) return;
    if (ok) {
      _recoveryAttempt = 0;
      _recoveryTimer?.cancel();
      _set(NetworkStatus.online);
    } else {
      _set(_hasInterface ? NetworkStatus.unreachable : NetworkStatus.offline);
      _scheduleRecovery();
    }
  }

  Future<bool> _safeProbe() async {
    try {
      return await _probe();
    } catch (_) {
      return false;
    }
  }

  void _scheduleRecovery() {
    _recoveryTimer?.cancel();
    if (_disposed || !_started || !_foreground || isOnline) return;
    final base = minRecoveryDelay.inMilliseconds * pow(2, _recoveryAttempt);
    final capped = min(base, maxRecoveryDelay.inMilliseconds.toDouble());
    // Jitter 50–100% so many devices do not retry in lock-step.
    final delay = Duration(milliseconds: (capped * (.5 + _random.nextDouble() / 2)).round());
    if (_recoveryAttempt < 10) _recoveryAttempt++;
    _recoveryTimer = Timer(delay, () async {
      if (_disposed || isOnline) return;
      try {
        _onInterfacesSilently(await _check());
      } catch (_) {}
      if (!_hasInterface) {
        _set(NetworkStatus.offline);
        _scheduleRecovery();
      } else {
        await _verify(force: true);
      }
    });
  }

  void _set(NetworkStatus next) {
    if (_disposed || next == _status) return;
    final previous = _status;
    _status = next;
    _transitions.add(DateTime.now());
    if (_transitions.length > 8) _transitions.removeAt(0);
    notifyListeners();
    if (previous != NetworkStatus.online && next == NetworkStatus.online) {
      if (!_reconnected.isClosed) _reconnected.add(null);
    }
  }

  // --- Lifecycle ----------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (!isOnline) {
        _recoveryAttempt = 0;
        unawaited(checkNow());
      } else if (away >= resumeProbeAfter) {
        unawaited(_verify(force: true));
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _pausedAt ??= DateTime.now();
      _recoveryTimer?.cancel(); // no background polling
    }
  }

  /// Any HTTP answer (even 404) proves DNS + TLS + server are reachable.
  static Future<bool> _defaultProbe() async {
    final client = http.Client();
    try {
      await client
          .head(Uri.parse(ApiClient.baseUrl))
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}
