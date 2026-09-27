import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/student_repository.dart';
import '../../core/analytics_service.dart';
import '../../core/realtime_sync_service.dart';
import '../../core/notification_links.dart';
import '../services_support/services_consultation_screens.dart';
import '../services_support/support_team_ai_screens.dart';
import '../services_support/community_screen.dart';
import '../applications_documents_payments/applications_screens.dart';
import '../applications_documents_payments/documents_screens.dart';
import '../applications_documents_payments/payments_screens.dart';
import '../visa_travel_accommodation/arrival_services_screen.dart';
import '../visa_travel_accommodation/accommodation_arrival_screens.dart';
import '../visa_travel_accommodation/visa_travel_screens.dart' show InsuranceScreen, EquivalencyScreen, VisaCenterScreen, TravelCenterScreen;
import 'journey_tracker_screen.dart';

/// Returns a short action label for a notification link, or null if no action.
String? notificationActionLabel(String? link) {
  if (link == null || !link.startsWith('/student/')) return null;
  final dest = link.replaceFirst('/student/', '');
  return switch (dest) {
    'documents' || 'upload-document' => 'رفع المستند الآن',
    'payments'                       => 'عرض الفاتورة',
    'applications'                   => 'عرض الطلب',
    'support'                        => 'فتح الدعم',
    'journey' || 'visa'              => 'متابعة الرحلة',
    'travel' || 'accommodation'      => 'خدمات الوصول',
    'university-registration'        => 'التسجيل الجامعي',
    'insurance'                      => 'التأمين الصحي',
    'equivalency'                    => 'معادلة الشهادة',
    'consultations'                  => 'حجز استشارة',
    _                                => null,
  };
}

/// Maps a backend notification link (e.g. '/student/documents') to the widget
/// that should be pushed. Returns null for unknown or non-navigable links.
Widget? notificationScreenForLink(String? link) {
  link = notificationPath(link ?? '');
  if (link == null || !link.startsWith('/student/')) return null;
  final dest = link.replaceFirst('/student/', '');
  return switch (dest) {
    'consultations' => const ConsultationBookingScreen(),
    'journey' => const JourneyTrackerScreen(),
    'visa' => const VisaCenterScreen(),
    'travel' => const TravelCenterScreen(),
    'accommodation' => const AccommodationScreen(),
    'services' => const MyServiceRequestsScreen(),
    'notifications' => const NotificationsScreen(),
    'university-registration' => const UniversityRegistrationScreen(),
    'insurance' => const InsuranceScreen(),
    'equivalency' => const EquivalencyScreen(),
    'documents' || 'upload-document' => const MyDocumentsScreen(),
    'payments' => const PaymentsSummaryScreen(),
    'applications' => const ApplicationsListScreen(),
    'support' => const SupportCenterScreen(),
    'community' => const StudentCommunityScreen(),
    'bird-ai' => const BirdAIChatScreen(),
    _ => null,
  };
}

IconData _notificationIcon(String? type) {
  switch (type) {
    case 'success':
      return Icons.check_circle_outline_rounded;
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'info':
    default:
      return Icons.info_outline_rounded;
  }
}

Color _notificationColor(String? type) {
  switch (type) {
    case 'success':
      return AppColors.success;
    case 'warning':
      return AppColors.warning;
    case 'info':
    default:
      return AppColors.info;
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<DateTime>? _syncSub;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('notifications');
    _load();
    _syncSub = RealtimeSyncService.instance.onTick.listen((_) {
      StudentRepository.instance.getNotifications()
          .then((data) { if (mounted) setState(() => _notifications = data); })
          .catchError((_) {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StudentRepository.instance.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الإشعارات.';
        _loading = false;
      });
    }
  }

  Future<void> _markRead(Map<String, dynamic> n, int index) async {
    if (n['isRead'] == true || !mounted) return;
    setState(() => n['isRead'] = true); // optimistic
    try {
      await StudentRepository.instance.markNotificationRead(n['_id'] as String);
    } catch (_) {
      if (!mounted) return;
      setState(() => n['isRead'] = false); // revert on failure
    }
  }

  Future<void> _markAllRead() async {
    final unread = _notifications
        .cast<Map<String, dynamic>>()
        .where((n) => n['isRead'] != true)
        .toList();
    await Future.wait(unread.map((n) => _markRead(n, 0)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإشعارات',
      actions: [
        TextButton(
          onPressed: _markAllRead,
          child: const Text('تعليم الكل كمقروء',
              style: TextStyle(color: Colors.white, fontSize: 12.5)),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (_, __) =>
                    const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _notifications.isEmpty
                    ? const EmptyState(
                        icon: Icons.notifications_off_rounded,
                        title: 'لا توجد إشعارات',
                        message:
                            'ستصلك هنا كل التحديثات المهمة المتعلقة برحلتك.',
                      )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, i) {
                        final n = _notifications[i] as Map<String, dynamic>;
                        final isRead = n['isRead'] == true;
                        final color = _notificationColor(n['type'] as String?);
                        final createdAt =
                            (n['createdAt'] as String?)?.split('T').first ?? '';

                        final link = n['link'] as String?;
                        final actionLabel = notificationActionLabel(link);
                        void navigate() async {
                          await _markRead(n, i);
                          if (!context.mounted) return;
                          final screen = notificationScreenForLink(link);
                          if (screen != null) {
                            await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => screen));
                          }
                        }

                        return AppCard(
                          onTap: navigate,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isRead)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6, top: 4),
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                          color: AppColors.orange,
                                          shape: BoxShape.circle),
                                    ),
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        shape: BoxShape.circle),
                                    child: Icon(
                                        _notificationIcon(n['type'] as String?),
                                        size: 18,
                                        color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(n['title'] as String? ?? '',
                                            style: AppTextStyles.body.copyWith(
                                                fontWeight: isRead
                                                    ? FontWeight.w400
                                                    : FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(n['message'] as String? ?? '',
                                            style: AppTextStyles.caption),
                                        const SizedBox(height: 4),
                                        Text(createdAt,
                                            style: AppTextStyles.caption),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (actionLabel != null) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: navigate,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      side: const BorderSide(color: AppColors.navy),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.button)),
                                    ),
                                    child: Text(actionLabel,
                                        style: const TextStyle(
                                            color: AppColors.navy,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}
