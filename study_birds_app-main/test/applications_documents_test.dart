import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/applications_documents_payments/applications_screens.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';
import 'package:study_birds/screens/universities_programs_countries/catalog_detail.dart';

http.Response reply(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final application = {
  '_id': 'a1',
  'status': 'under-review',
  'detailedStatus': 'under-review',
  'program': {
    'title': 'Medicine',
    'university': {
      'name': 'Istanbul University',
      'city': 'Istanbul',
      'country': {'name': 'Turkey'}
    }
  },
  'card': {
    'intake': 'Fall 2026',
    'degreeLevel': 'bachelor',
    'campus': 'Istanbul',
    'admissionStatus': {
      'status': 'waiting',
      'labelAr': 'بانتظار الفريق أو الجامعة',
      'tone': 'info'
    },
    'documentsStatus': {
      'status': 'completed',
      'labelAr': 'مكتمل',
      'tone': 'success'
    },
    'paymentStatus': {
      'status': 'overdue',
      'labelAr': 'متأخر',
      'tone': 'danger'
    },
    'visaStatus': {
      'status': 'preparing-documents',
      'labelAr': 'تجهيز المستندات'
    },
    'consultant': 'Mona',
    'lastUpdate': '2026-09-20T10:00:00Z',
    'nextAction': {
      'titleAr': 'سداد فاتورة',
      'waiting': false,
      'destination': 'payments'
    },
  },
};

final birthCertificate = {
  '_id': 'd2',
  'type': 'birth-certificate',
  'fileName': 'birth-v2.pdf',
  'filePath': '/api/documents/d2/access',
  'status': 'pending',
  'detailedStatus': 'needs-translation',
  'createdAt': '2026-09-21T10:00:00Z',
  'reviewedBy': {'name': 'Rami'},
  'isLatest': true,
  'versions': [
    {
      '_id': 'd1',
      'fileName': 'birth-v1.pdf',
      'filePath': '/api/documents/d1/access',
      'createdAt': '2026-09-01T10:00:00Z',
      'statusInfo': {
        'status': 'rejected',
        'tone': 'danger',
        'ar': {'label': 'مرفوض', 'meaning': 'x', 'nextStep': 'y'}
      },
    }
  ],
  'translation': {'status': 'required', 'documentId': null},
};

void main() {
  setUp(() => AuthSession.instance.token = 'test');
  tearDown(() => AuthSession.instance.token = null);

  testWidgets(
      'applications list shows intake, admission, payment, visa, consultant and next action',
      (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: ApplicationsListScreen()));
      await tester.pumpAndSettle();
      for (final text in [
        'Fall 2026',
        'بانتظار الفريق أو الجامعة',
        'متأخر',
        'تجهيز المستندات',
        'Mona'
      ]) {
        expect(find.textContaining(text, findRichText: true), findsWidgets,
            reason: text);
      }
      expect(find.textContaining('سداد فاتورة', findRichText: true),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((r) async => reply([application])));
  });

  testWidgets(
      'document list hides old versions and translations; detail shows history and translation',
      (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyDocumentsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('شهادة الميلاد'), findsOneWidget);
      // The superseded file and the translation file are not listed separately.
      expect(find.text('ترجمة معتمدة'), findsNothing);

      await tester.tap(find.text('شهادة الميلاد'));
      await tester.pumpAndSettle();
      expect(find.text('Rami'), findsOneWidget);
      expect(find.text('مطلوبة'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('سجل النسخ (1)'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('birth-v1.pdf'), findsOneWidget);
      expect(find.text('رفع ترجمة معتمدة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async => reply([
              birthCertificate,
              {
                ...(birthCertificate['versions'] as List).first as Map,
                'type': 'birth-certificate',
                'status': 'rejected',
                'isLatest': false
              },
              {
                '_id': 't1',
                'type': 'translation',
                'fileName': 'tr.pdf',
                'status': 'pending',
                'translationOf': 'd2',
                'isLatest': true
              },
            ])));
  });

  testWidgets('document type picker scrolls on a small phone', (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyDocumentsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رفع مستند'));
      await tester.pumpAndSettle();
      expect(find.text('اختر نوع المستند'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('أخرى'), 100,
          scrollable: find.byType(Scrollable).last);
      expect(tester.takeException(), isNull);
    }, () => MockClient((r) async => reply(<dynamic>[])));
  });

  testWidgets(
      'program details show careers, other universities and related programs',
      (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: CatalogDetailPage(id: 'p1')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Pharmacy'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('مجالات العمل بعد التخرج'), findsOneWidget);
      expect(find.text('طبيب عام'), findsOneWidget);
      expect(find.text('Ankara University'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((r) async => reply({
              '_id': 'p1',
              'title': 'Medicine',
              'degreeLevel': 'bachelor',
              'university': {'name': 'Istanbul University'},
              'careerOpportunities': ['طبيب عام'],
              'offeredAt': [
                {
                  '_id': 'p2',
                  'title': 'Medicine',
                  'university': {'name': 'Ankara University', 'city': 'Ankara'}
                }
              ],
              'relatedPrograms': [
                {
                  '_id': 'p3',
                  'title': 'Pharmacy',
                  'university': {'name': 'Ankara University'}
                }
              ],
            })));
  });
}
