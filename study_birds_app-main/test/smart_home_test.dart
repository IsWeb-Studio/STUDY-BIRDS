import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';
import 'package:study_birds/screens/home_journey/home_dashboard_screen.dart';

http.Response reply(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> overview({Map<String, dynamic>? home}) => {
      'profile': null,
      'progress': {'currentStage': 'applying', 'stages': []},
      'stats': {
        'currentApplications': 1,
        'acceptedDocuments': 1,
        'rejectedDocuments': 1,
        'pendingPayments': 1,
        'unreadNotifications': 2
      },
      'latestNotification': null,
      'recentApplications': [],
      'recentDocuments': [],
      'nextAction': {
        'code': 'document-correction',
        'destination': 'documents',
        'titleAr': 'استكمال مستند',
        'descriptionAr': 'راجع المستند المطلوب: كشف الدرجات',
        'waiting': false,
      },
      if (home != null) 'home': home,
    };

final home = {
  'greeting': {'name': 'أحمد'},
  'context': {
    'key': 'documents',
    'titleAr': 'أكمل أوراقك المطلوبة',
    'descriptionAr': 'هناك مستندات مطلوبة منك حتى يستمر طلبك.',
    'destination': 'documents',
  },
  'statusCard': {
    'labelAr': 'مستندات ناقصة',
    'nextStepAr': 'استكمال مستند',
    'destination': 'documents',
    'waiting': false,
  },
  'currentJourney': {
    'applicationId': 'a1',
    'country': 'Turkey',
    'city': 'Istanbul',
    'university': 'Istanbul University',
    'program': 'Physiotherapy',
  },
  'progressPercent': 47,
  'importantDates': [
    {
      'key': 'payment-due',
      'date': '2026-09-22T00:00:00Z',
      'daysLeft': -1,
      'overdue': true,
      'critical': true,
      'titleAr': 'استحقاق دفعة: القسط الأول',
      'destination': 'payments',
      'entityId': 'i1',
    },
    {
      'key': 'arrival',
      'date': '2026-10-10T00:00:00Z',
      'daysLeft': 17,
      'overdue': false,
      'critical': false,
      'titleAr': 'موعد السفر والوصول',
      'destination': 'travel',
      'entityId': 'r1',
    },
  ],
  'sections': {
    'admission': {
      'statusInfo': {
        'status': 'documents-missing',
        'code': 'APP_02',
        'tone': 'action',
        'ar': {
          'label': 'مستندات ناقصة',
          'meaning': 'لا يمكن متابعة طلبك قبل رفع كل المستندات المطلوبة.',
          'nextStep': 'ارفع المستندات الناقصة.'
        },
      }
    },
    'documents': {
      'total': 3,
      'approved': 1,
      'needsAction': 1,
      'underReview': 1
    },
    'visa': null,
    'travel': {'arrivalDate': '2026-10-10T00:00:00Z'},
    'payments': {'unpaid': 1, 'overdue': 1},
    'support': {'openTickets': 0},
    'notifications': {'unread': 2, 'latest': null},
    'recentActivity': [
      {
        'at': '2026-09-20T10:00:00Z',
        'kind': 'document',
        'titleAr': 'كشف الدرجات: مرفوض',
        'destination': 'documents',
        'entityId': 'd1',
      }
    ],
  },
  'quickActions': [
    for (final entry in {
      'programs': 'البرامج',
      'universities': 'الجامعات',
      'applications': 'طلباتي',
      'upload-document': 'رفع مستند',
      'consultation': 'حجز استشارة',
      'visa': 'التأشيرة',
      'travel': 'السفر والوصول',
      'accommodation': 'السكن',
      'payments': 'المدفوعات',
      'support': 'الدعم',
      'bird-ai': 'Bird AI',
    }.entries)
      {'key': entry.key, 'labelAr': entry.value, 'destination': entry.key}
  ],
};

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => AuthSession.instance.token = 'test');
  tearDown(() => AuthSession.instance.token = null);

  testWidgets(
      'smart home: greeting, context card, journey, countdowns, sections, quick actions',
      (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: HomeDashboardScreen(embedInShell: true)));
      await tester.pumpAndSettle();
      expect(find.text('مرحباً أحمد'), findsOneWidget);
      expect(find.text('Turkey - Istanbul - Physiotherapy'), findsOneWidget);
      expect(find.text('47%'), findsOneWidget);
      // The context card is the first thing below the status card.
      expect(find.text('أكمل أوراقك المطلوبة'), findsWidgets);
      // Server quick actions (11) plus the app's community shortcut.
      for (final label in [
        'البرامج',
        'رفع مستند',
        'التأشيرة',
        'السكن',
        'المجتمع'
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.scrollUntilVisible(find.text('متأخر 1 يوم'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('استحقاق دفعة: القسط الأول'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('بعد 17 يوم'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.scrollUntilVisible(find.text('1 يحتاج إجراء منك'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('1 متأخرة'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('كشف الدرجات: مرفوض'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);

      // The documents section opens the student's documents.
      await tester.ensureVisible(find.text('1 يحتاج إجراء منك'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 يحتاج إجراء منك'));
      await tester.pumpAndSettle();
      expect(find.byType(MyDocumentsScreen), findsOneWidget);
    },
        () => MockClient((r) async => reply(
            r.url.path.endsWith('/students/overview')
                ? overview(home: home)
                : <dynamic>[])));
  });

  testWidgets('an older server without the home payload still renders',
      (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: HomeDashboardScreen(embedInShell: true)));
      await tester.pumpAndSettle();
      expect(find.text('مرحباً بك'), findsOneWidget);
      expect(find.text('المواعيد المهمة'), findsNothing);
      expect(find.text('طلباتي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async => reply(
            r.url.path.endsWith('/students/overview')
                ? overview()
                : <dynamic>[])));
  });
}
