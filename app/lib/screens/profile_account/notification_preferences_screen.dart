import '../../core/services/error_reporter.dart';
import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import '../../core/services/notification_preferences_store.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> with WidgetsBindingObserver {
  String? _owner;
  bool _sessionEnded = false;
  int _loadRevision = 0;
  bool _loadFailed = false;
  final _saving = <String>{};
  final _prefs = <String, bool>{};
  bool _loading = true;
  bool _requesting = false;

  static const _categories = [
    (
      'payments',
      'استحقاق الدفع',
      Icons.payment_rounded,
      'تذكير بموعد السداد قبل 6 ساعات'
    ),
    (
      'admission',
      'تحديثات القبول',
      Icons.school_rounded,
      'صدور قبول، تغيير حالة الطلب'
    ),
    (
      'documents',
      'طلبات المستندات',
      Icons.folder_rounded,
      'طلب رفع مستند، قرار مراجعة'
    ),
    (
      'consultations',
      'الاستشارات',
      Icons.calendar_today_rounded,
      'تذكير بموعد الاستشارة القادمة'
    ),
    (
      'visa',
      'التأشيرة والسفر',
      Icons.flight_takeoff_rounded,
      'تحديثات تتعلق بالتأشيرة وموعد السفر'
    ),
    (
      'support',
      'ردود الدعم',
      Icons.support_agent_rounded,
      'رد فريق الدعم على تذاكرك'
    ),
    (
      'announcements',
      'الإعلانات العامة',
      Icons.campaign_rounded,
      'أخبار وتحديثات COVEY'
    ),
    (
      'community',
      'المجتمع',
      Icons.forum_outlined,
      'تعليق أو إعجاب جديد على محتواك'
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _owner = AuthSession.instance.currentUser?.id;
    _sessionEnded = _owner == null || AuthSession.instance.token == null;
    AuthSession.instance.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  Future<void> _enableNotifications() async {
    setState(() => _requesting = true);
    try {
      await PushNotificationService.instance.requestPermission();
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/profile_account/notification_preferences_screen.dart:91');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar(
              content: const Text('تعذر تفعيل الإشعارات. حاول مجددًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  bool get _active =>
      mounted &&
      !_sessionEnded &&
      _owner != null &&
      AuthSession.instance.currentUser?.id == _owner &&
      AuthSession.instance.token != null;

  void _sessionChanged() {
    if (_sessionEnded ||
        (_owner == AuthSession.instance.currentUser?.id &&
            AuthSession.instance.token != null)) {
      return;
    }
    setState(() {
      _sessionEnded = true;
      _loadRevision++;
      _prefs.clear();
      _saving.clear();
    });
  }

  Future<void> _load() async {
    if (!_active || _saving.isNotEmpty) return;
    final revision = ++_loadRevision;
    final owner = _owner!;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    var cached = NotificationPreferencesStore.defaults();
    try {
      cached = await NotificationPreferencesStore.read(owner);
      if (!_active || revision != _loadRevision) return;
      _prefs.addAll(cached);
    } catch (error, stack) {
      ErrorReporter.swallowed(
          error, stack, 'notification-preferences.cache.read');
    }
    try {
      if (!_active || revision != _loadRevision) return;
      final remote = await ApiClient.instance.get(
          '/mobile-security/notification-preferences',
          token: AuthSession.instance.token,
          cached: false);
      if (!_active || revision != _loadRevision) return;
      // The first server read after deployment must preserve this account's
      // existing local preferences instead of replacing them with defaults.
      final synchronized = remote is Map && remote['_initialized'] == false
          ? await ApiClient.instance.put(
              '/mobile-security/notification-preferences',
              token: AuthSession.instance.token,
              body: cached)
          : remote;
      if (!_active || revision != _loadRevision) return;
      final values = _parse(synchronized);
      setState(() => _prefs.addAll(values));
      try {
        await NotificationPreferencesStore.save(owner, values);
        if (_active) {
          await PushNotificationService.instance.syncAnnouncementPreference();
        }
        for (final entry in values.entries) {
          if (!entry.value && _active && revision == _loadRevision) {
            await NotificationScheduler.instance
                .cancelCategory(entry.key, owner: owner);
          }
        }
      } catch (error, stack) {
        ErrorReporter.swallowed(
            error, stack, 'notification-preferences.cache.write');
      }
    } catch (error, stack) {
      ErrorReporter.swallowed(error, stack, 'notification-preferences.load');
      if (_active && revision == _loadRevision) {
        setState(() => _loadFailed = true);
      }
    } finally {
      if (_active && revision == _loadRevision) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, bool> _parse(dynamic data) {
    if (data is! Map ||
        NotificationPreferencesStore.categories
            .any((key) => data[key] is! bool)) {
      throw const FormatException('Invalid notification preferences');
    }
    return {
      for (final key in NotificationPreferencesStore.categories)
        key: data[key] as bool
    };
  }

  Future<void> _toggle(String key, bool value) async {
    if (!_active || _saving.contains(key)) return;
    final owner = _owner!;
    final previous = _prefs[key] ?? true;
    setState(() {
      _prefs[key] = value;
      _saving.add(key);
    });
    try {
      final remote = await ApiClient.instance.put(
          '/mobile-security/notification-preferences',
          token: AuthSession.instance.token,
          body: {key: value});
      if (!_active) return;
      final saved = _parse(remote)[key]!;
      setState(() => _prefs[key] = saved);
      try {
        await NotificationPreferencesStore.save(owner, {key: saved});
        if (key == 'announcements' && _active) {
          await PushNotificationService.instance.syncAnnouncementPreference();
        }
      } catch (error, stack) {
        ErrorReporter.swallowed(
            error, stack, 'notification-preferences.cache.write');
      }
      if (!saved && _active) {
        try {
          await NotificationScheduler.instance
              .cancelCategory(key, owner: owner);
        } catch (error, stack) {
          ErrorReporter.swallowed(
              error, stack, 'notification-preferences.cancel');
        }
      }
    } catch (error, stack) {
      ErrorReporter.swallowed(error, stack, 'notification-preferences.save');
      if (!mounted || !_active) return;
      setState(() => _prefs[key] = previous);
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
          content: const Text('تعذر حفظ تفضيلات الإشعارات. حاول مجددًا.')));
    } finally {
      if (_active) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'تفضيلات الإشعارات',
        body: _sessionEnded
            ? const Center(
                child: Text('انتهت الجلسة. افتح الإعدادات من حسابك مجددًا.'))
            : _loading
                ? const LoadingState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_loadFailed) ...[
                        const InlineNotice(
                            'تعذر مزامنة الإعدادات. المعروض هو آخر إعداد محفوظ لهذا الحساب.'),
                        TextButton(
                            onPressed: _load,
                            child: const Text('إعادة المحاولة')),
                      ],
                      if (PushNotificationService.instance.supported)
                        AppCard(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('إشعارات الجهاز',
                                style: AppTextStyles.cardTitle),
                            const SizedBox(height: 8),
                            Text(PushNotificationService
                                    .instance.permissionGranted
                                ? 'الإشعارات مفعّلة. يتحكم جهازك بصوت التنبيه ووضع عدم الإزعاج.'
                                : 'اسمح بالإشعارات لتصلك التحديثات خارج التطبيق.'),
                            if (!PushNotificationService
                                .instance.permissionGranted)
                              FilledButton.icon(
                                onPressed:
                                    _requesting ? null : _enableNotifications,
                                icon: const Icon(
                                    Icons.notifications_active_rounded),
                                label: Text(_requesting
                                    ? 'جارٍ التفعيل…'
                                    : 'تفعيل الإشعارات'),
                              ),
                          ],
                        )),
                      const InlineNotice(
                          'تُحفظ التفضيلات لحسابك وتُطبّق على تنبيهات الخادم والتذكيرات المحلية. تنبيهات الأمان والمساعدة العاجلة لا تُكتم، وتبقى صلاحيات الجهاز مطلوبة.'),
                      const SizedBox(height: 12),
                      for (final (key, label, icon, desc) in _categories)
                        AppCard(
                          child: SwitchListTile(
                            key: ValueKey('notification-pref-$key'),
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(icon, color: AppColors.navy),
                            title: Text(label, style: AppTextStyles.cardTitle),
                            subtitle: Text(desc, style: AppTextStyles.caption),
                            value: _prefs[key] ?? true,
                            activeThumbColor: AppColors.navy,
                            activeTrackColor:
                                AppColors.navy.withValues(alpha: 0.4),
                            onChanged: _saving.contains(key)
                                ? null
                                : (v) => _toggle(key, v),
                          ),
                        ),
                    ],
                  ),
      );
}

/// Returns true if a given notification category is enabled.
/// Used by NotificationScheduler to skip scheduling when the user opted out.
Future<bool> isNotificationCategoryEnabled(String category) async {
  if (!NotificationPreferencesStore.categories.contains(category)) return true;
  final owner = AuthSession.instance.currentUser?.id;
  if (owner == null) return false;
  try {
    final values = await NotificationPreferencesStore.read(owner);
    return owner == AuthSession.instance.currentUser?.id &&
        values[category] == true;
  } catch (error, stack) {
    ErrorReporter.swallowed(error, stack, 'notification-preferences.read');
    return owner == AuthSession.instance.currentUser?.id;
  }
}
