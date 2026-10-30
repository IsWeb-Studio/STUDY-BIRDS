import 'package:study_birds/core/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/stories/student_stories.dart';

void main() {
  testWidgets(
      'achievement ring keeps its brand color when viewing ring becomes grey',
      (tester) async {
    Future<void> render(bool seen, int points) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StoryRing(
                seen: seen, points: points, child: const Text('S')))));
    List<Color> borders() => tester
        .widgetList<Container>(find.byType(Container))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>()
        .map((b) => b.top.color)
        .toList();
    await render(false, 9999);
    expect(borders(), [AppColors.navy]);
    await render(false, 10000);
    expect(borders(), [AppColors.greenInk, AppColors.navy]);
    await render(true, 10000);
    expect(borders(), [AppColors.greenInk, Colors.grey]);
    await render(false, 99999);
    expect(borders(), [AppColors.greenInk, AppColors.navy]);
    await render(false, 100000);
    expect(borders(), [AppColors.navy, AppColors.navy]);
    expect(
        find.byKey(const ValueKey('cosmetic-achievement-badge')), findsNothing);
    await render(true, 199999);
    expect(borders(), [AppColors.navy, Colors.grey]);
    expect(
        find.byKey(const ValueKey('cosmetic-achievement-badge')), findsNothing);
    await render(true, 200000);
    expect(borders(), [AppColors.navy, Colors.grey]);
    expect(find.byKey(const ValueKey('cosmetic-achievement-badge')),
        findsOneWidget);
  });
  testWidgets(
      'progress sheet clamps achievement progress and shows completed daily tasks',
      (tester) async {
    final previousUser = AuthSession.instance.currentUser;
    AuthSession.instance.currentUser = const AuthUser(
        id: 'student',
        name: 'Student',
        email: 'student@example.test',
        role: UserRole.student);
    addTearDown(() => AuthSession.instance.currentUser = previousUser);
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
            body: StoryProgressSheet(
                progress: const StoryProgress(
                    points: 12000, days: 8, loves: 10, posted: true),
                onPost: () {}))));
    expect(
        find.text(
            '\u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0633\u062a\u0631\u064a\u0643'),
        findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('12000 / 10,000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agent story composer explains the restricted publishing rule',
      (tester) async {
    final previousUser = AuthSession.instance.currentUser;
    AuthSession.instance.currentUser = const AuthUser(
        id: 'agent',
        name: 'Agent',
        email: 'agent@example.test',
        role: UserRole.agent);
    addTearDown(() => AuthSession.instance.currentUser = previousUser);
    await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: StoryComposer()));

    expect(find.text('Stories'), findsOneWidget);
    expect(
      find.text(
          'Story publishing is available to community accounts except agents. Your streak is counted through online play.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Publish story'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('student account retains story publishing controls',
      (tester) async {
    final previousUser = AuthSession.instance.currentUser;
    AuthSession.instance.currentUser = const AuthUser(
        id: 'student',
        name: 'Student',
        email: 'student@example.test',
        role: UserRole.student);
    addTearDown(() => AuthSession.instance.currentUser = previousUser);
    await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: StoryComposer()));

    expect(find.text('New story'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Publish story'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
