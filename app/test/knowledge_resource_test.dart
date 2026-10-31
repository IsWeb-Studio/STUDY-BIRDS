import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/utils/knowledge_resource.dart';

void main() {
  test('empty video does not hide a document link and the resource type determines priority', () {
    expect(knowledgeResourceUrl({'videoUrl': '', 'fileUrl': ' www.example.test/file.pdf '}), 'www.example.test/file.pdf');
    expect(knowledgeResourceUrl({'resourceType': 'pdf', 'videoUrl': 'video', 'fileUrl': 'file'}), 'file');
    expect(knowledgeResourceUrl({'resourceType': 'video', 'videoUrl': 'video', 'fileUrl': 'file'}), 'video');
  });
  test('normalizes links without a protocol and preserves query strings', () async {
    expect((await resolveKnowledgeResource(' www.example.test/file.pdf?a=1#page=2 ')).toString(), 'https://www.example.test/file.pdf?a=1#page=2');
    expect((await resolveKnowledgeResource('//example.test/guide')).scheme, 'https');
    expect((await resolveKnowledgeResource('/uploads/guide.pdf')).path, '/uploads/guide.pdf');
  });
  test('invalid links fail with a visible error path rather than launching arbitrary schemes', () async {
    for (final value in ['javascript:alert(1)', 'file:///secret', 'not a link', 'https://user:pass@example.test']) {
      await expectLater(resolveKnowledgeResource(value), throwsFormatException);
    }
  });
}
