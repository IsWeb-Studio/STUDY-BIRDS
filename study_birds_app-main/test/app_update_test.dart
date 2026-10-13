import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/app_update_service.dart';
import 'package:study_birds/core/widgets/update_gate.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

const policy = {
  'minVersion': {'android': '2.1.0', 'ios': '2.0.5'},
  'storeUrl': {'android': 'https://play.example/app', 'ios': 'https://apps.example/app'},
  'message': 'حدّث من فضلك',
};

void main() {
  group('version comparison', () {
    test('compares numerically, not as text', () {
      expect(AppUpdateService.compareVersions('1.10.0', '1.9.9'), 1);
      expect(AppUpdateService.compareVersions('1.2.0', '1.2'), 0);
      expect(AppUpdateService.compareVersions('1.0.9', '1.1.0'), -1);
      expect(AppUpdateService.compareVersions('2.0.0+45', '2.0.0'), 0,
          reason: 'build number is ignored');
      expect(AppUpdateService.compareVersions('2.0.0-beta', '2.0.0'), 0);
    });
  });

  group('policy', () {
    UpdateRequirement? run(String installed, dynamic config,
            [TargetPlatform p = TargetPlatform.android]) =>
        AppUpdateService.evaluate(installed: installed, config: config, platform: p);

    test('older than the minimum -> update required, with store link', () {
      final r = run('2.0.0', policy)!;
      expect(r.storeUrl, 'https://play.example/app');
      expect(r.message, 'حدّث من فضلك');
    });

    test('equal or newer -> no restriction', () {
      expect(run('2.1.0', policy), isNull);
      expect(run('3.0.0', policy), isNull);
    });

    test('uses the platform-specific minimum', () {
      expect(run('2.0.5', policy, TargetPlatform.iOS), isNull);
      expect(run('2.0.4', policy, TargetPlatform.iOS), isNotNull);
    });

    test('no policy / garbage / unsupported platform never blocks anyone', () {
      expect(run('0.0.1', null), isNull);
      expect(run('0.0.1', 'oops'), isNull);
      expect(run('0.0.1', {'minVersion': {'android': null}}), isNull);
      expect(run('0.0.1', {'minVersion': {'android': ''}}), isNull);
      expect(run('0.0.1', {'minVersion': 5}), isNull);
      expect(run('0.0.1', policy, TargetPlatform.windows), isNull);
    });

    test('a missing message falls back to the default text', () {
      final r = run('1.0.0', {
        'minVersion': {'android': '9.0.0'}
      })!;
      expect(r.message, AppUpdateService.defaultMessage);
      expect(r.storeUrl, isNull);
    });
  });

  group('service', () {
    test('an old install becomes "required"; check never throws when offline',
        () async {
      final service = AppUpdateService(installedVersion: () async => '2.0.0');
      await http.runWithClient(() async {
        await service.check(platform: TargetPlatform.android);
      }, () => MockClient((r) async => json(policy)));
      expect(service.required, isNotNull);

      final offline = AppUpdateService(installedVersion: () async => '1.0.0');
      await http.runWithClient(() async {
        await offline.check(platform: TargetPlatform.android);
      }, () => MockClient((r) async => throw http.ClientException('offline')));
      expect(offline.required, isNull, reason: 'offline must not lock anyone out');

      final old = AppUpdateService(installedVersion: () async => '1.0.0');
      await http.runWithClient(() async {
        await old.check(platform: TargetPlatform.android);
      }, () => MockClient((r) async => json({'message': 'not found'}, 404)));
      expect(old.required, isNull, reason: 'older server without the endpoint');
    });

    test('recovers when the policy is relaxed', () async {
      final service = AppUpdateService(installedVersion: () async => '2.0.0');
      var relaxed = false;
      await http.runWithClient(() async {
        await service.check(platform: TargetPlatform.android);
        expect(service.required, isNotNull);
        relaxed = true;
        await service.check(platform: TargetPlatform.android);
      }, () => MockClient((r) async => json(relaxed ? {'minVersion': {}} : policy)));
      expect(service.required, isNull);
    });
  });

  testWidgets('the gate shows the app normally, and a blocking page when required',
      (tester) async {
    final service = AppUpdateService(installedVersion: () async => '2.0.0');
    await tester.pumpWidget(MaterialApp(
        home: UpdateGate(service: service, child: const Text('the app'))));
    expect(find.text('the app'), findsOneWidget);

    await http.runWithClient(() async {
      await service.check(platform: TargetPlatform.android);
    }, () => MockClient((r) async => json(policy)));
    await tester.pump();
    expect(find.text('the app'), findsNothing);
    expect(find.text('تحديث مطلوب'), findsOneWidget);
    expect(find.text('حدّث من فضلك'), findsOneWidget);
    expect(find.text('تحديث الآن'), findsOneWidget);
  });
}
