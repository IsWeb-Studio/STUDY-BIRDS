import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:study_birds/core/repositories/student_repository.dart';
import 'package:study_birds/core/services/auth_session.dart';
import 'package:study_birds/core/utils/document_eligibility.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = StudentRepository.instance;
  final bytes = utf8.encode('%PDF-1.4\nfixture\n%%EOF');
  final document = <String, dynamic>{
    '_id': 'doc',
    'type': 'transcript',
    'fileName': 'doc.pdf',
    'fileHash': documentFileHash(bytes),
    'size': bytes.length,
    'status': 'pending',
    'uploadStatus': 'uploaded'
  };
  setUp(() {
    AuthSession.instance.token = 'library-test';
    AuthSession.instance.currentUser = null;
  });
  tearDown(() {
    AuthSession.instance.token = null;
  });

  test(
      'simultaneous identical uploads share one network operation and publish confirmed metadata',
      () async {
    var uploads = 0;
    final gate = Completer<void>();
    final changes = <List<dynamic>>[];
    final sub = repo.documentChanges.listen(changes.add);
    await http.runWithClient(() async {
      final first = repo.uploadDocument(
          fileBytes: bytes, fileName: 'doc.pdf', type: 'transcript');
      final second = repo.uploadDocument(
          fileBytes: bytes, fileName: 'renamed.pdf', type: 'transcript');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(changes, isEmpty); // Pending bytes must not look uploaded.
      gate.complete();
      final results = await Future.wait([first, second]);
      expect(results.map((d) => d['_id']), everyElement('doc'));
      await Future<void>.delayed(Duration.zero);
      expect(uploads, 1);
      expect(changes.last.first['_id'], 'doc');
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/lookup'))
                return http.Response('{"document":null}', 200);
              uploads++;
              await gate.future;
              return http.Response(jsonEncode(document), 201);
            }));
    await sub.cancel();
  });

  test('existing hash lookup reuses the document without sending file bytes',
      () async {
    await http.runWithClient(() async {
      final result = await repo.uploadDocument(
          fileBytes: bytes, fileName: 'renamed.pdf', type: 'transcript');
      expect(result['reused'], true);
      expect(result['_id'], 'doc');
    },
        () => MockClient((request) async {
              expect(request.url.path, '/api/students/documents/lookup');
              final body = jsonDecode(request.body);
              expect(body['fileHash'], document['fileHash']);
              expect(body['size'], bytes.length);
              return http.Response(jsonEncode({'document': document}), 200);
            }));
  });
  test('a late library refresh cannot hide a newly confirmed upload', () async {
    final gate = Completer<void>();
    await http.runWithClient(() async {
      final staleRefresh = repo.getDocuments(forceRefresh: true);
      await repo.uploadDocument(fileBytes: bytes, fileName: 'doc.pdf', type: 'transcript');
      gate.complete();
      final documents = await staleRefresh;
      expect(documents.any((item) => item['_id'] == 'doc'), true);
    }, () => MockClient((request) async {
      if (request.method == 'GET') { await gate.future; return http.Response('[]', 200); }
      if (request.url.path.endsWith('/lookup')) return http.Response('{"document":null}', 200);
      return http.Response(jsonEncode(document), 201);
    }));
  });

  test('failed uploads never publish uploaded metadata', () async {
    final changes = <List<dynamic>>[];
    final sub = repo.documentChanges.listen(changes.add);
    await http.runWithClient(() async {
      await expectLater(
          repo.uploadDocument(
              fileBytes: bytes, fileName: 'doc.pdf', type: 'transcript'),
          throwsException);
      expect(changes, isEmpty);
    },
        () => MockClient((request) async => request.url.path.endsWith('/lookup')
            ? http.Response('{"document":null}', 200)
            : http.Response('{"message":"Storage failed"}', 500)));
    await sub.cancel();
  });

  test(
      'late upload response after account switch cannot populate another user library',
      () async {
    final gate = Completer<void>();
    final changes = <List<dynamic>>[];
    final sub = repo.documentChanges.listen(changes.add);
    await http.runWithClient(() async {
      final upload = repo.uploadDocument(
          fileBytes: bytes, fileName: 'doc.pdf', type: 'transcript');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      AuthSession.instance.token = 'other-account';
      gate.complete();
      await upload;
      await Future<void>.delayed(Duration.zero);
      expect(changes, isEmpty);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/lookup'))
                return http.Response('{"document":null}', 200);
              await gate.future;
              return http.Response(jsonEncode(document), 201);
            }));
    await sub.cancel();
  });

  test(
      'new request suggestions exclude previous, expired, archived and unconfirmed files',
      () {
    expect(isUsableLibraryDocument(document), true);
    for (final change in [
      {'supersededBy': 'new'},
      {'isLatest': false},
      {'archivedAt': '2026-01-01'},
      {'expiresAt': '2020-01-01'},
      {'uploadStatus': 'uploading'},
      {'detailedStatus': 'needs-revision'}
    ]) {
      expect(isUsableLibraryDocument({...document, ...change}), false);
    }
  });
}
