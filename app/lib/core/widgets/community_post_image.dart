import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../services/auth_session.dart';
import '../config/app_theme.dart';

class CommunityPostImage extends StatefulWidget {
  final String path;
  const CommunityPostImage({super.key, required this.path});
  @override
  State<CommunityPostImage> createState() => _PostImageState();
}

class _PostImageState extends State<CommunityPostImage> {
  late Future<Uint8List> _bytes;
  late final String? _owner = AuthSession.instance.currentUser?.id;
  Future<Uint8List> _load() async {
    final token = AuthSession.instance.token;
    if (token == null ||
        !RegExp(r'^/community/posts/[a-f\d]{24}/image$')
            .hasMatch(widget.path)) {
      throw StateError('Image unavailable');
    }
    final bytes = await ApiClient.instance.download(widget.path, token: token);
    if (_owner != AuthSession.instance.currentUser?.id ||
        AuthSession.instance.token == null ||
        bytes.length > 5 * 1024 * 1024) {
      throw StateError('Image unavailable');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  @override
  void didUpdateWidget(covariant CommunityPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) _bytes = _load();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: 1.6,
      child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(snapshot.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined));
            }
            if (snapshot.hasError) {
              return Center(
                  child: TextButton.icon(
                      onPressed: () => setState(() => _bytes = _load()),
                      icon: const Icon(Icons.refresh),
                      label: Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'إعادة تحميل الصورة'
                              : 'Retry image')));
            }
            return const Center(
                child: CircularProgressIndicator(color: AppColors.green));
          }));
}
