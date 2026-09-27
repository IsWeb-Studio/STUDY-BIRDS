import 'package:flutter/foundation.dart';
import 'deep_link_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and cancels local (on-device) reminders.
///
/// Covers PRD بند 48 (Push Notifications) — local tier only.
/// For server-push via FCM, wire up `firebase_messaging` with a
/// google-services.json / GoogleService-Info.plist file.
///
/// Usage:
///   await NotificationScheduler.instance.init();
///   await NotificationScheduler.instance.scheduleConsultation(
///     id: 'abc123',
///     title: 'تذكير: استشارتك بعد ساعة',
///     at: consultationDateTime.subtract(const Duration(hours: 1)),
///   );
class NotificationScheduler {
  NotificationScheduler._();
  static final NotificationScheduler instance = NotificationScheduler._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready || kIsWeb || ![TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) DeepLinkService.instance.open(response.payload!);
      },
    );
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) DeepLinkService.instance.open(payload);
  }

  // ── schedule helpers ──────────────────────────────────────────────────────

  /// Schedules a reminder 1 hour before a consultation.
  Future<void> scheduleConsultation({
    required String id,
    required String title,
    required DateTime at,
    String body = 'انقر للانضمام أو إلغاء الحجز.',
  }) =>
      _schedule(_idFor('consultation:$id'), title, body, at.subtract(const Duration(hours: 1)), '/student/consultations');

  /// Schedules a payment due-date reminder.
  Future<void> schedulePaymentDue({
    required String invoiceId,
    required String amount,
    required DateTime dueDate,
  }) =>
      _schedule(
        _idFor('payment:$invoiceId'),
        'تذكير بدفعة مستحقة',
        'الدفعة $amount مستحقة اليوم. انقر للدفع الآن.',
        dueDate.subtract(const Duration(hours: 6)),
        '/student/payments',
      );

  /// Schedules a reminder when a document is about to expire.
  Future<void> scheduleDocumentExpiry({
    required String docId,
    required String docName,
    required DateTime expiryDate,
  }) =>
      _schedule(
        _idFor('document:$docId'),
        'مستند على وشك الانتهاء',
        '$docName تنتهي صلاحيته قريباً. يُرجى تجديده.',
        expiryDate.subtract(const Duration(days: 7)),
        '/student/documents',
      );

  /// Cancels a scheduled reminder by its source ID.
  Future<void> cancel(String sourceId) async {
    if (!_ready) return;
    await _plugin.cancel(_idFor(sourceId));
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  // ── internal ──────────────────────────────────────────────────────────────

  Future<void> _schedule(
    int notifId,
    String title,
    String body,
    DateTime at,
    String path,
  ) async {
    if (!_ready) return;
    final when = tz.TZDateTime.from(at, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      'sb_reminders',
      'Study Birds Reminders',
      channelDescription: 'تذكيرات المواعيد والمدفوعات والمستندات',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      when,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: path,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Converts a string ID to a stable int for the notifications plugin.
  int _idFor(String id) => id.codeUnits.fold<int>(2166136261, (hash, unit) => ((hash ^ unit) * 16777619) & 0x7fffffff);
}
