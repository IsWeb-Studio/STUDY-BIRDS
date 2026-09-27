import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'auth_session.dart';
import 'notification_links.dart';
import '../screens/home_journey/notifications_screen.dart';

class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();
  final _appLinks = AppLinks();
  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<Uri>? _subscription;
  String? _pending;
  bool _initialized = false;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;
    AuthSession.instance.addListener(_flush);
    _subscription = _appLinks.uriLinkStream.listen(
        (uri) => open(uri.toString()), onError: (_) {});
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) open(uri.toString());
    } catch (_) {}
  }

  void open(String link) {
    _pending = notificationPath(link);
    _flush();
  }

  void _flush() {
    if (_pending == null || AuthSession.instance.currentUser == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pending == null) return;
      final user = AuthSession.instance.currentUser;
      if (user == null) return;
      if (user.role != UserRole.student) { _pending = null; return; }
      final navigator = _navigatorKey?.currentState;
      if (navigator == null) return;
      final screen = notificationScreenForLink(_pending);
      _pending = null;
      if (screen != null) navigator.push(MaterialPageRoute(builder: (_) => screen));
    });
  }

  void dispose() {
    _subscription?.cancel();
    AuthSession.instance.removeListener(_flush);
    _pending = null;
    _initialized = false;
  }
}
