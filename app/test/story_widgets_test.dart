import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/repositories/stories_repository.dart';
import 'package:study_birds/screens/stories/student_stories.dart';

void main() {
  testWidgets('achievement ring stays orange when viewing ring becomes grey',
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
    expect(borders(), [Colors.blue]);
    await render(false, 10000);
    expect(borders(), [Colors.orange, Colors.blue]);
    await render(true, 10000);
    expect(borders(), [Colors.orange, Colors.grey]);
    await render(false, 99999);
    expect(borders(), [Colors.orange, Colors.blue]);
    await render(false, 100000);
    expect(borders(), [const Color(0xFF8B5CF6), Colors.blue]);
    expect(
        find.byKey(const ValueKey('cosmetic-achievement-badge')), findsNothing);
    await render(true, 199999);
    expect(borders(), [const Color(0xFF8B5CF6), Colors.grey]);
    expect(
        find.byKey(const ValueKey('cosmetic-achievement-badge')), findsNothing);
    await render(true, 200000);
    expect(borders(), [const Color(0xFF8B5CF6), Colors.grey]);
    expect(find.byKey(const ValueKey('cosmetic-achievement-badge')),
        findsOneWidget);
  });
  testWidgets(
      'progress sheet clamps achievement progress and shows completed daily tasks',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StoryProgressSheet(
                progress: const StoryProgress(
                    points: 12000, days: 8, loves: 10, posted: true),
                onPost: () {}))));
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        1);
    expect(find.text('12000 / 10,000'), findsOneWidget);
    expect(find.text('تم ✓'), findsOneWidget);
    expect(find.text('10 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
