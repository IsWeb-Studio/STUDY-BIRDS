import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';

/// Routes a notification tap to the correct screen name.
/// The server sends `screen` in the notification data to tell us where to go.
typedef PushTapHandler = void Function(
    String screen, Map<String, dynamic> data);

abstract class NotificationAccess {
  bool get supported;
  bool get permissionGranted;
  Future<void> init();
  Future<void> requestPermission();
  Future<void> enableForCurrentUser();
  Future<void> disableDelivery();
}

class PushNotificationService implements NotificationAccess {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  static const _appId = '06774f8d-4fc5-427e-b024-ae8fec0114eb';

  PushTapHandler? _tapHandler;
  bool _ready = false;
  Future<void>? _initializing;
  bool _deliveryAllowed = false;
  String? _userId;
  bool get deliveryAllowed => _deliveryAllowed;
  Map<String, dynamic>? _pendingTap;

  /// Call once in main() before runApp.
  /// Does NOT prompt for permission — call [requestPermission] from within
  /// the app (after runApp) so the activity/window is already visible.
  @override
  Future<void> init() {
    if (_ready || !supported) return Future.value();
    return _initializing ??= _initialize().catchError((Object error) {
      _initializing = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    await OneSignal.initialize(_appId);
    // Do not subscribe or link a new login until its permission gate completes.
    await OneSignal.User.pushSubscription.optOut();

    // Handle tap when app is in background / closed.
    OneSignal.Notifications.addClickListener((event) {
      final data =
          Map<String, dynamic>.from(event.notification.additionalData ?? {});
      final screen = data['screen']?.toString() ?? '';
      if (_tapHandler == null) {
        _pendingTap = data;
      } else {
        _tapHandler!(screen, data);
      }
    });

    // Foreground: display the system banner so the user sees it even while
    // the app is open. Without calling display() OneSignal 5.x suppresses it.
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();
      if (_deliveryAllowed) event.notification.display();
    });
    _ready = true;
  }

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// true if the OS has already granted push permission.
  @override
  bool get permissionGranted => _ready && OneSignal.Notifications.permission;

  /// Triggers the OS permission dialog.
  /// Show your own rationale first, then call this on user acceptance.
  @override
  Future<void> requestPermission() async {
    if (!_ready) return;
    final granted = await OneSignal.Notifications.requestPermission(true);
    if (granted) await enableForCurrentUser();
  }

  /// Link this device to the logged-in user.
  /// Call after every successful login.
  void setUser(String userId) {
    _userId = userId;
    _deliveryAllowed = false;
  }

  @override
  Future<void> enableForCurrentUser() async {
    if (!_ready || !permissionGranted) return;
    final id = _userId;
    if (id == null) return;
    await OneSignal.login(id);
    _deliveryAllowed = true;
    await OneSignal.User.pushSubscription.optIn();
  }

  @override
  Future<void> disableDelivery() async {
    _deliveryAllowed = false;
    if (_ready) await OneSignal.User.pushSubscription.optOut();
  }

  /// Unlink device from user on logout.
  void clearUser() {
    _userId = null;
    _deliveryAllowed = false;
    if (!_ready) return;
    OneSignal.User.pushSubscription.optOut();
    OneSignal.logout();
  }

  /// Register a handler that navigates when user taps a notification.
  /// Called from main.dart after the navigator key is ready.
  void setTapHandler(PushTapHandler handler) {
    _tapHandler = handler;
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) handler(pending['screen']?.toString() ?? '', pending);
  }
}
