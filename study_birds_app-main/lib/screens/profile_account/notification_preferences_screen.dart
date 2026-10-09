import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _prefix = 'notif_pref_';
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
      'أخبار وتحديثات Study Birds'
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar(content: Text('تعذر تفعيل الإشعارات. حاول مجددًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final (key, _, _, _) in _categories) {
        _prefs[key] = p.getBool('$_prefix$key') ?? true;
      }
      final remote = await ApiClient.instance.get(
        '/mobile-security/notification-preferences',
        token: AuthSession.instance.token,
      );
      if (remote is Map) {
        for (final (key, _, _, _) in _categories) {
          if (remote[key] is bool) {
            _prefs[key] = remote[key] as bool;
            await p.setBool('$_prefix$key', _prefs[key]!);
          }
        }
      }
    } catch (_) {
      for (final (key, _, _, _) in _categories) {
        _prefs.putIfAbsent(key, () => true);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String key, bool value) async {
    final previous = _prefs[key] ?? true;
    setState(() => _prefs[key] = value);
    try {
      await ApiClient.instance.put(
        '/mobile-security/notification-preferences',
        token: AuthSession.instance.token,
        body: {key: value},
      );
      final p = await SharedPreferences.getInstance();
      await p.setBool('$_prefix$key', value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs[key] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
            content: const Text('تعذر حفظ تفضيلات الإشعارات. حاول مجددًا.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'تفضيلات الإشعارات',
        body: _loading
            ? const LoadingState()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (PushNotificationService.instance.supported)
                    AppCard(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إشعارات الجهاز',
                            style: AppTextStyles.cardTitle),
                        const SizedBox(height: 8),
                        Text(PushNotificationService.instance.permissionGranted
                            ? 'الإشعارات مفعّلة. يتحكم جهازك بصوت التنبيه ووضع عدم الإزعاج.'
                            : 'اسمح بالإشعارات لتصلك التحديثات خارج التطبيق.'),
                        if (!PushNotificationService.instance.permissionGranted)
                          FilledButton.icon(
                            onPressed:
                                _requesting ? null : _enableNotifications,
                            icon:
                                const Icon(Icons.notifications_active_rounded),
                            label: Text(_requesting
                                ? 'جارٍ التفعيل…'
                                : 'تفعيل الإشعارات'),
                          ),
                      ],
                    )),
                  const InlineNotice(
                      'التفضيلات تتحكم في الإشعارات المحلية. الإشعارات الفورية من الخادم تتبع إعدادات النظام.'),
                  const SizedBox(height: 12),
                  for (final (key, label, icon, desc) in _categories)
                    AppCard(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(icon, color: AppColors.navy),
                        title: Text(label, style: AppTextStyles.cardTitle),
                        subtitle: Text(desc, style: AppTextStyles.caption),
                        value: _prefs[key] ?? true,
                        activeThumbColor: AppColors.navy,
                        activeTrackColor: AppColors.navy.withValues(alpha: 0.4),
                        onChanged: (v) => _toggle(key, v),
                      ),
                    ),
                ],
              ),
      );
}

/// Returns true if a given notification category is enabled.
/// Used by NotificationScheduler to skip scheduling when the user opted out.
Future<bool> isNotificationCategoryEnabled(String category) async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getBool('notif_pref_$category') ?? true;
  } catch (_) {
    return true;
  }
}
