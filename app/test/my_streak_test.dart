import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/config/app_theme.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/widgets/streak_restore.dart';
import 'package:study_birds/screens/profile_account/my_streak.dart';

StoryProgress snapshot(String state) => StoryProgress.fromJson({
      'total_points': 1234,
      'streak_days': ['active', 'at_risk'].contains(state) ? 7 : 0,
      'streakState': state,
      'longestStreak': 18,
      'recoverableStreakDays':
          state == 'recoverable' || state == 'expired' ? 7 : 0,
      'streakRestoresRemaining': 2,
      'streakRestoreLimit': 3,
      'canRestoreStreak': state == 'recoverable',
      'serverNow': '2030-10-22T12:00:00Z',
      'resetsAt': '2030-10-22T13:00:00Z',
      'recoveryExpiresAt':
          state == 'expired' ? '2030-10-22T11:00:00Z' : '2030-10-22T14:00:00Z',
      'timeZone': 'Europe/Istanbul',
      'activityCalendar': List.generate(
          35,
          (i) => {
                'day': DateTime.utc(2030, 10, 22)
                    .subtract(Duration(days: 34 - i))
                    .toIso8601String()
                    .substring(0, 10),
                'active': i % 3 == 0,
              }),
    });
Widget host(Widget body,
        {String locale = 'en', bool dark = false, double scale = 1}) =>
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: dark ? ThemeData.dark(useMaterial3: true) : AppTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(body: SingleChildScrollView(child: body)),
    );
void main() {
  for (final language in ['ar', 'en']) {
    for (final gameAccount in [false, true]) {
      testWidgets(
          '$language points rules distinguish student rewards from game-account streaks ($gameAccount)',
          (tester) async {
        await tester.pumpWidget(host(
            StreakRulesSheet(
              timeZone: 'Europe/Istanbul',
              isGameActivity: gameAccount,
            ),
            locale: language));
        await tester.pumpAndSettle();
        final ar = language == 'ar';
        expect(find.text(ar ? 'كيف تجمع النقاط؟' : 'How do you earn points?'),
            findsOneWidget);
        expect(
            find.textContaining(ar
                ? 'اللايك على ستوريك لا يمنح نقاطًا'
                : 'Liking your own story earns no points'),
            findsOneWidget);
        expect(
            find.textContaining(
                ar ? 'بحد أقصى 50 نقطة في اليوم' : 'up to 50 points per day'),
            findsOneWidget);
        expect(find.textContaining(ar ? '+300 نقطة' : '+300 bonus points'),
            gameAccount ? findsNothing : findsOneWidget);
        expect(
            find.textContaining(ar
                ? 'مكافأة الـ10 نقاط الخاصة بحساب الطالب'
                : '10-point student bonus'),
            gameAccount ? findsOneWidget : findsNothing);
        expect(find.byType(GridView), findsNothing);
        expect(find.byType(StreakRestore), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  test(
      'successful story post returns its server-awarded points and refreshes profile listeners',
      () async {
    AuthSession.instance.token = 'story-points-test';
    final changed = StoriesRepository.instance.changes.first;
    await http.runWithClient(() async {
      final result = await StoriesRepository.instance.post(
        text: 'Synthetic story',
        imageUrl: '',
        operationId: 'story-points-test-01',
      );
      expect(result.points, 1100);
      expect(result.awardedPoints, 100);
    },
        () => MockClient((request) async {
              expect(request.method, 'POST');
              expect(request.url.path, endsWith('/stories'));
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['operationId'], 'story-points-test-01');
              return http.Response(
                jsonEncode({
                  'awarded': 100,
                  'progress': {
                    'total_points': 1100,
                    'streak_days': 0,
                    'streakState': 'empty',
                    'streakRestoresRemaining': 3,
                    'streakRestoreLimit': 3,
                    'timeZone': 'Europe/Istanbul',
                  },
                }),
                201,
                headers: {'content-type': 'application/json'},
              );
            }));
    await changed;
    AuthSession.instance.token = null;
  });

  for (final role in [
    UserRole.parent,
    UserRole.university,
    UserRole.employee,
    UserRole.admin,
  ]) {
    testWidgets('$role streak copy is based on online game activity',
        (tester) async {
      AuthSession.instance.token = 'activity-role-test';
      AuthSession.instance.currentUser = AuthUser(
        id: 'user-${role.name}',
        name: 'Activity test',
        email: '${role.name}@example.test',
        role: role,
      );
      addTearDown(() {
        AuthSession.instance.token = null;
        AuthSession.instance.currentUser = null;
      });
      await tester
          .pumpWidget(host(MyStreakCard(load: () async => snapshot('empty'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Start a new streak by playing online'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final state in [
    'active',
    'at_risk',
    'recoverable',
    'expired',
    'empty'
  ]) {
    testWidgets('profile summary has a distinct $state presentation',
        (tester) async {
      await tester.pumpWidget(host(StreakSummary(progress: snapshot(state))));
      await tester.pumpAndSettle();
      expect(find.text('My Streak'), findsOneWidget);
      expect(find.byKey(const ValueKey('my-streak-points')), findsOneWidget);
      if (state == 'at_risk') {
        expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
        expect(find.textContaining('13:00'), findsOneWidget);
      }
      if (state == 'expired' || state == 'empty') {
        expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
      }
      if (state == 'recoverable') {
        expect(find.text('Your streak can be restored'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'loading and offline/error support accessible retry without invented zero data',
      (tester) async {
    await tester.pumpWidget(host(const StreakSummary(loading: true)));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    int retries = 0;
    await tester.pumpWidget(host(StreakSummary(
        error: const SocketException('synthetic'), onRetry: () => retries++)));
    expect(find.textContaining('You are offline'), findsOneWidget);
    await tester.tap(find.byTooltip('Retry'));
    expect(retries, 1);
    await tester.pumpWidget(
        host(StreakSummary(error: StateError('synthetic'), onRetry: () {})));
    expect(find.textContaining('Could not refresh'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('game streak recovery guidance asks for online play',
      (tester) async {
    await tester.pumpWidget(host(StreakRestore(
      progress: snapshot('expired'),
      isGameActivity: true,
      onRestored: (_) {},
    )));
    expect(
        find.textContaining(
            'Play online to start again; a monthly reset does not reopen it.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final locale in ['ar', 'en']) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 900.0]) {
        testWidgets(
            '$locale dark=$dark width=$width supports details and large text without overflow',
            (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = snapshot('recoverable');
          await tester.pumpWidget(host(
              StreakDetailsSheet(initial: p, load: () async => p),
              locale: locale,
              dark: dark,
              scale: 1.8));
          await tester.pumpAndSettle();
          expect(
              find.text(locale == 'ar'
                  ? '\u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0633\u062a\u0631\u064a\u0643'
                  : 'Streak rules'),
              findsOneWidget);
          expect(find.byType(GridView), findsNothing);
          expect(find.byType(StreakRestore), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets(
      'a stale in-flight request cannot publish after account identity changes',
      (tester) async {
    final previous = AuthSession.instance.token;
    AuthSession.instance.token = 'owner-A';
    final response = Completer<StoryProgress>();
    await tester.pumpWidget(host(MyStreakCard(load: () => response.future)));
    AuthSession.instance.token = 'owner-B';
    response.complete(snapshot('active'));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    AuthSession.instance.token = previous;
  });
}
