import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/roles/employee_extra_screens.dart'
    show MyStudentsQueueScreen;
import 'package:study_birds/screens/roles/admin_student_profile_screen.dart';

void main() {
  const studentId = 'student-42';
  const staffId = 'staff-9';
  final student = <String, dynamic>{
    '_id': studentId,
    'name': 'Student One',
    'email': 'student@example.test',
    'isActive': true,
    'profile': {
      'phone': '+905551234567',
      'nationality': 'Jordanian',
      'passportNumber': 'P12345',
      'currentEducation': 'Bachelor',
      'targetCountries': ['Türkiye'],
    },
  };

  setUp(() {
    AuthSession.instance.token = 'admin-test-token';
    ApiClient.instance.clearCache();
  });

  tearDown(() {
    AuthSession.instance.token = null;
    ApiClient.instance.clearCache();
  });

  testWidgets(
      'student profile exposes details, status and assigned team editing',
      (tester) async {
    var active = true;
    var assignedIds = <String>[];
    var teamSaveCount = 0;
    var advisorAssigned = false;
    var advisorSaveCount = 0;

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const AdminStudentProfileScreen(studentId: studentId),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Student One'), findsOneWidget);
      expect(find.text('student@example.test'), findsOneWidget);
      expect(find.text('+905551234567'), findsOneWidget);
      expect(find.text('P12345'), findsOneWidget);
      await tester.tap(find.text('تعطيل الحساب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(active, isFalse);
      expect(find.text('تفعيل الحساب'), findsOneWidget);

      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('تعديل الفريق'), 260,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('تعديل الفريق'));
      await tester.pumpAndSettle();
      expect(find.text('موظف المتابعة'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('حفظ الفريق'));
      await tester.pumpAndSettle();

      expect(assignedIds, [staffId]);
      expect(teamSaveCount, 1);
      await tester.scrollUntilVisible(find.text('موظف المتابعة'), 220,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('موظف المتابعة'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('تعديل المستشار'), 220,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('تعديل المستشار'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('موظف المتابعة').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(advisorAssigned, isTrue);
      expect(advisorSaveCount, 1);
      expect(find.text('مستشار CRM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              final path = request.url.path;
              dynamic body;
              var statusCode = 200;
              if (request.method == 'GET' &&
                  path == '/api/admin/students/$studentId') {
                body = {
                  'student': {...student, 'isActive': active},
                  'applications': [],
                  'documents': [],
                  'invoices': [],
                  'paymentProofs': [],
                  'favorites': [],
                  'supportTickets': [],
                  'notifications': [],
                };
              } else if (request.method == 'GET' &&
                  path == '/api/admin/students/$studentId/support-team') {
                body = {
                  'members': [],
                  'teamMembers': assignedIds
                      .map((_) => {'_id': staffId, 'name': 'موظف المتابعة'})
                      .toList(),
                  'memberIds': assignedIds,
                  'crmAdvisor': advisorAssigned
                      ? {'_id': staffId, 'name': 'موظف المتابعة'}
                      : null,
                  'candidates': [
                    {
                      '_id': staffId,
                      'name': 'موظف المتابعة',
                      'employeeRole': 'support'
                    },
                  ],
                  'canEdit': true,
                };
              } else if (request.method == 'PATCH' &&
                  path == '/api/admin/students/$studentId/status') {
                active = (jsonDecode(request.body)
                    as Map<String, dynamic>)['isActive'] as bool;
                body = {...student, 'isActive': active};
              } else if (request.method == 'PUT' &&
                  path == '/api/admin/students/$studentId/support-team') {
                assignedIds = List<String>.from((jsonDecode(request.body)
                    as Map<String, dynamic>)['memberIds'] as List);
                teamSaveCount++;
                body = {'members': []};
              } else if (request.method == 'PUT' &&
                  path == '/api/crm/students/$studentId/advisor') {
                advisorAssigned = (jsonDecode(request.body)
                        as Map<String, dynamic>)['advisorId'] ==
                    staffId;
                advisorSaveCount++;
                body = {'advisorId': staffId};
              } else {
                statusCode = 404;
                body = {'message': 'unexpected request'};
              }
              return http.Response(jsonEncode(body), statusCode,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  testWidgets('all students search, bulk status and profile navigation work',
      (tester) async {
    var active = true;
    var profileOpened = false;

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const MyStudentsQueueScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '+905551234567');
      expect(find.text('Student One'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعطيل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(active, isFalse);

      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student One'));
      await tester.pumpAndSettle();
      expect(profileOpened, isTrue);
      expect(find.text('ملف الطالب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              final path = request.url.path;
              dynamic body;
              if (request.method == 'GET' && path == '/api/admin/students') {
                body = [student];
              } else if (request.method == 'PATCH' &&
                  path == '/api/admin/students/$studentId/status') {
                active = (jsonDecode(request.body)
                    as Map<String, dynamic>)['isActive'] as bool;
                body = {...student, 'isActive': active};
              } else if (request.method == 'GET' &&
                  path == '/api/admin/students/$studentId') {
                profileOpened = true;
                body = {
                  'student': {...student, 'isActive': active},
                  'applications': [],
                  'documents': [],
                  'invoices': [],
                  'paymentProofs': [],
                  'favorites': [],
                  'supportTickets': [],
                  'notifications': [],
                };
              } else if (request.method == 'GET' &&
                  path == '/api/admin/students/$studentId/support-team') {
                body = {
                  'members': [],
                  'teamMembers': [],
                  'memberIds': [],
                  'crmAdvisor': null,
                  'candidates': [],
                  'canEdit': true,
                };
              } else {
                body = {'message': 'unexpected request'};
              }
              return http.Response(jsonEncode(body), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
