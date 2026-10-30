import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:study_birds/core/services/response_cache.dart';

class MemoryStore implements ResponseCacheStore {
  final values = <String, CachedResponse>{};
  @override
  Future<CachedResponse?> read(String scope, String key) async =>
      values['$scope|$key'];
  @override
  Future<void> write(String scope, String key, CachedResponse value) async {
    values['$scope|$key'] =
        CachedResponse(jsonDecode(jsonEncode(value.data)), value.savedAt);
  }

  @override
  Future<void> invalidate(String scope, bool Function(String) matches) async {
    values.removeWhere((key, _) =>
        key.startsWith('$scope|') && matches(key.substring(scope.length + 1)));
  }

  @override
  Future<void> clearPrivate() async =>
      values.removeWhere((key, _) => !key.startsWith('public|'));
}

http.Response jsonReply(Object data, {Map<String, String>? headers}) =>
    http.Response(jsonEncode(data), 200,
        headers: {'content-type': 'application/json', ...?headers});

void main() {
  test(
      'public data survives a new client/process and is returned before network',
      () async {
    final store = MemoryStore();
    final first = ApiClient.forTesting(
        MockClient((_) async => jsonReply([
              {'name': 'Saved university'}
            ])),
        cacheStore: store);
    await first.get('/universities');
    var requests = 0;
    final background = Completer<void>();
    final restarted = ApiClient.forTesting(MockClient((_) async {
      requests++;
      await background.future;
      return jsonReply([{'name':'Saved university'}]);
    }), cacheStore: store);
    expect(
        (await restarted.get('/universities'))[0]['name'], 'Saved university');
    expect(requests, lessThanOrEqualTo(1));
    background.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test(
      'stale data renders immediately and a single background fetch updates listeners',
      () async {
    final store = MemoryStore();
    var now = DateTime.utc(2026, 10, 30);
    final first = ApiClient.forTesting(
        MockClient((_) async => jsonReply({'name': 'Old'})),
        cacheStore: store,
        clock: () => now);
    await first.get('/universities/one');
    now = now.add(const Duration(hours: 1));
    final pending = Completer<http.Response>();
    var count = 0;
    final restarted = ApiClient.forTesting(MockClient((_) {
      count++;
      return pending.future;
    }), cacheStore: store, clock: () => now);
    final changes = <String>[];
    final sub = restarted.cacheChanges.listen(changes.add);
    expect((await restarted.get('/universities/one'))['name'], 'Old');
    expect((await restarted.get('/universities/one'))['name'], 'Old');
    await Future<void>.delayed(Duration.zero);
    expect(count, 1);
    pending.complete(jsonReply({'name': 'New'}));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect((await restarted.get('/universities/one'))['name'], 'New');
    expect(changes, ['/universities/one']);
    await sub.cancel();
  });

  test(
      'private summaries survive token rotation but never cross account boundaries',
      () async {
    final store = MemoryStore();
    final a = ApiClient.forTesting(
        MockClient((_) async => jsonReply({'student': 'Alice'})),
        cacheStore: store);
    a.cacheOwnerForToken = (_) => 'alice:student';
    await a.get('/students/overview', token: 'old-token');
    final pending = Completer<http.Response>();
    final restarted = ApiClient.forTesting(MockClient((_) => pending.future),
        cacheStore: store);
    restarted.cacheOwnerForToken =
        (token) => token == 'rotated' ? 'alice:student' : 'bob:student';
    expect(
        (await restarted.get('/students/overview',
            token: 'rotated'))['student'],
        'Alice');
    var bobCompleted = false;
    final bob = restarted.get('/students/overview', token: 'bob').then((v) {
      bobCompleted = true;
      return v;
    });
    await Future<void>.delayed(Duration.zero);
    expect(bobCompleted, false);
    pending.complete(jsonReply({'student': 'Verified'}));
    expect((await bob)['student'], 'Verified');
  });

  test(
      'money, access, permissions, slots and game state never read persistent cache',
      () async {
    for (final path in [
      '/students/financials',
      '/parents/children/id/payments',
      '/partners/wallet',
      '/mobile-security/sessions',
      '/auth/me',
      '/documents/id/access',
      '/consultations/slots',
      '/games/wink/current',
      '/assistant/config'
    ]) {
      final store = MemoryStore();
      var count = 0;
      final api = ApiClient.forTesting(MockClient((_) async {
        count++;
        return jsonReply({'value': count});
      }), cacheStore: store);
      api.cacheOwnerForToken = (_) => 'alice';
      await api.get(path, token: 'token');
      await api.get(path, token: 'token');
      expect(count, 2, reason: path);
      expect(store.values, isEmpty, reason: path);
    }
  });

  test('no-store response is not retained in memory or disk', () async {
    final store = MemoryStore();
    var count = 0;
    final api = ApiClient.forTesting(MockClient((_) async {
      count++;
      return jsonReply({'value': count},
          headers: {'cache-control': 'private, no-store'});
    }), cacheStore: store);
    await api.get('/universities');
    await api.get('/universities');
    expect(count, 2);
    expect(store.values, isEmpty);
  });

  test('cached:false fetches live and replaces a saved public response',
      () async {
    final store = MemoryStore();
    var count = 0;
    final api = ApiClient.forTesting(
        MockClient((_) async => jsonReply({'value': ++count})),
        cacheStore: store);
    expect((await api.get('/programs'))['value'], 1);
    expect((await api.get('/programs', cached: false))['value'], 2);
    expect((await api.get('/programs'))['value'], 2);
  });

  test('mutation invalidates dependent summaries but preserves public catalog',
      () async {
    final store = MemoryStore();
    var reads = 0;
    final api = ApiClient.forTesting(
        MockClient((request) async =>
            jsonReply({'value': request.method == 'GET' ? ++reads : 0})),
        cacheStore: store);
    api.cacheOwnerForToken = (_) => 'alice';
    await api.get('/universities');
    await api.get('/students/applications', token: 't');
    await api.post('/students/documents', token: 't', body: {});
    expect((await api.get('/universities'))['value'], 1);
    expect((await api.get('/students/applications', token: 't'))['value'], 3);
  });

  test(
      'response started before logout cannot refill disk and other account has no hit',
      () async {
    final store = MemoryStore();
    final pending = Completer<http.Response>();
    final api = ApiClient.forTesting(MockClient((_) => pending.future),
        cacheStore: store);
    String? owner = 'alice';
    api.cacheOwnerForToken = (_) => owner;
    final old = api.get('/students/overview', token: 'old');
    await Future<void>.delayed(Duration.zero);
    owner = null;
    await api.clearPrivateCache();
    pending.complete(jsonReply({'secret': 'Alice'}));
    await old;
    expect(store.values, isEmpty);
  });

  test('old request cannot refill cache after a mutation', () async {
    final store = MemoryStore();
    final pending = Completer<http.Response>();
    var reads = 0;
    final api = ApiClient.forTesting(MockClient((r) async {
      if (r.method != 'GET') return jsonReply({});
      if (++reads == 1) return pending.future;
      return jsonReply({'value': 'new'});
    }), cacheStore: store);
    final old = api.get('/programs');
    await Future<void>.delayed(Duration.zero);
    await api.patch('/admin/programs/one', body: {});
    pending.complete(jsonReply({'value': 'old'}));
    await old;
    expect((await api.get('/programs'))['value'], 'new');
  });

  test('returned maps cannot mutate a stored response', () async {
    final api = ApiClient.forTesting(
        MockClient((_) async => jsonReply({'name': 'Correct'})),
        cacheStore: MemoryStore());
    final value = await api.get('/universities/one');
    value['name'] = 'Changed externally';
    expect((await api.get('/universities/one'))['name'], 'Correct');
  });

  test('expired and future-dated records are never displayed', () async {
    final store = MemoryStore();
    var now = DateTime.utc(2026, 10, 30);
    final api = ApiClient.forTesting(
        MockClient((_) async => jsonReply({'at': now.toIso8601String()})),
        cacheStore: store,
        clock: () => now);
    await api.get('/universities');
    now = now.add(const Duration(days: 2));
    final newApi = ApiClient.forTesting(
        MockClient((_) async => jsonReply({'fresh': true})),
        cacheStore: store,
        clock: () => now);
    expect((await newApi.get('/universities'))['fresh'], true);
    expect(
        CachedResponse({}, now.add(const Duration(days: 1)))
            .valid(const Duration(days: 7), now),
        false);
  });
}
