import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/notification_scheduler.dart';
import 'notification_permission_sheet.dart';

/// Only mounted after authentication, before constructing the dashboard.
class LoginNotificationGate extends StatefulWidget {
  final WidgetBuilder homeBuilder;
  final NotificationAccess? access;
  const LoginNotificationGate(
      {super.key, required this.homeBuilder, this.access});
  @override
  State<LoginNotificationGate> createState() => _LoginNotificationGateState();
}

class _LoginNotificationGateState extends State<LoginNotificationGate>
    with WidgetsBindingObserver {
  bool _checking = true, _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _check();
  }

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final push = widget.access ?? PushNotificationService.instance;
      await push.init().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      var allowed = !push.supported || push.permissionGranted;
      final prefs = await SharedPreferences.getInstance();
      if (!allowed && prefs.getBool('_notif_sheet_shown') != true) {
        await prefs.setBool('_notif_sheet_shown', true);
        if (!mounted) return;
        final accept = await showModalBottomSheet<bool>(
          context: context,
          isDismissible: true,
          enableDrag: true,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const NotificationPermissionSheet(),
        );
        if (accept == true) await push.requestPermission();
        allowed = push.permissionGranted;
      }
      if (allowed) {
        await push.enableForCurrentUser().timeout(const Duration(seconds: 8));
      } else {
        await push.disableDelivery().timeout(const Duration(seconds: 3));
        await NotificationScheduler.instance
            .cancelAll()
            .timeout(const Duration(seconds: 3));
      }
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    } catch (_) {
      try {
        await (widget.access ?? PushNotificationService.instance)
            .disableDelivery()
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Notification SDK failure must not block account access. */
      }
      try {
        await NotificationScheduler.instance
            .cancelAll()
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Keep account access available if the local plugin fails. */
      }
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.homeBuilder(context);
  }
}
