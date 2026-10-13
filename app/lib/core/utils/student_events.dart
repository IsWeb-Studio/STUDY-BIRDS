import 'json_safe.dart';
import '../services/error_reporter.dart';
import '../repositories/student_repository.dart';
import '../repositories/consultation_repository.dart';
import '../services/auth_session.dart' show AuthSession;
import '../network/api_client.dart';

class StudentEvent {
  final DateTime date;
  final String title;
  final String detail;
  const StudentEvent(this.date, this.title, [this.detail = '']);
}

List<StudentEvent> calendarEvents(
    Map<String, dynamic> financials,
    Map<String, dynamic>? arrival, {
    List<Map<String, dynamic>> consultations = const [],
    List<dynamic> documents = const [],
}) {
  final events = <StudentEvent>[];
  for (final booking in consultations) {
    final date = DateTime.tryParse('${booking['startsAt']}');
    if (booking['status'] == 'booked' && date != null) {
      events.add(StudentEvent(date.toLocal(), 'موعد استشارة',
          '${booking['advisor']?['name'] ?? ''}'));
    }
  }
  for (final invoice in (Json.listOrNull(financials['invoices']) ?? [])) {
    final date = DateTime.tryParse(invoice['dueDate']?.toString() ?? '');
    if (date != null && invoice['status'] != 'paid') {
      events.add(StudentEvent(date,
          'استحقاق: ${invoice['description'] ?? invoice['invoiceNumber'] ?? 'فاتورة'}'));
    }
  }
  // Document expiry dates
  for (final doc in documents) {
    final exp = DateTime.tryParse((Json.map(doc))['expiresAt']?.toString() ?? '');
    if (exp != null) {
      final name = doc['originalName']?.toString() ?? doc['type']?.toString() ?? 'مستند';
      events.add(StudentEvent(exp.toLocal(), 'انتهاء صلاحية: $name'));
    }
  }
  final date = DateTime.tryParse(arrival?['arrivalDate']?.toString() ?? '');
  if (date != null)
    events.add(StudentEvent(
        date,
        'موعد الوصول',
        '${arrival?['airport'] ?? ''} ${arrival?['arrivalTime'] ?? ''}'
            .trim()));
  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
}

List<StudentEvent> activityEvents(
    List<dynamic> applications,
    List<dynamic> documents,
    List<dynamic> notifications, {
    List<dynamic> invoices = const [],
    List<dynamic> serviceRequests = const [],
}) {
  final events = <StudentEvent>[];
  void add(dynamic rawDate, String title, [String detail = '']) {
    final date = DateTime.tryParse(rawDate?.toString() ?? '');
    if (date != null) events.add(StudentEvent(date.toLocal(), title, detail));
  }

  for (final application in applications) {
    add(application['createdAt'], 'تقديم طلب دراسي');
    for (final item in (Json.listOrNull(application['timeline']) ?? [])) {
      add(item['changedAt'], 'تحديث الطلب',
          item['note']?.toString() ?? item['status']?.toString() ?? '');
    }
  }
  for (final document in documents) {
    add(
        document['createdAt'],
        'رفع مستند',
        document['originalName']?.toString() ??
            document['type']?.toString() ??
            '');
  }
  for (final invoice in invoices) {
    final m = Json.map(invoice);
    if (m['status'] == 'paid' && m['reviewedAt'] != null) {
      add(m['reviewedAt'], 'دفع فاتورة',
          m['description']?.toString() ?? m['invoiceNumber']?.toString() ?? '');
    } else {
      add(m['createdAt'], 'فاتورة جديدة',
          m['description']?.toString() ?? m['invoiceNumber']?.toString() ?? '');
    }
  }
  for (final sr in serviceRequests) {
    final m = Json.map(sr);
    add(m['createdAt'], 'طلب خدمة',
        m['serviceType']?.toString() ?? m['status']?.toString() ?? '');
    for (final item in (Json.listOrNull(m['statusHistory']) ?? [])) {
      add(item['changedAt'], 'تحديث طلب الخدمة',
          item['status']?.toString() ?? '');
    }
  }
  for (final notification in notifications) {
    add(notification['createdAt'], notification['title']?.toString() ?? 'إشعار',
        notification['message']?.toString() ?? '');
  }
  events.sort((a, b) => b.date.compareTo(a.date));
  return events;
}

Future<List<StudentEvent>> loadCalendarEvents() async {
  final repo = StudentRepository.instance;
  final results = await Future.wait([
    repo.getFinancials().catchError(ErrorReporter.fallback('core/utils/student_events.dart:112', <String, dynamic>{})),
    repo.getArrivalServices().catchError(ErrorReporter.fallback('core/utils/student_events.dart:113', <dynamic>[])),
    repo.getDocuments().catchError(ErrorReporter.fallback('core/utils/student_events.dart:114', <dynamic>[])),
  ]);
  final financials = Json.map(results[0]);
  final arrivalList = Json.list(results[1]);
  final arrival = arrivalList.isNotEmpty
      ? Json.mapOrNull(arrivalList.first)
      : null;
  final documents = Json.list(results[2]);
  List<Map<String, dynamic>> consultations;
  try {
    consultations = await ConsultationRepository.instance.mine();
  } on ApiException catch (e) {
    if (e.statusCode != 404) rethrow;
    consultations = [];
  }
  return calendarEvents(financials, arrival,
      consultations: consultations, documents: documents);
}

Future<List<StudentEvent>> loadActivityEvents() async {
  final repo = StudentRepository.instance;
  final results = await Future.wait([
    repo.getApplications(),
    repo.getDocuments(),
    repo.getNotifications(),
    repo.getFinancials(),
  ]);
  final applications = Json.list(results[0]);
  final documents = Json.list(results[1]);
  final notifications = Json.list(results[2]);
  final financials = Json.map(results[3]);
  final invoices = (Json.listOrNull(financials['invoices']))?.cast<dynamic>() ?? [];
  List<dynamic> serviceRequests;
  try {
    final raw = await ApiClient.instance.get(
        '/service-requests/mine', token: AuthSession.instance.token);
    serviceRequests = raw is List ? raw : [];
  } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'core/utils/student_events.dart:150');
    serviceRequests = [];
  }
  return activityEvents(applications, documents, notifications,
      invoices: invoices, serviceRequests: serviceRequests);
}
