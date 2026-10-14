import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/student_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/screens/applications_documents_payments/documents_screens.dart';
import 'package:study_birds/screens/services_support/services_consultation_screens.dart';
import 'catalog_filters_test.dart' show mount;

void main() {
  setUp(() { AuthSession.instance.token = 'library-flow'; AuthSession.instance.currentUser = null; });
  tearDown(() => AuthSession.instance.token = null);
  final doc = <String, dynamic>{'_id': 'saved', 'type': 'transcript',
    'fileName': 'saved-transcript.pdf', 'status': 'pending', 'uploadStatus': 'uploaded'};

  testWidgets('confirmed upload updates the open document library without reopening', (tester) async {
    final library = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await mount(tester, const MyDocumentsScreen());
      expect(find.text('saved-transcript.pdf'), findsNothing);
      await tester.runAsync(() => StudentRepository.instance.uploadDocument(
          fileBytes: utf8.encode('%PDF-1.4\nfixture\n%%EOF'), fileName: 'saved-transcript.pdf', type: 'transcript'));
      await tester.pumpAndSettle();
      expect(find.text('saved-transcript.pdf'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async {
      Object data;
      if (request.url.path.endsWith('/lookup')) { data = {'document': null}; }
      else if (request.method == 'POST') { library.add(doc); data = doc; }
      else { data = library; }
      return http.Response(jsonEncode(data), 200);
    }));
  });

  testWidgets('service request sends saved document IDs only after explicit selection and confirmation', (tester) async {
    Map<String, dynamic>? submitted;
    await http.runWithClient(() async {
      await mount(tester, const ServiceDetailScreen(service: {'_id': 'visa', 'title': 'Visa'}));
      expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, false);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final submit = find.text('طلب الخدمة');
      await tester.scrollUntilVisible(submit, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(submit); await tester.pumpAndSettle();
      expect(submitted, isNull);
      await tester.tap(find.text('تأكيد')); await tester.pumpAndSettle();
      expect(submitted?['documentIds'], ['saved']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.url.path, '/api/service-requests');
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"_id":"request"}', 201);
      }
      expect(request.url.path, '/api/students/documents');
      return http.Response(jsonEncode([doc]), 200);
    }));
  });
}
