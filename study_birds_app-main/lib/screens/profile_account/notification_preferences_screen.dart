import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  static const _prefix = 'notif_pref_';
  final _prefs = <String, bool>{};
  bool _loading = true;

  static const _categories = [
    ('payments', 'استحقاق الدفع', Icons.payment_rounded,
        'تذكير بموعد السداد قبل 6 ساعات'),
    ('admission', 'تحديثات القبول', Icons.school_rounded,
        'صدور قبول، تغيير حالة الطلب'),
    ('documents', 'طلبات المستندات', Icons.folder_rounded,
        'طلب رفع مستند، قرار مراجعة'),
    ('consultations', 'الاستشارات', Icons.calendar_today_rounded,
        'تذكير بموعد الاستشارة القادمة'),
    ('visa', 'التأشيرة والسفر', Icons.flight_takeoff_rounded,
        'تحديثات تتعلق بالتأشيرة وموعد السفر'),
    ('support', 'ردود الدعم', Icons.support_agent_rounded,
        'رد فريق الدعم على تذاكرك'),
    ('announcements', 'الإعلانات العامة', Icons.campaign_rounded,
        'أخبار وتحديثات Study Birds'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final (key, _, _, _) in _categories) {
        _prefs[key] = p.getBool('$_prefix$key') ?? true;
      }
    } catch (_) {
      for (final (key, _, _, _) in _categories) {
        _prefs[key] = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _prefs[key] = value);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('$_prefix$key', value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'تفضيلات الإشعارات',
        body: _loading
            ? const LoadingState()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
