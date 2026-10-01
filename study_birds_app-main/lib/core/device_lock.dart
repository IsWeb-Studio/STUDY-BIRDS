import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_session.dart';

class DeviceLock extends ChangeNotifier {
  DeviceLock._();
  static final instance = DeviceLock._();
  static const storage = FlutterSecureStorage();
  final auth = LocalAuthentication();
  bool enabled = false, ready = false, locked = false, authenticating = false;
  Future<void> load() async {
    enabled = await storage.read(key: 'device_lock_enabled') == 'true';
    locked = enabled;
    ready = true;
    notifyListeners();
  }

  Future<bool> unlock() async {
    if (authenticating) return false;
    authenticating = true;
    try {
      final success = await auth.authenticate(
          localizedReason: 'افتح حساب Study Birds باستخدام بصمتك أو رمز الجهاز',
          persistAcrossBackgrounding: true);
      if (success) {
        locked = false;
        notifyListeners();
      }
      return success;
    } finally {
      authenticating = false;
    }
  }

  Future<bool> setEnabled(bool value) async {
    if (!await auth.isDeviceSupported()) return false;
    if (!await unlock()) return false;
    await storage.write(
        key: 'device_lock_enabled', value: value ? 'true' : 'false');
    enabled = value;
    notifyListeners();
    return true;
  }

  Future<void> clear() async {
    await storage.delete(key: 'device_lock_enabled');
    enabled = false;
    locked = false;
    ready = true;
    notifyListeners();
  }

  void lock() {
    if (enabled && !authenticating) {
      locked = true;
      notifyListeners();
    }
  }
}

class DeviceLockGate extends StatefulWidget {
  final Widget child;
  const DeviceLockGate({super.key, required this.child});
  @override
  State<DeviceLockGate> createState() => _DeviceLockGateState();
}

class _DeviceLockGateState extends State<DeviceLockGate>
    with WidgetsBindingObserver {
  String? error;
  DateTime? _lastSessionCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeviceLock.instance.load().catchError((_) {
      if (mounted)
        setState(() =>
            error = 'تعذر قراءة إعدادات حماية الجهاز. أعد تشغيل التطبيق.');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // hidden covers iOS (app not visible in task switcher); paused covers Android.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      DeviceLock.instance.lock();
    } else if (state == AppLifecycleState.resumed) {
      _checkSessionInBackground();
    }
  }

  /// Silently validates the auth token when the app returns to foreground.
  /// Rate-limited to once every 5 minutes to avoid unnecessary network calls.
  /// A 401 from the server triggers the ApiClient refresh path, which will
  /// either renew the token silently or call AuthSession.logout().
  void _checkSessionInBackground() {
    final session = AuthSession.instance;
    if (!session.isRestored || session.currentUser == null) return;
    final token = session.token;
    if (token == null) return;
    final now = DateTime.now();
    if (_lastSessionCheck != null &&
        now.difference(_lastSessionCheck!) < const Duration(minutes: 5)) return;
    _lastSessionCheck = now;
    AuthService.instance.fetchCurrentUser(token).catchError((_) {});
  }

  Future<void> open() async {
    try {
      final success = await DeviceLock.instance.unlock();
      if (mounted)
        setState(
            () => error = success ? null : 'لم يتم فتح القفل. حاول مجددًا.');
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'تعذر التحقق. يمكنك إعادة المحاولة أو تسجيل الخروج.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: DeviceLock.instance,
      builder: (context, _) {
        final lock = DeviceLock.instance;
        return Stack(children: [
          widget.child,
          if ((lock.ready && lock.locked) || error != null)
            Positioned.fill(
                child: Material(
                    color: const Color(0xfff8fafc),
                    child: SafeArea(
                        child: Center(
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_outline, size: 52),
                                      const SizedBox(height: 20),
                                      const Text('حسابك محمي',
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(fontSize: 24)),
                                      if (error != null)
                                        Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Text(error!,
                                                textDirection:
                                                    TextDirection.rtl)),
                                      if (!lock.ready && error == null)
                                        const CircularProgressIndicator()
                                      else ...[
                                        FilledButton(
                                            onPressed: () => open(),
                                            child: const Text(
                                                'فتح بالبصمة أو رمز الجهاز')),
                                        TextButton(
                                            onPressed: () async {
                                              await AuthSession.instance
                                                  .logout();
                                              await lock.clear();
                                              if (mounted)
                                                setState(() => error = null);
                                            },
                                            child: const Text(
                                                'تسجيل الخروج واستخدام كلمة المرور')),
                                      ]
                                    ]))))))
        ]);
      });
}

class DeviceLockSetting extends StatefulWidget {
  const DeviceLockSetting({super.key});
  @override
  State<DeviceLockSetting> createState() => _DeviceLockSettingState();
}

class _DeviceLockSettingState extends State<DeviceLockSetting> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: DeviceLock.instance,
      builder: (context, _) => SwitchListTile(
          title: const Text('قفل التطبيق بالبصمة'),
          subtitle: const Text('أو رمز الجهاز؛ يحمي الجلسة عند العودة للتطبيق'),
          value: DeviceLock.instance.enabled,
          onChanged: busy
              ? null
              : (value) async {
                  setState(() => busy = true);
                  try {
                    if (!await DeviceLock.instance.setEnabled(value) &&
                        context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'لم يتم تفعيل الحماية. تأكد من إعداد قفل الجهاز.')));
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('التحقق بالجهاز غير متاح')));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                }));
}
