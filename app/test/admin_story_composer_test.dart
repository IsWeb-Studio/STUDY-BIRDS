import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/stories/student_stories.dart';

http.Response _reply(Object value) => http.Response(
      jsonEncode(value),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('admins select a story audience and confirm broad publishing',
      (tester) async {
    final previous = AuthSession.instance.currentUser;
    AuthSession.instance.currentUser = const AuthUser(
      id: 'admin-1',
      name: 'Administrator',
      email: 'admin@example.test',
      role: UserRole.admin,
    );
    addTearDown(() => AuthSession.instance.currentUser = previous);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      home: StoryComposer(),
    ));

    final audience = find.byKey(const ValueKey('admin-story-audience'));
    expect(audience, findsOneWidget);
    expect(find.text('Official COVEY story'), findsOneWidget);
    final notify = find.byKey(const ValueKey('admin-story-notify-audience'));
    expect(tester.widget<CheckboxListTile>(notify).value, isFalse);

    await tester.tap(audience);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('All eligible users').last);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(notify);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(notify).value, isTrue);
    await tester.enterText(find.byType(TextField), 'Service update');
    final publish = find.text('Publish story', skipOffstage: false);
    await tester.ensureVisible(publish);
    await tester.pump();
    await tester.tap(publish);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree to community rules'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'This story will be visible to all eligible COVEY users. They will also receive a community notification if their preferences allow it. Publish?'),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('students keep the existing composer without admin targeting',
      (tester) async {
    final previous = AuthSession.instance.currentUser;
    AuthSession.instance.currentUser = const AuthUser(
      id: 'student-1',
      name: 'Student',
      email: 'student@example.test',
      role: UserRole.student,
    );
    addTearDown(() => AuthSession.instance.currentUser = previous);

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      home: StoryComposer(),
    ));

    expect(find.byKey(const ValueKey('admin-story-audience')), findsNothing);
    expect(find.text('Share an update with your community'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admins can publish without a missing-audience dead end',
      (tester) async {
    AuthSession.instance.token = 'admin-story-publish';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'admin-1',
      name: 'Administrator',
      email: 'admin@example.test',
      role: UserRole.admin,
    );
    ApiClient.instance.clearCache();
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
      ApiClient.instance.clearCache();
    });

    Map<String, dynamic>? postedBody;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        home: StoryComposer(),
      ));
      final audience = find.byKey(const ValueKey('admin-story-audience'));
      expect(
          tester.widget<DropdownButtonFormField<String>>(audience).initialValue,
          'students');
      await tester.enterText(find.byType(TextField), 'Admin story');
      final publish = find.text('Publish story', skipOffstage: false);
      await tester.ensureVisible(publish);
      await tester.pump();
      await tester.tap(publish);
      await tester.pumpAndSettle();
      if (find.text('Agree to community rules').evaluate().isNotEmpty) {
        await tester.tap(find.text('Agree to community rules'));
        await tester.pumpAndSettle();
      }

      expect(postedBody, isNotNull);
      expect(postedBody!['text'], 'Admin story');
      expect(postedBody!['audience'], 'students');
      expect(find.text('Choose a story audience first.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.method == 'POST' &&
                  request.url.path.endsWith('/stories')) {
                postedBody =
                    Map<String, dynamic>.from(jsonDecode(request.body));
                return _reply({
                  'progress': {'streak_days': 0}
                });
              }
              return _reply({});
            }));
  });
}
