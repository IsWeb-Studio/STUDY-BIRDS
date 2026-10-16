import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/games/wink_controller.dart';
import 'wink_game_test.dart' show fixture, mount, DisplayGame;

Map<String, dynamic> training(
    {String phase = 'reveal', String role = 'player'}) {
  final data = fixture(phase: phase);
  data['isPractice'] = true;
  (data['me'] as Map)['role'] = role;
  (data['me'] as Map)['card'] = role == 'winker' ? 11 : 1;
  for (final p in data['players'] as List) {
    p['isBot'] = p['id'] != 'p0';
    p['seen'] = p['isBot'];
  }
  if (phase == 'finished')
    data['result'] = {
      'winner': 'players',
      'winker': 'p1',
      'reason': 'winker-out'
    };
  return data;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.token = 'practice-human';
  });
  tearDown(() {
    AuthSession.instance.token = null;
  });
  testWidgets(
      'practice button starts one human with three bots and no room sharing',
      (tester) async {
    var starts = 0;
    final api = ApiClient.forTesting(MockClient((request) async {
      if (request.url.path.endsWith('/current'))
        return http.Response('{"code":null}', 200);
      expect(request.url.path.endsWith('/practice'), true);
      expect((jsonDecode(request.body) as Map)['role'], 'player');
      starts++;
      return http.Response(jsonEncode(training()), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final game = WinkController(api: api);
    await mount(tester, game);
    final button = find.text('تجربة اللعبة مع 3 بوتات');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(game.players.where((p) => p['isBot'] == true), hasLength(3));
    expect(find.text('وضع التجربة · أنت و3 بوتات'), findsOneWidget);
    expect(find.text('ABCD1234'), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(game.phase, 'reveal');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('practice wink controls are available only in the practice room',
      (tester) async {
    final data = training(phase: 'playing', role: 'winker');
    // Older cached responses must not reintroduce a wait on the button.
    (data['me'] as Map)['nextWinkAt'] =
        DateTime.now().millisecondsSinceEpoch + 15000;
    await mount(tester, DisplayGame(data));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('practice-wink-p1')), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('غمزة تجريبية'), findsWidgets);
    expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('practice-wink-p1')))
            .onPressed,
        isNotNull);
    expect(find.textContaining('الغمزة التجريبية القادمة'), findsNothing);
    expect(find.textContaining('باقي '), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('practice result offers both roles for the next round',
      (tester) async {
    await mount(tester, DisplayGame(training(phase: 'finished')));
    expect(find.text('جولة جديدة كلاعب'), findsOneWidget);
    expect(find.text('جرّب كغمّاز'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
