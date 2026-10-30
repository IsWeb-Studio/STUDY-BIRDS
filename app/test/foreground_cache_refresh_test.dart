import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/realtime_sync_service.dart';
import 'package:study_birds/core/widgets/cached_resource.dart';
import 'package:study_birds/screens/games/wink_controller.dart';
import 'wink_game_test.dart' show fixture;
import 'persistent_response_cache_test.dart' show MemoryStore;

http.Response reply(Object data) => http.Response(jsonEncode(data), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() => AuthSession.instance.token = 'foreground-test');
  tearDown(() => AuthSession.instance.token = null);

  testWidgets(
      'returning to the idle game reuses its hub and checks quietly when stale',
      (tester) async {
    var now = DateTime.utc(2026, 10, 30);
    var calls = 0;
    final pending = Completer<http.Response>();
    final game = WinkController(
        clock: () => now,
        api: ApiClient.forTesting(MockClient((_) async {
          if (++calls == 1) return reply({'code': null});
          return pending.future;
        })));
    await game.start();
    expect(game.initialized, true);
    await game.refresh(force: false);
    await game.start();
    expect(calls, 1);
    expect(game.busy, false);
    now = now.add(const Duration(seconds: 16));
    final checking = game.refresh(force: false);
    var manualFinished = false;
    final manual = game.refresh().then((_) => manualFinished = true);
    expect(game.busy, false);
    expect(game.initialized, true);
    expect(game.canAct, true);
    expect(manualFinished, false);
    pending.complete(reply({'code': null}));
    await checking;
    await manual;
    expect(manualFinished, true);
    expect(calls, 2);
    game.dispose();
  });

  testWidgets(
      'a current-room read cannot overwrite a room created while it was in flight',
      (tester) async {
    var now = DateTime.utc(2026, 10, 30);
    var reads = 0;
    final pending = Completer<http.Response>();
    final game = WinkController(
        clock: () => now,
        api: ApiClient.forTesting(MockClient((request) async {
          if (request.method == 'POST') return reply(fixture(phase: 'lobby'));
          if (++reads == 1) return reply({'code': null});
          return pending.future;
        })));
    await game.start();
    now = now.add(const Duration(seconds: 16));
    final checking = game.refresh(force: false);
    await game.create();
    pending.complete(reply({'code': null}));
    await checking;
    expect(game.room?['code'], 'ABCD1234');
    game.dispose();
  });

  testWidgets('active rooms always refresh immediately on resume',
      (tester) async {
    var reads = 0;
    final game =
        WinkController(api: ApiClient.forTesting(MockClient((request) async {
      if (request.url.path.endsWith('/current')) return reply({'code': null});
      if (request.method == 'GET') reads++;
      return reply(fixture(phase: 'lobby'));
    })));
    await game.start();
    await game.create();
    game.didChangeAppLifecycleState(AppLifecycleState.paused);
    game.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, 1);
    expect(game.room, isNotNull);
    expect(game.busy, false);
    game.dispose();
  });

  test(
      'brief app switches do not trigger global reloads; long resumes and manual refresh do',
      () async {
    var now = DateTime.utc(2026, 10, 30);
    final sync = RealtimeSyncService.forTesting(clock: () => now);
    var ticks = 0;
    final sub = sync.onTick.listen((_) => ticks++);
    sync.start();
    sync.didChangeAppLifecycleState(AppLifecycleState.inactive);
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    sync.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 5));
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(ticks, 0);
    sync.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 30));
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(ticks, 1);
    sync.forceSync();
    sync.forceSync();
    await Future<void>.delayed(Duration.zero);
    expect(ticks, 3);
    sync.stop();
    await sub.cancel();
  });

  testWidgets('hidden tabs defer cache refresh until they become visible',
      (tester) async {
    final api = ApiClient.forTesting(MockClient((_) async => reply({})),
        cacheStore: MemoryStore());
    var selected = 0, first = 0, second = 0;
    late StateSetter update;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, set) {
      update = set;
      return IndexedStack(index: selected, children: [
        TickerMode(
            enabled: selected == 0,
            child: _CacheTab(api: api, onRefresh: () => first++)),
        TickerMode(
            enabled: selected == 1,
            child: _CacheTab(api: api, onRefresh: () => second++)),
      ]);
    })));
    api.invalidateResource('/universities');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(first, 1);
    expect(second, 0);
    update(() => selected = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(second, 1);
    await tester.pumpWidget(const SizedBox());
  });
}

class _CacheTab extends StatefulWidget {
  final ApiClient api;
  final VoidCallback onRefresh;
  const _CacheTab({required this.api, required this.onRefresh});
  @override
  State<_CacheTab> createState() => _CacheTabState();
}

class _CacheTabState extends State<_CacheTab> with CachedResource<_CacheTab> {
  @override
  ApiClient get resourceCacheClient => widget.api;
  @override
  Iterable<String> get cachedPaths => const ['/universities'];
  @override
  Future<void> reloadCachedResource() async => widget.onRefresh();
  @override
  Widget build(BuildContext context) => const Text('Saved page');
}
