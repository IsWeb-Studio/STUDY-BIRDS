import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/utils/notification_links.dart';

const _queueKey = 'pending_refresh_revocations';

void main() {
  const storage = FlutterSecureStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('sign-out while offline', () {
    test('the refresh token is queued for revocation, local session is gone',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'active_session_token': 'access',
        'refresh_token': 'refresh-1',
      });
      await http.runWithClient(() async {
        await AuthSession.instance.logout();
      }, () => MockClient((r) async => throw http.ClientException('offline')));
      expect(await storage.read(key: 'active_session_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
      expect(await storage.read(key: _queueKey), 'refresh-1');
    });

    test('a normal online sign-out queues nothing', () async {
      FlutterSecureStorage.setMockInitialValues({'refresh_token': 'r'});
      await http.runWithClient(() async {
        await AuthSession.instance.logout();
      }, () => MockClient((r) async => http.Response('{}', 200)));
      expect(await storage.read(key: _queueKey), isNull);
    });

    test('flush revokes queued tokens once the server is reachable', () async {
      FlutterSecureStorage.setMockInitialValues({_queueKey: 'a\nb'});
      final revoked = <String>[];
      await http.runWithClient(() async {
        await AuthSession.instance.flushPendingRevocations();
      }, () => MockClient((r) async {
            revoked.add(r.body);
            return http.Response('{}', 200);
          }));
      expect(revoked.length, 2);
      expect(revoked.first, contains('"a"'));
      expect(await storage.read(key: _queueKey), isNull);
    });

    test('flush keeps tokens while the server is still unreachable or down',
        () async {
      FlutterSecureStorage.setMockInitialValues({_queueKey: 'a\nb'});
      var n = 0;
      await http.runWithClient(() async {
        await AuthSession.instance.flushPendingRevocations();
      }, () => MockClient((r) async {
            n++;
            if (n == 1) throw http.ClientException('still offline');
            return http.Response('{}', 503);
          }));
      expect(await storage.read(key: _queueKey), 'a\nb');
    });

    test('a token the server already rejects (401) is dropped, not retried forever',
        () async {
      FlutterSecureStorage.setMockInitialValues({_queueKey: 'dead'});
      await http.runWithClient(() async {
        await AuthSession.instance.flushPendingRevocations();
      }, () => MockClient((r) async => http.Response('{"message":"x"}', 401)));
      expect(await storage.read(key: _queueKey), isNull);
    });

    test('the queue is bounded', () async {
      for (var i = 0; i < 8; i++) {
        FlutterSecureStorage.setMockInitialValues({
          'refresh_token': 'r$i',
          if (i > 0) _queueKey: await storage.read(key: _queueKey) ?? '',
        });
        await http.runWithClient(() async {
          await AuthSession.instance.logout();
        }, () => MockClient((r) async => throw http.ClientException('x')));
        // carry the queue to the next round
        final q = await storage.read(key: _queueKey);
        FlutterSecureStorage.setMockInitialValues({_queueKey: q ?? ''});
      }
      final q = (await storage.read(key: _queueKey)) ?? '';
      expect(q.split('\n').where((t) => t.isNotEmpty).length, lessThanOrEqualTo(5));
    });
  });

  test('legacy plain-text caches are wiped at startup', () async {
    SharedPreferences.setMockInitialValues({
      'sb_overview_cache': '{"secret":1}',
      'sb_docs_cache': '[]',
      'keep_me': 'x',
    });
    AuthSession.instance.debugResetRestore();
    await AuthSession.instance.restore();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('sb_overview_cache'), isFalse);
    expect(prefs.containsKey('sb_docs_cache'), isFalse);
    expect(prefs.getString('keep_me'), 'x');
  });

  group('deep links', () {
    test('only the app domains and student paths are accepted', () {
      expect(notificationPath('studybirds://student/applications'),
          '/student/applications');
      expect(notificationPath('https://studybirds.app/student/documents'),
          '/student/documents');
      expect(notificationPath('https://evil.example/student/documents'), isNull);
      expect(notificationPath('https://studybirds.app.evil.example/student/x'),
          isNull);
      expect(notificationPath('studybirds://admin/users'), isNull);
      expect(notificationPath('javascript:alert(1)'), isNull);
    });
  });

  group('Android manifest', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    test('cloud backup / device transfer cannot carry app data', () {
      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
      final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
      expect(rules, contains('<cloud-backup>'));
      expect(rules, contains('<device-transfer>'));
      expect(rules, contains('domain="sharedpref"'));
    });
  });
}
