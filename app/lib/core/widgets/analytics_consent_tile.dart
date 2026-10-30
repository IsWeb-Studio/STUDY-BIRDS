import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

class AnalyticsConsentTile extends StatefulWidget {
  const AnalyticsConsentTile({super.key});
  @override
  State<AnalyticsConsentTile> createState() => _AnalyticsConsentTileState();
}

class _AnalyticsConsentTileState extends State<AnalyticsConsentTile> {
  bool _allowed = false, _busy = true;
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.getConsent().then((value) {
      if (mounted) {
        setState(() {
          _allowed = value;
          _busy = false;
        });
      }
    });
  }

  Future<void> _change(bool value) async {
    setState(() => _busy = true);
    try {
      await AnalyticsService.instance.setConsent(value);
      if (mounted) setState(() => _allowed = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر حفظ الاختيار / Could not save preference')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return SwitchListTile(
      title: Text(ar
          ? 'مشاركة التحليلات والأعطال (اختياري)'
          : 'Share analytics and errors (optional)'),
      subtitle: Text(ar
          ? 'السماح بإرسال أحداث الاستخدام ومعرّف الحساب إلى PostHog، وتقارير الأعطال إلى Sentry في الولايات المتحدة لتحسين التطبيق. يمكنك الإيقاف هنا في أي وقت. يبدأ إرسال تقارير الأعطال بعد إعادة تشغيل التطبيق.'
          : 'Allow usage events and account ID to be sent to PostHog, and error reports to Sentry in the US to improve the app. Turn sharing off here at any time. Error reporting starts after restarting the app.'),
      value: _allowed,
      onChanged: _busy ? null : _change,
    );
  }
}
