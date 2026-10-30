import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/ai/assistant_navigation.dart';
import 'package:study_birds/screens/ai/birds_ai_screen.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthSession.instance.token = 'synthetic-token';
    AuthSession.instance.currentUser = const AuthUser(
        id: 'synthetic',
        name: 'Student',
        email: 'student@example.test',
        role: UserRole.student);
  });
  tearDown(() {
    AuthSession.instance.token = null;
    AuthSession.instance.currentUser = null;
  });
  test(
      'every shortcut is an existing screen and requires current version plus student role',
      () {
    for (final id in AssistantNavigation.ids) {
      expect(AssistantNavigation.labels[id]?.length, 2, reason: id);
      expect(AssistantNavigation.destination(id), isNotNull, reason: id);
      expect(
          AssistantNavigation.allowed(
              id, UserRole.student, AssistantNavigation.knowledgeVersion),
          isTrue);
      expect(
          AssistantNavigation.allowed(
              id, UserRole.admin, AssistantNavigation.knowledgeVersion),
          isFalse);
      expect(
          AssistantNavigation.allowed(id, UserRole.student, 'stale'), isFalse);
    }
    expect(AssistantNavigation.destination('https://evil.example'), isNull);
    expect(
        AssistantNavigation.allowed(
            'admin', UserRole.student, AssistantNavigation.knowledgeVersion),
        isFalse);
    final context = AssistantNavigation.context('documents', 'en');
    expect(context['knowledgeRevision'], AssistantNavigation.knowledgeRevision);
    expect(context.containsKey('userId'), isFalse);
    expect(context.containsKey('role'), isFalse);
  });
  testWidgets(
      'allowlisted navigation opens actual documents and screen-specific help',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: AssistantActions(
                  version: AssistantNavigation.knowledgeVersion,
                  actions: [
            {'id': 'documents'},
            {'id': '/admin'},
            {'id': 'delete-account'}
          ]))));
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assistant-open-documents')));
      await tester.pumpAndSettle();
      expect(find.byType(MyDocumentsScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();
      expect(
          tester.widget<BirdsAiScreen>(find.byType(BirdsAiScreen)).originScreen,
          'documents');
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
  testWidgets(
      'stale actions do not render and provider errors offer explicit retry',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AssistantActions(version: 'stale', actions: [
      {'id': 'documents'}
    ]))));
    expect(find.byType(OutlinedButton), findsNothing);
    var attempts = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: BirdsAiScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How do I upload documents?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/message')) {
                attempts++;
                return http.Response('{"message":"Service unavailable"}', 503,
                    headers: {'content-type': 'application/json'});
              }
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
}
