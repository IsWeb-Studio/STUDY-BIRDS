import 'dart:async';
import 'package:flutter/widgets.dart';

import 'connectivity_service.dart';

/// Lightweight foreground-only polling bus.
/// Screens subscribe to [onTick] and refresh their data when called.
/// Polling pauses automatically when the app goes to background.
///
/// Foreground data sync polls every thirty seconds.
/// True WebSocket is intentionally deferred — the Render.com server does not
/// expose a WS endpoint and the polling approach satisfies all current use cases
/// (dashboard KPIs, notifications badge, journey stage updates).
class RealtimeSyncService with WidgetsBindingObserver {
  RealtimeSyncService._() : _clock = DateTime.now;
  RealtimeSyncService.forTesting({required DateTime Function() clock})
      : _clock = clock;
  final DateTime Function() _clock;
  DateTime? _lastSync;
  bool _backgrounded = false;
  static final RealtimeSyncService instance = RealtimeSyncService._();

  static const _interval = Duration(seconds: 30);

  Timer? _timer;
  final _controller = StreamController<DateTime>.broadcast();

  /// Subscribe to receive a tick every thirty seconds while foregrounded.
  Stream<DateTime> get onTick => _controller.stream;

  StreamSubscription<void>? _reconnectSub;

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _lastSync = _clock();
    WidgetsBinding.instance.addObserver(this);
    // Refresh subscribed screens once when verified connectivity returns.
    _reconnectSub =
        ConnectivityService.instance.onReconnected.listen((_) => forceSync());
    _startTimer();
  }

  void stop() {
    _reconnectSub?.cancel();
    _reconnectSub = null;
    _timer?.cancel();
    _timer = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
  }

  /// Manually trigger a tick (e.g. after a user action that should immediately
  /// refresh all subscribed screens).
  void forceSync() {
    _lastSync = _clock();
    _controller.add(DateTime.now());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      if (_backgrounded &&
          (_lastSync == null ||
              _clock().difference(_lastSync!) >= const Duration(seconds: 15))) {
        forceSync();
      }
      _backgrounded = false;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (state != AppLifecycleState.inactive) _backgrounded = true;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    if (!_started) return;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      // No point polling a network that is known to be down; the
      // reconnect hook below refreshes everything once it is back.
      if (ConnectivityService.instance.status == NetworkStatus.online) {
        forceSync();
      }
    });
  }
}
