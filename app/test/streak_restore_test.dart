import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/widgets/streak_restore.dart';

StoryProgress recoverable({int remaining = 3}) => StoryProgress.fromJson({
      'streak_days': 0,
      'recoverableStreakDays': 7,
      'streakRestoresRemaining': remaining,
      'streakRestoreLimit': 3,
      'canRestoreStreak': remaining > 0,
      'serverNow': '2030-10-22T12:00:00Z',
      'recoveryExpiresAt': '2030-10-22T13:00:00Z',
      'monthResetsAt': '2030-10-31T21:00:00Z',
      'streakState': 'recoverable',
    });
void main() {
  setUp(() => AuthSession.instance.token = 'streak-test');
  tearDown(() => AuthSession.instance.token = null);
  testWidgets(
      'restoration requires confirmation, prevents duplicates and updates allowance immediately',
      (tester) async {
    int writes = 0;
    StoryProgress p = recoverable();
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StatefulBuilder(
                  builder: (context, update) => StreakRestore(
                      progress: p,
                      onRestored: (value) => update(() => p = value))))));
      await tester.tap(find.byKey(const ValueKey('streak-restore')));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Restore your streak?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-streak-restore')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(p.days, 7);
      expect(p.restoresRemaining, 2);
      expect(find.text('2 of 3 restores left this month'), findsOneWidget);
      expect(find.byKey(const ValueKey('streak-restore')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              writes++;
              expect(request.url.path, endsWith('/stories/streak/restore'));
              expect(request.headers['Idempotency-Key'], isNotEmpty);
              return http.Response(
                  jsonEncode({
                    'streak_days': 7,
                    'streakRestoresRemaining': 2,
                    'streakState': 'active'
                  }),
                  200);
            }));
  });
  testWidgets('cancel does not write and exhausted allowance offers no restore',
      (tester) async {
    int writes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StreakRestore(
                progress: recoverable(),
                restore: (_) async {
                  writes++;
                  return recoverable();
                },
                onRestored: (_) {}))));
    await tester.tap(find.byKey(const ValueKey('streak-restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StreakRestore(
                progress: recoverable(remaining: 0), onRestored: (_) {}))));
    expect(find.byKey(const ValueKey('streak-restore')), findsNothing);
    expect(find.textContaining('used all three'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'uncertain retry reuses one operation; failed attempt does not change allowance',
      (tester) async {
    final operations = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StreakRestore(
                progress: recoverable(),
                restore: (id) async {
                  operations.add(id);
                  throw Exception('synthetic offline');
                },
                onRestored: (_) {
                  fail('failed restore must not update balance');
                }))));
    for (int i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('streak-restore')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-streak-restore')));
      await tester.pumpAndSettle();
    }
    expect(operations.length, 2);
    expect(operations.toSet().length, 1);
    expect(find.text('3 of 3 restores left this month'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test(
      'eligibility never falls back to device clock or old unlimited recovery payloads',
      () {
    expect(recoverable().restoreEligible, true);
    expect(
        StoryProgress.fromJson({
          'canRestoreStreak': true,
          'recoverableStreakDays': 7,
          'streakRestoresRemaining': 3
        }).restoreEligible,
        false);
    expect(
        StoryProgress.fromJson({
          'canRestoreStreak': true,
          'recoverableStreakDays': 7,
          'streakRestoresRemaining': 3,
          'serverNow': '2030-01-01T00:00:00Z',
          'recoveryExpiresAt': '2029-12-31T23:59:59Z'
        }).restoreEligible,
        false);
  });
}
