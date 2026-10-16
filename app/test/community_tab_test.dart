import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/app_shell.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/community/student_community_hub.dart';
import 'package:study_birds/screens/profile_account/profile_account_screens.dart';
import 'package:study_birds/screens/stories/student_stories.dart';

void main() {
  testWidgets(
      'bottom account tab is replaced by community and hidden community stops refreshing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthSession.instance.token = 'community-tab';
    addTearDown(() => AuthSession.instance.token = null);
    var inboxRequests = 0, storyRequests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: StudentAppShell()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('مجتمع الطلاب'), findsOneWidget);
      expect(find.byType(ProfileScreen, skipOffstage: false), findsNothing);
      expect(inboxRequests, 0);
      expect(storyRequests, 0);
      await tester.tap(find.byKey(const ValueKey('main-tab-4')));
      await tester.pump(const Duration(seconds: 1));
      expect(
          tester
              .widget<StudentCommunityHub>(find.byType(StudentCommunityHub))
              .isActive,
          true);
      expect(find.byType(StudentStories), findsOneWidget);
      expect(inboxRequests, greaterThan(0));
      expect(storyRequests, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('main-tab-0')));
      await tester.pump(const Duration(seconds: 1));
      final requests = inboxRequests;
      await tester.pump(const Duration(seconds: 6));
      expect(inboxRequests, requests,
          reason: 'offstage community must not poll');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              final path = request.url.path;
              Object data = {};
              if (path.endsWith('/overview')) data = {'journeys': []};
              if ([
                '/universities',
                '/programs',
                '/countries',
                '/scholarships',
                '/services',
                '/banners'
              ].any(path.endsWith)) data = [];
              if (path.endsWith('/conversations')) {
                inboxRequests++;
                data = {'conversations': [], 'unreadTotal': 0};
              }
              if (path.endsWith('/stories')) {
                storyRequests++;
                data = {'stories': []};
              }
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
