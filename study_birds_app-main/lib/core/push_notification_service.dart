import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Routes a notification tap to the correct screen name.
/// The server sends `screen` in the notification data to tell us where to go.
typedef PushTapHandler = void Function(String screen, Map<String, dynamic> data);

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  static const _appId = '06774f8d-4fc5-427e-b024-ae8fec0114eb';

  PushTapHandler? _tapHandler;
  bool _ready = false;
  Map<String, dynamic>? _pendingTap;

  /// Call once in main() before runApp.
  /// Does NOT prompt for permission — call [requestPermission] from within
  /// the app (after runApp) so the activity/window is already visible.
  Future<void> init() async {
    OneSignal.initialize(_appId);
    _ready = true;

    // Handle tap when app is in background / closed.
    OneSignal.Notifications.addClickListener((event) {
      final data = Map<String, dynamic>.from(
          event.notification.additionalData ?? {});
      final screen = data['screen']?.toString() ?? '';
      if (_tapHandler == null) { _pendingTap = data; }
      else { _tapHandler!(screen, data); }
    });

    // Foreground: display the system banner so the user sees it even while
    // the app is open. Without calling display() OneSignal 5.x suppresses it.
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });
  }

  /// Prompt the user for push-notification permission.
  /// Call this once from within the running app (e.g. initState of the root
  /// widget) so the OS dialog has an activity/window to attach to.
  Future<void> requestPermission() async {
    if (!_ready) return;
    await OneSignal.Notifications.requestPermission(true);
  }

  /// Link this device to the logged-in user.
  /// Call after every successful login.
  void setUser(String userId) {
    if (!_ready) return;
    OneSignal.login(userId);
  }

  /// Unlink device from user on logout.
  void clearUser() {
    if (!_ready) return;
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
