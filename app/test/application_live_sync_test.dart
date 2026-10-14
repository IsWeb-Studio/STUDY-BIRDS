import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/realtime_sync_service.dart';
import 'package:study_birds/screens/applications_documents_payments/applications_screens.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  testWidgets('open application reflects admin acceptance without reopening', (tester) async {
    AuthSession.instance.token = 'test';
    addTearDown(() => AuthSession.instance.token = null);
    var status = 'submitted';
    final application = <String, dynamic>{'_id': 'a', 'status': status};
    await http.runWithClient(() async {
      await mount(tester, ApplicationDetailScreen(application: application));
      expect(find.text('تم التقديم'), findsWidgets);
      status = 'accepted';
      RealtimeSyncService.instance.forceSync();
      await tester.pumpAndSettle();
      expect(find.text('مقبول'), findsWidgets);
      expect(find.text('تم التقديم'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async => http.Response(
        jsonEncode({...application, 'status': status}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
