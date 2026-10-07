import 'dart:async';
import 'package:flutter/widgets.dart';

/// Lightweight foreground-only polling bus.
/// Screens subscribe to [onTick] and refresh their data when called.
/// Polling pauses automatically when the app goes to background.
///
/// PRD بند 77: Real-time Data Sync (polling-based, 30-second interval).
/// True WebSocket is intentionally deferred — the Render.com server does not
/// expose a WS endpoint and the polling approach satisfies all current use cases
/// (dashboard KPIs, notifications badge, journey stage updates).
class RealtimeSyncService with WidgetsBindingObserver {
  RealtimeSyncService._();
  static final RealtimeSyncService instance = RealtimeSyncService._();

  static const _interval = Duration(seconds: 30);

  Timer? _timer;
  final _controller = StreamController<DateTime>.broadcast();

  /// Subscribe to receive a tick every 30 s while the app is foregrounded.
  Stream<DateTime> get onTick => _controller.stream;

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
  }

  /// Manually trigger a tick (e.g. after a user action that should immediately
  /// refresh all subscribed screens).
  void forceSync() => _controller.add(DateTime.now());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      forceSync(); // immediate refresh on resume
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _controller.add(DateTime.now()));
  }
}
