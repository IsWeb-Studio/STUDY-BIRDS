import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/games/wink_controller.dart';
import 'package:study_birds/screens/games/wink_screen.dart';
import 'package:study_birds/screens/games/wink_playing_card.dart';

Map<String, dynamic> fixture({String phase = 'reveal'}) => {
      'code': 'ABCD1234',
      'phase': phase,
      'round': 1,
      'host': 'p0',
      'serverNow': DateTime.now().millisecondsSinceEpoch,
      'revealUntil': DateTime.now().millisecondsSinceEpoch + 60000,
      'endsAt': DateTime.now().millisecondsSinceEpoch + 300000,
      'settings': {
        'mode': 'local',
        'roundSeconds': 300,
        'voteSeconds': 20,
        'cooldownSeconds': 15
      },
      'me': {
        'id': 'p0',
        'role': 'winker',
        'card': 11,
        'eliminated': false,
        'seen': false,
        'accused': false,
        'nextWinkAt': 0
      },
      'players': [
        for (var i = 0; i < 4; i++)
          {
            'id': 'p$i',
            'name': 'اللاعب $i',
            'connected': true,
            'ready': true,
            'eliminated': false
          }
      ],
      'events': [],
    };

class DisplayGame extends WinkController {
  DisplayGame(Map<String, dynamic>? data) {
    room = data;
    initialized = true;
  }
  @override
  Future<void> start() async {}
  @override
  Future<void> refresh() async {}
}

Future<void> mount(WidgetTester tester, WinkController game,
    {double scale = 1, String language = 'ar'}) async {
  await tester.pumpWidget(MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: WinkScreen(controller: game)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.token = 'game-test';
  });
  tearDown(() {
    AuthSession.instance.token = null;
  });

  testWidgets('invalid room codes never send an API request', (tester) async {
    var calls = 0;
    final game =
        WinkController(api: ApiClient.forTesting(MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    })));
    await game.join('invalid/code');
    expect(game.errorCode, 'invalid-code');
    expect(calls, 0);
    game.dispose();
  });

  testWidgets(
      'room code stays editable across ticks and joins with Arabic digits',
      (tester) async {
    var joins = 0;
    final game =
        WinkController(api: ApiClient.forTesting(MockClient((request) async {
      if (request.url.path.endsWith('/current')) {
        return http.Response('{"code":null}', 200);
      }
      expect(request.method, 'POST');
      expect(request.url.path.endsWith('/AB12CD34/join'), true);
      joins++;
      return http.Response(
          jsonEncode({...fixture(phase: 'lobby'), 'code': 'AB12CD34'}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    })));
    await mount(tester, game);
    final input = find.byKey(const ValueKey('wink-room-code-input'));
    await tester.scrollUntilVisible(input, 250,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(input), alignment: .3);
    await tester.pumpAndSettle();
    await tester.enterText(input, 'ab١٢');
    await tester.pump(const Duration(seconds: 3));
    expect(tester.testTextInput.isVisible, true);
    expect(tester.widget<TextField>(input).controller!.text, 'ab١٢');
    tester.testTextInput.enterText('ab١٢ cd٣٤');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, 'ab١٢ cd٣٤');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(joins, 1);
    expect(game.room?['code'], 'AB12CD34');
    expect(game.players, hasLength(4));
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'room codes accept pasted separators and Arabic, Persian and fullwidth numbers',
      () {
    for (final code in [
      'ab12-cd34',
      ' AB١٢ CD٣٤ ',
      '\u200fab۱۲cd۳۴\u200e',
      'ab１２cd３４'
    ]) {
      expect(WinkController.normalizeRoomCode(code), 'AB12CD34');
    }
  });

  testWidgets('late responses cannot expose cards after changing accounts',
      (tester) async {
    late Completer<http.Response> response;
    final game = WinkController(
        api: ApiClient.forTesting(MockClient((request) => response.future)));
    await tester.runAsync(() async {
      response = Completer<http.Response>();
      final create = game.create();
      await Future<void>.delayed(Duration.zero);
      AuthSession.instance.token = 'another-player';
      response.complete(http.Response(jsonEncode(fixture()), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      await create;
    });
    expect(game.room, isNull);
    expect(game.me, isEmpty);
    expect(game.canAct, false);
    game.dispose();
  });

  testWidgets(
      'face-to-face play offers self-report and no digital wink controls',
      (tester) async {
    final data = fixture(phase: 'playing');
    (data['me'] as Map)['role'] = 'player';
    (data['me'] as Map)['card'] = 7;
    await mount(tester, DisplayGame(data));
    await tester.scrollUntilVisible(find.text('اتغمزلي'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('اتغمزلي'), findsOneWidget);
    expect(find.text('غمزة سرية'), findsNothing);
    expect(find.textContaining('أونلاين'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('role stays open after release and refresh until manually hidden',
      (tester) async {
    final game = DisplayGame(fixture());
    await mount(tester, game);
    expect(find.text('إنت الغمّاز'), findsNothing);
    final hold = find.byType(WinkPlayingCard);
    await tester.ensureVisible(hold);
    await tester.pumpAndSettle();
    final pointer = await tester.startGesture(tester.getCenter(hold));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('إنت الغمّاز'), findsOneWidget);
    await pointer.up();
    await tester.pump();
    expect(find.text('إنت الغمّاز'), findsOneWidget);
    game.connected = false;
    game.notifyListeners();
    await tester.pump();
    expect(find.text('إنت الغمّاز'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('wink-hide-card')));
    await tester.tap(find.byKey(const ValueKey('wink-hide-card')));
    await tester.pump();
    expect(find.text('إنت الغمّاز'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  for (final lateReadFails in [false, true]) {
    testWidgets(
        'polling allows immediate actions and ignores stale reads ($lateReadFails)',
        (tester) async {
      var delayRead = false;
      var writes = 0;
      late Completer<http.Response> read;
      final game =
          WinkController(api: ApiClient.forTesting(MockClient((request) async {
        if (request.url.path.endsWith('/current')) {
          return http.Response('{"code":"ABCD1234"}', 200);
        }
        if (request.method == 'GET' && delayRead) return read.future;
        final data = fixture(phase: 'playing');
        if (request.method == 'POST') {
          writes++;
          (data['me'] as Map)['notice'] = 'winked';
        }
        return http.Response(jsonEncode(data), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      })));
      await tester.runAsync(() async {
        await game.start();
        read = Completer<http.Response>();
        delayRead = true;
        final refresh = game.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(game.canAct, isTrue);
        await game.action('got-wink');
        expect(writes, 1);
        expect(game.me['notice'], 'winked');
        if (lateReadFails) {
          read.completeError(Exception('late network failure'));
        } else {
          read.complete(http.Response(
              jsonEncode(fixture(phase: 'playing')), 200,
              headers: {'content-type': 'application/json; charset=utf-8'}));
        }
        await refresh;
        expect(game.me['notice'], 'winked');
        expect(game.canAct, isTrue);
        expect(game.errorCode, isNull);
      });
      game.dispose();
    });
  }
  testWidgets('hub and game fit narrow screens, RTL and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final phase in ['lobby', 'reveal', 'playing', 'voting', 'finished']) {
      final data = fixture(phase: phase);
      if (phase == 'voting')
        data['vote'] = {
          'accused': 'p1',
          'endsAt': DateTime.now().millisecondsSinceEpoch + 20000
        };
      if (phase == 'finished')
        data['result'] = {
          'winner': 'players',
          'winker': 'p0',
          'reason': 'time'
        };
      await mount(tester, DisplayGame(data), scale: 2);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: phase);
      await tester.pumpWidget(const SizedBox());
    }
    await mount(tester, DisplayGame(null), scale: 2, language: 'en');
    expect(find.text('Who is the winker?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'double tap sends one action; uncertain retry reuses operation ID',
      (tester) async {
    var fail = true;
    final operations = <String>[];
    late Completer<http.Response> pending;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/current'))
        return http.Response('{"code":"ABCD1234"}', 200);
      if (request.method == 'GET')
        return http.Response(jsonEncode(fixture(phase: 'playing')), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      operations
          .add((jsonDecode(request.body) as Map)['operationId'] as String);
      if (fail) return pending.future;
      return http.Response(jsonEncode(fixture(phase: 'playing')), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = ApiClient.forTesting(client);
    final game = WinkController(api: api);
    await tester.runAsync(game.start);
    expect(game.room, isNotNull, reason: 'startup: ${game.errorCode}');
    expect(game.canAct, isTrue, reason: 'startup connected: ${game.connected}');
    await tester.runAsync(() async {
      pending = Completer<http.Response>();
      final first = game.action('got-wink');
      await Future<void>.delayed(Duration.zero);
      await game.action('got-wink');
      pending.completeError(http.ClientException('offline'));
      await first;
    });
    expect(operations, hasLength(1));
    expect(game.connected, false);
    expect(game.canAct, false);
    fail = false;
    await tester.runAsync(game.refresh);
    expect(operations, hasLength(2));
    expect(operations[0], operations[1]);
    expect(game.connected, true);
    game.dispose();
  });
}
