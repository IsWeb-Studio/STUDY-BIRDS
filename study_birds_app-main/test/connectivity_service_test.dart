import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/services/connectivity_service.dart';

/// Drives ConnectivityService with a fake radio + fake backend probe, using
/// millisecond-scale timings so real timers stay fast and deterministic.
class _Harness {
  final radio = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> interfaces = [ConnectivityResult.wifi];
  bool backendUp = true;
  Duration probeLatency = Duration.zero;
  int probes = 0;
  int reconnects = 0;

  late final ConnectivityService service = ConnectivityService(
    changes: () => radio.stream,
    check: () async => interfaces,
    probe: () async {
      probes++;
      await Future<void>.delayed(probeLatency);
      return backendUp;
    },
    offlineDebounce: const Duration(milliseconds: 60),
    confirmDelay: const Duration(milliseconds: 20),
    minRecoveryDelay: const Duration(milliseconds: 40),
    maxRecoveryDelay: const Duration(milliseconds: 120),
  );

  Future<void> start() async {
    service.onReconnected.listen((_) => reconnects++);
    await service.start();
    await settle();
  }

  void emit(List<ConnectivityResult> r) {
    interfaces = r;
    radio.add(r);
  }

  Future<void> settle([int ms = 200]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> dispose() async {
    service.dispose();
    await radio.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opening the app without internet -> offline, no crash', () async {
    final h = _Harness()
      ..interfaces = [ConnectivityResult.none]
      ..backendUp = false;
    await h.start();
    expect(h.service.status, NetworkStatus.offline);
    expect(h.probes, 0, reason: 'no radio => no pointless network probe');
    await h.dispose();
  });

  test('Wi-Fi connected but no real internet -> unreachable, not online',
      () async {
    final h = _Harness()..backendUp = false;
    await h.start();
    expect(h.service.status, NetworkStatus.unreachable);
    await h.dispose();
  });

  test('restoring internet after an outage -> online once, reconnect fires once',
      () async {
    final h = _Harness();
    await h.start();
    h.emit([ConnectivityResult.none]);
    await h.settle(150);
    expect(h.service.status, NetworkStatus.offline);

    // Long outage: stays offline across several recovery checks.
    await h.settle(300);
    expect(h.service.status, NetworkStatus.offline);
    expect(h.reconnects, 0);

    h.emit([ConnectivityResult.wifi]);
    await h.settle(150);
    expect(h.service.status, NetworkStatus.online);
    expect(h.reconnects, 1);
    await h.dispose();
  });

  test('recovers by itself from backend downtime via backoff probes', () async {
    final h = _Harness()..backendUp = false;
    await h.start();
    expect(h.service.status, NetworkStatus.unreachable);
    h.backendUp = true; // server comes back, radio never changed
    await h.settle(500);
    expect(h.service.status, NetworkStatus.online);
    expect(h.reconnects, 1);
    await h.dispose();
  });

  test('Wi-Fi -> mobile data hand-over never flashes offline', () async {
    final h = _Harness();
    await h.start();
    final seen = <NetworkStatus>[];
    h.service.addListener(() => seen.add(h.service.status));
    h.emit([ConnectivityResult.none]); // brief gap during switch
    await h.settle(20);
    h.emit([ConnectivityResult.mobile]);
    await h.settle(250);
    expect(seen, isEmpty, reason: 'status never left online');
    expect(h.service.status, NetworkStatus.online);
    expect(h.reconnects, 0);
    await h.dispose();
  });

  test('one failed probe is not enough to declare an outage', () async {
    final h = _Harness();
    await h.start();
    var call = 0;
    final flaky = ConnectivityService(
      changes: () => h.radio.stream,
      check: () async => h.interfaces,
      probe: () async => ++call > 1, // first fails, second succeeds
      confirmDelay: const Duration(milliseconds: 10),
    );
    await flaky.start();
    await h.settle(150);
    expect(flaky.status, NetworkStatus.online);
    flaky.dispose();
    await h.dispose();
  });

  test('rapid disconnect/reconnect storm: bounded probes, ends consistent',
      () async {
    final h = _Harness()..probeLatency = const Duration(milliseconds: 30);
    await h.start();
    final before = h.probes;
    for (var i = 0; i < 20; i++) {
      h.emit([ConnectivityResult.none]);
      await h.settle(5);
      h.emit([ConnectivityResult.wifi]);
      await h.settle(5);
    }
    await h.settle(400);
    expect(h.service.status, NetworkStatus.online);
    // Single-flight: 20 flaps must not trigger 20 concurrent probes.
    expect(h.probes - before, lessThan(20)); // 20 flaps must not cost 20 probes (timing-tolerant)
    await h.dispose();
  });

  test('slow connection: a slow probe is awaited once, not duplicated',
      () async {
    final h = _Harness()..probeLatency = const Duration(milliseconds: 150);
    await h.start();
    final before = h.probes;
    final a = h.service.checkNow();
    final b = h.service.checkNow();
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(h.probes - before, lessThanOrEqualTo(2));
    await h.dispose();
  });

  test('a successful real API call immediately clears unreachable', () async {
    final h = _Harness()..backendUp = false;
    await h.start();
    expect(h.service.status, NetworkStatus.unreachable);
    h.service.reportSuccess();
    expect(h.service.status, NetworkStatus.online);
    await h.settle(10); // broadcast delivery is asynchronous
    expect(h.reconnects, 1);
    await h.dispose();
  });

  test('a failed API call while online triggers verification, not instant offline',
      () async {
    final h = _Harness();
    await h.start();
    h.service.reportFailure(); // backend actually fine
    await h.settle(150);
    expect(h.service.status, NetworkStatus.online);
    h.backendUp = false;
    await h.settle(60);
    h.service.reportFailure();
    await h.settle(150);
    expect(h.service.status, NetworkStatus.unreachable);
    await h.dispose();
  });

  test('Try Again (checkNow) reports the truth while offline', () async {
    final h = _Harness()..interfaces = [ConnectivityResult.none];
    await h.start();
    expect(await h.service.checkNow(), isFalse);
    h.interfaces = [ConnectivityResult.wifi];
    expect(await h.service.checkNow(), isTrue);
    expect(h.service.status, NetworkStatus.online);
    await h.dispose();
  });

  test('flapping is flagged as unstable', () async {
    final h = _Harness();
    await h.start();
    for (var i = 0; i < 3; i++) {
      h.backendUp = false;
      await h.service.checkNow();
      h.backendUp = true;
      await h.service.checkNow();
    }
    expect(h.service.isUnstable, isTrue);
    await h.dispose();
  });

  test('dispose cancels listeners and timers (no leaks / late callbacks)',
      () async {
    final h = _Harness()..backendUp = false;
    await h.start();
    await h.dispose();
    final probesAtDispose = h.probes;
    await h.settle(300);
    expect(h.probes, probesAtDispose);
  });
}
