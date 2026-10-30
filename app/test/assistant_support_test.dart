import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/ai/birds_ai_screen.dart';
import 'package:study_birds/screens/ai/assistant_navigation.dart';
import 'package:study_birds/screens/services_support/bird_ai_screen.dart';

void main() {
  const fixturePath = String.fromEnvironment('ASSISTANT_CONTRACT_FIXTURE');
  final response = fixturePath.isEmpty
      ? {
          'threadId': 'synthetic-thread',
          'scopePolicy': 'studybirds-only-v1',
          'responseFormat': 'verified-help-v1',
          'knowledgeVersion': AssistantNavigation.knowledgeVersion,
          'messages': [
            {
              'role': 'assistant',
              'content': 'Open your documents to manage files.',
              'details':
                  'Choose Upload document, select its type and camera or file, then review the result.',
              'knowledgeVersion': AssistantNavigation.knowledgeVersion
            }
          ]
        }
      : jsonDecode(File(fixturePath).readAsStringSync()) as Map;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AuthSession.instance.token = 'synthetic-assistant-token';
  });
  tearDown(() {
    AuthSession.instance.token = null;
  });
  for (final legacy in [false, true]) {
    testWidgets(
        'approved backend reply expands locally and renders in ${legacy ? 'support' : 'main'} assistant',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var requests = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
            theme: ThemeData.dark(),
            home: legacy
                ? const BirdAssistantScreen()
                : const BirdsAiScreen(originScreen: 'explore')));
        await tester.pumpAndSettle();
        expect(find.text('How do I upload documents?'), findsOneWidget);
        await tester.tap(find.text('How do I upload documents?'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agree and continue'));
        await tester.pumpAndSettle();
        expect(
            find.text((response['messages'] as List).last['content'] as String),
            findsOneWidget);
        if ((response['messages'] as List).last['details'] != null) {
          expect(find.text('Explain More'), findsOneWidget);
          final before = requests;
          await tester.tap(find.text('Explain More'));
          await tester.pumpAndSettle();
          expect(
              find.text(
                  (response['messages'] as List).last['details'] as String),
              findsOneWidget);
          expect(
              find.text(
                  (response['messages'] as List).last['content'] as String),
              findsNothing);
          expect(requests, before);
          await tester.tap(find.text('Show less'));
          await tester.pumpAndSettle();
          expect(requests, before);
        }
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests++;
                dynamic data;
                if (request.url.path.endsWith('/message')) {
                  final body = jsonDecode(request.body) as Map;
                  expect(body['screen'], legacy ? 'assistant' : 'explore');
                  expect(body['message'], 'How do I upload documents?');
                  expect(request.headers['Authorization'],
                      'Bearer synthetic-assistant-token');
                  data = response;
                } else if (request.url.path.endsWith('/config')) {
                  data = {
                    'enabled': true,
                    'scopePolicy': 'studybirds-only-v1',
                    'responseFormat': 'verified-help-v1',
                    'knowledgeVersion': AssistantNavigation.knowledgeVersion
                  };
                } else if (request.url.path.endsWith('/suggested-questions')) {
                  data = ['How do I upload documents?'];
                } else {
                  data = [];
                }
                return http.Response(jsonEncode(data), 200, headers: {
                  'content-type': 'application/json; charset=utf-8'
                });
              }));
    });
  }
  testWidgets(
      'old general backend contract is refused before sending a message',
      (tester) async {
    var messageRequests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: BirdsAiScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('service needs an update'), findsOneWidget);
      expect(find.textContaining('Sign in again'), findsNothing);
      expect(messageRequests, 0);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/message')) messageRequests++;
              return http.Response(
                  jsonEncode(request.url.path.endsWith('/config')
                      ? {'enabled': true}
                      : []),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets('logout clears messages and discards in-flight reply',
      (tester) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: BirdsAiScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How do I upload documents?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and continue'));
      await tester.pump();
      final logout = AuthSession.instance.logout(revoke: false);
      await tester.pump();
      await tester.runAsync(() => logout);
      pending.complete(http.Response(jsonEncode(response), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      await tester.pumpAndSettle();
      expect(
          find.text((response['messages'] as List).last['content'] as String),
          findsNothing);
      expect(find.text('How do I upload documents?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/message')) return pending.future;
              return http.Response(
                  jsonEncode(request.url.path.endsWith('/config')
                      ? {
                          'enabled': true,
                          'scopePolicy': 'studybirds-only-v1',
                          'responseFormat': 'verified-help-v1',
                          'knowledgeVersion':
                              AssistantNavigation.knowledgeVersion
                        }
                      : ['How do I upload documents?']),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
  testWidgets('Arabic support introduction fits a phone and uses RTL',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          home: BirdsAiScreen()));
      await tester.pumpAndSettle();
      final heading = find.text('مساعد COVEY');
      expect(heading, findsOneWidget);
      expect(Directionality.of(tester.element(heading)), TextDirection.rtl);
      expect(find.textContaining('مختص بالتطبيق فقط'), findsOneWidget);
      expect(find.byTooltip('مركز الدعم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async => http.Response(
            jsonEncode(request.url.path.endsWith('/config')
                ? {
                    'enabled': true,
                    'scopePolicy': 'studybirds-only-v1',
                    'responseFormat': 'verified-help-v1',
                    'knowledgeVersion': AssistantNavigation.knowledgeVersion
                  }
                : []),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
