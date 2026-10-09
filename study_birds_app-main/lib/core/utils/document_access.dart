import '../network/api_client.dart';
import '../services/auth_session.dart';

Future<Uri> resolveDocumentDownload(String path) async {
  final match = RegExp(
          r'^/api/(?:documents|payment-proofs|support-attachments)/([a-fA-F0-9]{24})/access$')
      .firstMatch(path);
  if (match != null) {
    final data = await ApiClient.instance
        .post(path.substring(4), token: AuthSession.instance.token);
    final uri = Uri.parse(data['url'] as String);
    if (uri.scheme != 'https' || uri.host != 'api.cloudinary.com') {
      throw const FormatException('Invalid private document URL');
    }
    return uri;
  }
  final uri = Uri.parse(ApiClient.baseUrl).resolve(path);
  if (uri.scheme != 'https')
    throw const FormatException('Invalid document URL');
  return uri;
}
