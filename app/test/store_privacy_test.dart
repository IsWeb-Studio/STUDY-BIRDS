import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/analytics_service.dart';
import 'package:study_birds/core/widgets/ai_consent.dart';
import 'package:study_birds/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/widgets/community_terms.dart';

void main() {
  test('blocking clears scoped feed and inbox caches and rejects older replies',
      () async {
    final api =
        ApiClient.forTesting(MockClient((_) async => http.Response('{}', 200)));
    const key = '/mobile-workspace/conversations?community=1';
    api.rememberSnapshot(key, {'private': true}, token: 'account');
    final version = api.snapshotVersion;
    await api.put('/safety/blocks/peer', token: 'account');
    expect(api.snapshot(key, token: 'account'), isNull);
    api.rememberSnapshot(key, {'stale': true},
        token: 'account', version: version);
    expect(api.snapshot(key, token: 'account'), isNull);
  });

  testWidgets(
      'community publishing requires explicit acceptance and remembers it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    bool? accepted;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      accepted = await requireCommunityTerms(context);
                    },
                    child: const Text('Publish'))))));
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    expect(accepted, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree to community rules'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    expect(find.text('Agree to community rules'), findsNothing);
  });
  test('analytics cannot initialize without explicit opt-in, even with a key',
      () async {
    SharedPreferences.setMockInitialValues({});
    await AnalyticsService.instance.init();
    expect(await AnalyticsService.instance.getConsent(), isFalse);
    expect(AnalyticsService.instance.consented, isFalse);
    await AnalyticsService.instance.track('private_event');
  });

  for (final accept in [false, true]) {
    testWidgets('assistant consent returns $accept without submitting data',
        (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result = await requestAiConsent(context);
                      },
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.textContaining('external AI provider'), findsOneWidget);
      await tester.tap(find.text(accept ? 'Agree and continue' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, accept);
    });
  }
}
