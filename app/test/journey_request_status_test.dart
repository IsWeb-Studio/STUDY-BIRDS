import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/services/realtime_sync_service.dart';
import 'package:study_birds/screens/home_journey/journey_requirements_view.dart';
import 'package:study_birds/screens/home_journey/journey_tracker_screen.dart';

void main() {
  testWidgets('refresh keeps content, skips hidden tabs and deduplicates requests', (tester) async {
    AuthSession.instance.token = 'test';
    addTearDown(() => AuthSession.instance.token = null);
    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    var calls = 0;
    Completer<http.Response>? pending;
    http.Response response(String status) => http.Response(jsonEncode({
      'journeys': [{'applicationId': 'a', 'applicationStatus': status, 'stages': []}],
    }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: ValueListenableBuilder<bool>(
        valueListenable: active,
        builder: (_, visible, __) => LiveJourneyScreen(isActive: visible),
      )));
      await tester.pumpAndSettle();
      expect(find.text('طلبك قيد الانتظار'), findsOneWidget);
      expect(calls, 1);
      pending = Completer<http.Response>();
      RealtimeSyncService.instance.forceSync();
      await tester.pump();
      RealtimeSyncService.instance.forceSync();
      await tester.pump();
      expect(calls, 2);
      expect(find.text('طلبك قيد الانتظار'), findsOneWidget);
      pending!.complete(response('under-review'));
      await tester.pumpAndSettle();
      expect(find.text('طلبك قيد المراجعة'), findsOneWidget);
      active.value = false;
      await tester.pump();
      RealtimeSyncService.instance.forceSync();
      await tester.pump();
      expect(calls, 2);
      pending = null;
      active.value = true;
      await tester.pumpAndSettle();
      expect(calls, 3);
      final navigator = Navigator.of(tester.element(find.byType(LiveJourneyScreen)));
      unawaited(navigator.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Other page')))));
      await tester.pumpAndSettle();
      RealtimeSyncService.instance.forceSync();
      await tester.pump();
      expect(calls, 3);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(calls, 4);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      RealtimeSyncService.instance.forceSync();
      await tester.pump();
      expect(calls, 4);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, 5);
      pending = Completer<http.Response>();
      RealtimeSyncService.instance.forceSync();
      await tester.pump();
      pending!.complete(http.Response('Unavailable', 503));
      await tester.pumpAndSettle();
      expect(find.text('طلبك قيد الانتظار'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) {
      calls++;
      return pending?.future ?? Future.value(response('submitted'));
    }));
  });

  for (final entry in {
    'submitted': 'طلبك قيد الانتظار',
    'under-review': 'طلبك قيد المراجعة',
    'draft': 'طلبك بحاجة إلى استكمال',
    'additional-documents-required': 'مطلوب استكمال المستندات',
  }.entries) {
    testWidgets('journey explains ${entry.key} before team approval', (tester) async {
      await tester.pumpWidget(MaterialApp(home: JourneyRequirementsView(
        onRefresh: () async {},
        journeys: [{'applicationStatus': entry.key, 'stages': []}],
      )));
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('لم تبدأ رحلة تقديم بعد'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('accepted request does not keep the pending message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      JourneyRequestStatusCard(journey: {'applicationStatus': 'accepted'}))));
    expect(find.text('طلبك قيد الانتظار'), findsNothing);
  });

  testWidgets('new submission refreshes an already open empty journey', (tester) async {
    AuthSession.instance.token = 'test';
    addTearDown(() => AuthSession.instance.token = null);
    var submitted = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: LiveJourneyScreen()));
      await tester.pumpAndSettle();
      expect(find.text('لم تبدأ رحلة تقديم بعد'), findsOneWidget);
      submitted = true;
      RealtimeSyncService.instance.forceSync();
      await tester.pumpAndSettle();
      expect(find.text('طلبك قيد الانتظار'), findsOneWidget);
      expect(find.text('لم تبدأ رحلة تقديم بعد'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async => http.Response(jsonEncode({
      'journeys': submitted ? [{'applicationId': 'new', 'applicationStatus': 'submitted', 'stages': []}] : [],
    }), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
