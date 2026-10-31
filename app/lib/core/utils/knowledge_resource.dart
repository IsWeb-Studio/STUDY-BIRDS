import '../network/api_client.dart';
import 'document_access.dart';

String knowledgeResourceUrl(Map<String, dynamic> item) {
  final keys = item['resourceType'] == 'video'
      ? ['videoUrl', 'fileUrl']
      : ['fileUrl', 'videoUrl'];
  for (final key in keys) {
    final value = item[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

Future<Uri> resolveKnowledgeResource(String value) async {
  var raw = value.trim();
  if (raw.isEmpty || raw.contains('\\') || RegExp(r'\s').hasMatch(raw)) {
    throw const FormatException('Invalid resource link');
  }
  if (raw.startsWith('/api/')) return resolveDocumentDownload(raw);
  if (raw.startsWith('//')) raw = 'https:$raw';
  if (raw.startsWith('/')) {
    raw = Uri.parse(ApiClient.baseUrl).resolve(raw).toString();
  } else if (!raw.contains('://')) {
    if (!RegExp(
            r'^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}(?::\d+)?(?:/|\?|#|$)')
        .hasMatch(raw)) {
      throw const FormatException('Invalid resource link');
    }
    raw = 'https://$raw';
  }
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Invalid resource link');
  }
  return uri;
}
