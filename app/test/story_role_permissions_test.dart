import 'dart:typed_data';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _StoryPicker extends ImagePickerPlatform {
  int calls = 0;
  @override
  Future<XFile?> getImageFromSource(
      {required ImageSource source,
      ImagePickerOptions options = const ImagePickerOptions()}) async {
    calls++;
    return XFile.fromData(Uint8List.fromList([255, 216, 255, 217]),
        path: 'story.jpg', mimeType: 'image/jpeg');
  }
}

void main() {
  for (final role in [
    UserRole.student,
    UserRole.parent,
    UserRole.university,
    UserRole.employee,
    UserRole.admin,
  ]) {
    testWidgets('${role.name} uses its story publishing flow', (tester) async {
      final oldPicker = ImagePickerPlatform.instance;
      final picker = _StoryPicker();
      ImagePickerPlatform.instance = picker;
      SharedPreferences.setMockInitialValues(
          {'community_terms_v1:story-role-${role.name}': true});
      var published = 0;
      addTearDown(() => ImagePickerPlatform.instance = oldPicker);
      AuthSession.instance.token = 'story-role-${role.name}';
      AuthSession.instance.currentUser = AuthUser(
        id: 'story-role-${role.name}',
        name: role.name,
        email: '${role.name}@example.test',
        role: role,
      );
      ApiClient.instance.clearCache();
      addTearDown(() {
        AuthSession.instance.token = null;
        AuthSession.instance.currentUser = null;
        ApiClient.instance.clearCache();
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: StudentStories(showCommunityButton: false),
          ),
        ));
        await tester.pumpAndSettle();

        expect(
            find.text('No stories yet. Share the first one!'), findsOneWidget);
        expect(find.text('New story'), findsOneWidget);
        await tester.tap(find.text('New story'));
        await tester.pumpAndSettle();
        if (role == UserRole.admin) {
          expect(find.byType(StoryComposer), findsOneWidget);
          expect(picker.calls, 0);
          expect(find.byKey(const ValueKey('admin-story-audience')),
              findsOneWidget);
        } else {
          expect(find.byType(StoryComposer), findsNothing);
          expect(picker.calls, 1);
          expect(published, 1);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/stories/progress')) {
                  return _reply({'streak_days': 0, 'activityCalendar': []});
                }
                if (request.url.path.endsWith('/stories/image')) {
                  return _reply({'imageUrl': 'https://example.test/story.jpg'});
                }
                if (request.url.path.endsWith('/stories') &&
                    request.method == 'POST') {
                  published++;
                  final body = jsonDecode(request.body) as Map;
                  expect(body['imageUrl'], 'https://example.test/story.jpg');
                  expect(body['operationId'], isNotEmpty);
                  return _reply({
                    'progress': {'streak_days': 1, 'activityCalendar': []},
                    'awarded': 1
                  });
                }
                if (request.url.path.endsWith('/stories')) {
                  return _reply({'stories': []});
                }
                return _reply({});
              }));
    });
  }

  testWidgets('agent can read the community but cannot start a story',
      (tester) async {
    AuthSession.instance.token = 'story-role-agent';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'story-role-agent',
      name: 'Agent',
      email: 'agent@example.test',
      role: UserRole.agent,
    );
    ApiClient.instance.clearCache();
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
      ApiClient.instance.clearCache();
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(body: StudentStories(showCommunityButton: false)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('New story'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((_) async => _reply({'stories': []})));
  });

  testWidgets('student retains the new-story entry point', (tester) async {
    AuthSession.instance.token = 'story-role-student';
    AuthSession.instance.currentUser = const AuthUser(
      id: 'story-role-student',
      name: 'Student',
      email: 'student@example.test',
      role: UserRole.student,
    );
    ApiClient.instance.clearCache();
    addTearDown(() {
      AuthSession.instance.token = null;
      AuthSession.instance.currentUser = null;
      ApiClient.instance.clearCache();
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: StudentStories(showCommunityButton: false),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('New story'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((_) async => _reply({'stories': []})));
  });
}
