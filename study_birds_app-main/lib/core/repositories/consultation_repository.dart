import '../network/api_client.dart';
import '../services/auth_session.dart';
import '../services/notification_scheduler.dart';

class ConsultationRepository {
  ConsultationRepository._();
  static final instance = ConsultationRepository._();
  String? get _token => AuthSession.instance.token;
  Future<List<Map<String, dynamic>>> _list(String path) async {
    final data =
        await ApiClient.instance.get('/consultations$path', token: _token);
    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> slots() => _list('/slots');
  Future<List<Map<String, dynamic>>> mine() => _list('/mine');
  Future<Map<String, dynamic>> book(String slotId) async {
    final result = await ApiClient.instance.post('/consultations/bookings',
        token: _token, body: {'slotId': slotId});
    final booking = Map<String, dynamic>.from(result as Map);
    await _remind(booking);
    return booking;
  }

  Future<void> cancel(Map<String, dynamic> booking) async {
    await ApiClient.instance.post(
        '/consultations/bookings/${booking['_id']}/cancel',
        token: _token,
        body: {'version': booking['__v']});
    await NotificationScheduler.instance.cancel('consultation:${booking['_id']}');
  }

  Future<Map<String, dynamic>> reschedule(Map<String, dynamic> booking, String slotId) async {
    final result = await ApiClient.instance.post(
        '/consultations/bookings/${booking['_id']}/reschedule',
        token: _token,
        body: {'version': booking['__v'], 'slotId': slotId});
    await NotificationScheduler.instance.cancel('consultation:${booking['_id']}');
    final updated = Map<String, dynamic>.from(result as Map);
    await _remind(updated);
    return updated;
  }

  Future<void> _remind(Map<String, dynamic> booking) async {
    final at = DateTime.tryParse('${booking['startsAt']}');
    if (at == null || booking['_id'] == null) return;
    try {
      await NotificationScheduler.instance.scheduleConsultation(id: '${booking['_id']}', title: 'تذكير: استشارتك بعد ساعة', at: at);
    } catch (_) { /* The booking remains valid when device reminders are denied. */ }
  }

  // ---- Staff availability & bookings (requires the 'consultations'
  // permission; admins see every consultant, staff see only themselves) ----

  Future<List<Map<String, dynamic>>> staffAdvisors() =>
      _list('/staff/advisors');
  Future<List<Map<String, dynamic>>> staffSlots() => _list('/staff/slots');
  Future<List<Map<String, dynamic>>> staffBookings() =>
      _list('/staff/bookings');

  Future<void> publishSlot({
    required String advisorId,
    required DateTime startsAt,
    required String mode,
    String meetingUrl = '',
    String instructions = '',
  }) async {
    await ApiClient.instance
        .post('/consultations/staff/slots', token: _token, body: {
      'advisorId': advisorId,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'mode': mode,
      'meetingUrl': meetingUrl,
      'instructions': instructions,
    });
  }

  Future<void> saveOutcome(Map<String, dynamic> booking,
      {required String result,
      required String summary,
      required String nextSteps}) async {
    await ApiClient.instance.put(
        '/consultations/staff/bookings/${booking['_id']}/outcome',
        token: _token,
        body: {
          'version': booking['__v'],
          'result': result,
          'summary': summary.trim(),
          'nextSteps': nextSteps.trim(),
        });
  }

  Future<void> publishSlots(
      {required String advisorId,
      required List<DateTime> startsAt,
      required String mode,
      String meetingUrl = '',
      String instructions = ''}) async {
    await ApiClient.instance
        .post('/consultations/staff/slots/batch', token: _token, body: {
      'advisorId': advisorId,
      'startsAt':
          startsAt.map((date) => date.toUtc().toIso8601String()).toList(),
      'mode': mode,
      'meetingUrl': meetingUrl,
      'instructions': instructions
    });
  }

  Future<void> setSlotEnabled(Map<String, dynamic> slot, bool enabled) async {
    await ApiClient.instance.patch('/consultations/staff/slots/${slot['_id']}',
        token: _token, body: {'version': slot['__v'], 'enabled': enabled});
  }
}
