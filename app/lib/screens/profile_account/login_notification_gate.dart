import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/auth_session.dart';
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
  bool _checking = true, _allowed = false, _busy = false;

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

  Future<void> _check({bool retry = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      final push = widget.access ?? PushNotificationService.instance;
      await push.init();
      if (!mounted) return;
      var allowed = !push.supported || push.permissionGranted;
      final prefs = await SharedPreferences.getInstance();
      if (!allowed && (retry || prefs.getBool('_notif_sheet_shown') != true)) {
        await prefs.setBool('_notif_sheet_shown', true);
        if (!mounted) return;
        final accept = await showModalBottomSheet<bool>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const NotificationPermissionSheet(),
        );
        if (accept == true) await push.requestPermission();
        allowed = push.permissionGranted;
      }
      if (allowed) {
        await push.enableForCurrentUser();
      } else {
        await push.disableDelivery();
        await NotificationScheduler.instance.cancelAll();
      }
      if (mounted) {
        setState(() {
          _allowed = allowed;
          _checking = false;
        });
      }
    } catch (_) {
      await (widget.access ?? PushNotificationService.instance).disableDelivery();
      if (mounted) {
        setState(() {
          _allowed = false;
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
    if (_allowed) return widget.homeBuilder(context);
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.notifications_off_outlined, size: 56),
        const SizedBox(height: 20),
        const Text('فعّل الإشعارات للمتابعة إلى حسابك',
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
            'لم يتم تفعيل الإشعارات. يمكنك الموافقة الآن أو الرجوع لتسجيل الدخول.',
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: () => _check(retry: true),
            child: const Text('تفعيل الإشعارات والمتابعة')),
        TextButton(
            onPressed: () => AuthSession.instance.logout(),
            child: const Text('تسجيل الخروج')),
      ]),
    ))));
  }
}
