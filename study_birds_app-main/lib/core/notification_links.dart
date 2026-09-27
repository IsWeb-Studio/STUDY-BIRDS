String? notificationPath(String raw) {
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  String path;
  if (uri.scheme == 'studybirds') {
    path = '/${uri.host}${uri.path}';
  } else if (uri.scheme == 'https' &&
      ['studybirds.app', 'studybirds.net', 'www.studybirds.net'].contains(uri.host)) {
    path = uri.path;
  } else if (!uri.hasScheme && !uri.hasAuthority) {
    path = uri.path.startsWith('/') ? uri.path : '/student/${uri.path}';
  } else { return null; }
  if (path == '/student/consultation') path = '/student/consultations';
  return path.startsWith('/student/') ? path : null;
}
