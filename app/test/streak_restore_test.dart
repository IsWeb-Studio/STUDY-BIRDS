import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/widgets/streak_restore.dart';

void main() {
  testWidgets(
      'restore consumes one request and updates remaining monthly allowance',
      (tester) async {
    AuthSession.instance.token = 'streak-test';
    addTearDown(() => AuthSession.instance.token = null);
    var progress = StoryProgress.fromJson({
      'streak_days': 0,
      'recoverableStreakDays': 7,
      'streakRestoresRemaining': 3,
      'canRestoreStreak': true,
    });
    final response = Completer<http.Response>();
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StatefulBuilder(
        builder: (context, update) => StreakRestore(
            progress: progress,
            onRestored: (value) => update(() => progress = value)),
      ))));
      await tester.tap(find.text('استرجاع الستريك (7 يوم)'));
      await tester.pump();
      expect(requests, 1);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      response.complete(http.Response(
          jsonEncode({
            'streak_days': 7,
            'streakRestoresRemaining': 2,
            'recoverableStreakDays': 0,
            'canRestoreStreak': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      await tester.pumpAndSettle();
      expect(progress.days, 7);
      expect(find.text('استرجاع الستريك: متبقي 2 من 3 هذا الشهر.'),
          findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) {
              requests++;
              expect(request.url.path, endsWith('/stories/streak/restore'));
              expect(request.method, 'POST');
              expect(request.headers['Idempotency-Key'], isNotEmpty);
              return response.future;
            }));
  });
  testWidgets('fourth restore is disabled and server fields default safely',
      (tester) async {
    final progress = StoryProgress.fromJson({
      'recoverableStreakDays': 7,
      'streakRestoresRemaining': 0,
      'canRestoreStreak': false,
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StreakRestore(
      progress: progress,
      onRestored: (_) => fail('must not restore'),
    ))));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.textContaining('استخدمت الاسترجاعات الثلاثة'), findsOneWidget);
    expect(StoryProgress.fromJson({}).canRestore, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
