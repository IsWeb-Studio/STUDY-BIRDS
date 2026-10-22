import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/screens/games/wink_local_game.dart';
import 'package:study_birds/screens/games/wink_local_screen.dart';
import 'package:study_birds/screens/games/wink_playing_card.dart';
import 'wink_game_test.dart' show mount, DisplayGame;

void main() {
  testWidgets(
      'single-device hub entry opens four-human setup without a server practice request',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await mount(tester, DisplayGame(null));
    final button = find.text('العبوا على جهاز واحد · 4–11 لاعبًا');
    await tester.scrollUntilVisible(button, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(WinkLocalScreen), findsOneWidget);
    expect(
        tester
            .widget<DropdownButtonFormField<int>>(
                find.byType(DropdownButtonFormField<int>))
            .initialValue,
        4);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  WinkLocalGame game() =>
      WinkLocalGame(['A', 'B', 'C', 'D'], random: Random(3));
  void ready(WinkLocalGame g) {
    for (int i = 0; i < 4; i++) {
      g.confirmRole();
    }
  }

  test('local game requires 4–11 people, one winker and unique cards', () {
    expect(() => WinkLocalGame(['A', 'B', 'C']), throwsArgumentError);
    expect(() => WinkLocalGame(List.filled(12, 'A')), throwsArgumentError);
    for (final n in [4, 11]) {
      final g = WinkLocalGame(List.generate(n, (i) => '$i'));
      expect({for (int i = 0; i < n; i++) g.cardFor(i)}.length, n);
      expect([for (int i = 0; i < n; i++) g.cardFor(i)].where((c) => c == 11),
          hasLength(1));
      for (int i = 0; i < n - 1; i++) {
        g.confirmRole();
        expect(g.phase, 'reveal');
      }
      g.confirmRole();
      expect(g.phase, 'playing');
    }
  });
  test('strict-majority secret votes, one accusation per player and player win',
      () {
    final g = game();
    ready(g);
    final accusers = g.living.where((p) => p != g.winker).toList();
    g.accuse(accusers[0], g.winker);
    g.vote(g.nextVoter!, true);
    g.vote(g.nextVoter!, false);
    g.vote(g.nextVoter!, false);
    expect(g.phase, 'playing');
    expect(g.eliminated, isEmpty);
    expect(() => g.accuse(accusers[0], g.winker), throwsStateError);
    g.accuse(accusers[1], g.winker);
    g.vote(g.nextVoter!, true);
    g.vote(g.nextVoter!, true);
    g.vote(g.nextVoter!, false);
    expect(g.winner, 'players');
    expect(g.phase, 'finished');
  });
  test(
      'wink eliminations finish with winker plus one opponent; invalid actions rejected',
      () {
    final g = game();
    expect(() => g.winkedAt(0), throwsStateError);
    ready(g);
    for (final p in g.living.where((p) => p != g.winker).take(2).toList()) {
      g.winkedAt(p);
    }
    expect(g.winner, 'winker');
    expect(g.living, hasLength(2));
    expect(() => g.vote(0, true), throwsStateError);
  });
  testWidgets(
      'four humans pass hidden roles on one offline device; background hides card',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: WinkLocalScreen()));
    await tester.pumpAndSettle();
    final count = tester.widget<DropdownButtonFormField<int>>(
        find.byType(DropdownButtonFormField<int>));
    expect(count.initialValue, 4);
    await tester.scrollUntilVisible(find.text('Deal cards'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Deal cards'));
    await tester.pumpAndSettle();
    for (int i = 1; i <= 4; i++) {
      expect(
          tester.widget<WinkPlayingCard>(find.byType(WinkPlayingCard)).revealed,
          isFalse);
      await tester.tap(find.text('I am Player $i · Show my card'));
      await tester.pumpAndSettle();
      expect(
          tester.widget<WinkPlayingCard>(find.byType(WinkPlayingCard)).revealed,
          isTrue);
      if (i == 1) {
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        expect(
            tester
                .widget<WinkPlayingCard>(find.byType(WinkPlayingCard))
                .revealed,
            isFalse);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.tap(find.text('I am Player $i · Show my card'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Hide and pass device'));
      await tester.pumpAndSettle();
    }
    expect(find.text('I was winked at'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
