// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/apple_sign_in_service.dart';
import 'package:study_birds/core/services/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() {
    SignInWithApple.channel.setMockMethodCallHandler(null);
    AuthSession.instance.currentUser = null;
    AuthSession.instance.token = null;
    AuthSession.instance.debugResetRestore();
  });
  test(
      'canceling native Apple does not create a session or verify a credential',
      () async {
    SignInWithApple.channel.setMockMethodCallHandler((call) async {
      if (call.method == 'isAvailable') return true;
      throw PlatformException(code: 'authorization-error/canceled');
    });
    final paths = <String>[];
    await http.runWithClient(() async {
      expect(await AppleSignInService.instance.signIn(), isFalse);
      expect(AuthSession.instance.currentUser, isNull);
      expect(paths.where((p) => p.endsWith('/verify')), isEmpty);
    },
        () => MockClient((r) async {
              paths.add(r.url.path);
              return http.Response(
                  '{"nonce":"nonce","challengeId":"challenge"}', 200,
                  headers: {'content-type': 'application/json'});
            }));
  });
  test(
      'native Apple sends nonce and state then creates a restorable passwordless session',
      () async {
    SignInWithApple.channel.setMockMethodCallHandler((call) async {
      if (call.method == 'isAvailable') return true;
      final request = (call.arguments as List).single as Map;
      expect(request['nonce'], 'server-nonce');
      expect(request['state'], 'server-challenge');
      return {
        'type': 'appleid',
        'identityToken': 'signed-token',
        'authorizationCode': 'auth-code',
        'userIdentifier': 'apple-id',
        'state': 'server-challenge',
        'givenName': 'Apple',
        'familyName': 'Student'
      };
    });
    final user = {
      '_id': 'apple-id',
      'name': 'Apple Student',
      'email': 'apple@example.test',
      'role': 'student',
      'authProvider': 'apple',
      'hasPassword': false,
      'emailVerified': true
    };
    await http.runWithClient(() async {
      expect(await AppleSignInService.instance.signIn(), isTrue);
      expect(AuthSession.instance.currentUser!.authProvider, 'apple');
      expect(AuthSession.instance.requiresGooglePasswordSetup, isFalse);
      AuthSession.instance.currentUser = null;
      AuthSession.instance.token = null;
      AuthSession.instance.debugResetRestore();
      await AuthSession.instance.restore();
      expect(AuthSession.instance.currentUser?.id, 'apple-id');
      expect(AuthSession.instance.currentUser?.hasPassword, isFalse);
      expect(AuthSession.instance.token, 'apple-access');
    },
        () => MockClient((request) async {
              Object data = {
                'user': user,
                'token': 'apple-access',
                'refreshToken': 'apple-refresh'
              };
              if (request.url.path.endsWith('/options'))
                data = {
                  'nonce': 'server-nonce',
                  'challengeId': 'server-challenge'
                };
              if (request.url.path.endsWith('/verify')) {
                final body = jsonDecode(request.body);
                expect(body['identityToken'], 'signed-token');
                expect(body['challengeId'], 'server-challenge');
                expect(body['name'], 'Apple Student');
              }
              return http.Response(jsonEncode(data), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
