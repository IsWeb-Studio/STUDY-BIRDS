import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import 'admin_applications_documents_screens.dart';

class FollowUpRemindersScreen extends StatefulWidget {
  const FollowUpRemindersScreen({super.key});
  @override
  State<FollowUpRemindersScreen> createState() => _FollowUpRemindersState();
}

class _FollowUpRemindersState extends State<FollowUpRemindersScreen> {
  List<dynamic> rows = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ApiClient.instance.get(
          '/applications/follow-up-reminders',
          token: AuthSession.instance.token);
      if (mounted) setState(() => rows = result as List<dynamic>);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل تذكيرات المتابعة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> read(String id) async {
    setState(() => busy = true);
    try {
      await ApiClient.instance.patch(
          '/applications/follow-up-reminders/$id/read',
          token: AuthSession.instance.token);
      if (mounted) await load();
    } catch (_) {
      if (mounted)
        setState(() {
          error = 'تعذر تحديث التذكير.';
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'تذكيرات متابعتي',
      body: busy
          ? const LoadingState()
          : error != null
              ? ErrorState(message: error!, onRetry: load)
              : RefreshIndicator(
                  onRefresh: load,
                  color: AppColors.navy,
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                            'قراءة التذكير لا تعني إنجاز المتابعة. حدّث الموعد من لوحة الموقع بعد مراجعة الطلب.',
                            style: AppTextStyles.caption),
                        if (rows.isEmpty)
                          const EmptyState(
                              icon: Icons.notifications_none_rounded,
                              title: 'لا توجد تذكيرات حالية',
                              message:
                                  'ستظهر هنا تنبيهات مواعيد المتابعة المتأخرة المسندة إليك.'),
                        for (final row in rows)
                          AppCard(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Text(row['title'] as String? ?? 'متابعة متأخرة',
                                    style: AppTextStyles.cardTitle),
                                Text(row['message'] as String? ?? '',
                                    style: AppTextStyles.caption),
                                Text('رقم الطلب: ${row['reminderApplication']}',
                                    style: AppTextStyles.caption),
                                OutlinedButton(
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  AdminApplicationsScreen(
                                                      applicationId:
                                                          row['reminderApplication']
                                                              as String)));
                                      if (mounted) await load();
                                    },
                                    child: const Text('عرض الطلب')),
                                if (row['isRead'] != true)
                                  TextButton(
                                      onPressed: () =>
                                          read(row['_id'] as String),
                                      child: const Text('تمت القراءة')),
                              ])),
                      ])));
}
