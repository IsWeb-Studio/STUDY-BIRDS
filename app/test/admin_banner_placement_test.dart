import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/admin_content_crud_screens.dart';

void main() {
  testWidgets(
      'admin phone banner form sends selected community placement and active state',
      (tester) async {
    final previous = AuthSession.instance.currentUser;
    final token = AuthSession.instance.token;
    AuthSession.instance.token = 'banner-admin';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'admin',
        name: 'Admin',
        email: 'admin@test.local',
        role: UserRole.admin);
    addTearDown(() {
      AuthSession.instance.currentUser = previous;
      AuthSession.instance.token = token;
      ApiClient.instance.clearCache();
    });
    Map<String, dynamic>? payload;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminBannersScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مجتمع الطلاب').last);
      await tester.pumpAndSettle();
      final title = find.widgetWithText(TextField, 'العنوان *');
      // Required marker is rendered by the shared CRUD field label.
      final input = title.evaluate().isNotEmpty
          ? title
          : find.widgetWithText(TextField, 'العنوان');
      await tester.enterText(input, 'Community offer');
      final save = find.text('حفظ');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(payload?['placement'], 'community');
      expect(payload?['title'], 'Community offer');
      expect(payload?['active'], isTrue);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                payload = Map<String, dynamic>.from(jsonDecode(request.body));
              }
              return http.Response(request.method == 'GET' ? '[]' : '{}', 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
