import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/realtime_sync_service.dart';
import 'package:study_birds/screens/profile_account/student_rewards_currency_screens.dart';
import 'package:study_birds/screens/stories/student_stories.dart';

void main() {
  testWidgets('story composer offers one shared photo and video option', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoryComposer()));
    expect(find.text('اختيار صورة أو فيديو'), findsOneWidget);
    expect(find.text('اختيار صورة'), findsNothing);
    expect(find.text('اختيار فيديو'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('rewards tracks activity balance and streak changes live', (tester) async {
    AuthSession.instance.token = 'activity-rewards-test';
    addTearDown(() => AuthSession.instance.token = null);
    var points = 6500;
    var days = 7;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: StudentRewardsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('6500'), findsOneWidget);
      expect(find.text('🔥 7 يوم متتالي'), findsOneWidget);
      points = 6550;
      days = 0;
      RealtimeSyncService.instance.forceSync();
      await tester.pumpAndSettle();
      expect(find.text('6550'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('🔥 0 يوم متتالي'), findsOneWidget);
      points = 6540;
      RealtimeSyncService.instance.forceSync();
      await tester.pumpAndSettle();
      expect(find.text('6540'), findsOneWidget);
      expect(find.text('-10'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((req) async => http.Response(jsonEncode(
      req.url.path.endsWith('/stories/progress')
        ? {'total_points': points, 'streak_days': days}
        : {'totalPoints': 123, 'entries': []}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
