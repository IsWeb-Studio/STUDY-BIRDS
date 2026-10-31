import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../services/auth_session.dart';
import '../config/app_theme.dart';

/// Private image bytes live only in bounded memory, never persistent storage.
class _CommunityImageMemory {
  _CommunityImageMemory() {
    AuthSession.instance.addListener(_sync);
  }
  static final instance = _CommunityImageMemory();
  final _images = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List>>{};
  String? _scope;
  int _version = -1, _size = 0, _epoch = 0;
  String get scope =>
      '${AuthSession.instance.currentUser?.id}:${AuthSession.instance.token}';
  void _sync() {
    final next = scope;
    final version = ApiClient.instance.snapshotVersion;
    if (_scope == next && _version == version) return;
    _scope = next;
    _version = version;
    _epoch++;
    _images.clear();
    _pending.clear();
    _size = 0;
  }

  Uint8List? peek(String path) {
    _sync();
    final image = _images.remove(path);
    if (image != null) _images[path] = image;
    return image;
  }

  Future<Uint8List> load(String path, {bool retry = false}) async {
    _sync();
    if (retry) {
      _size -= _images.remove(path)?.length ?? 0;
    } else {
      final saved = peek(path);
      if (saved != null) return saved;
    }
    final existing = _pending[path];
    if (existing != null) return existing;
    final token = AuthSession.instance.token;
    if (token == null ||
        !RegExp(r'^/community/posts/[a-f\d]{24}/image$').hasMatch(path)) {
      throw StateError('Image unavailable');
    }
    final owner = scope;
    final version = _version;
    final epoch = _epoch;
    late final Future<Uint8List> request;
    request = () async {
      try {
        final data = await ApiClient.instance.download(path, token: token);
        if (owner != scope ||
            epoch != _epoch ||
            AuthSession.instance.token == null ||
            data.length > 5 * 1024 * 1024) {
          throw StateError('Image unavailable');
        }
        final bytes = Uint8List.fromList(data);
        if (_scope == owner &&
            _version == version &&
            ApiClient.instance.snapshotVersion == version) {
          while (_images.isNotEmpty &&
              (_images.length >= 12 ||
                  _size + bytes.length > 20 * 1024 * 1024)) {
            _size -= _images.remove(_images.keys.first)!.length;
          }
          _images[path] = bytes;
          _size += bytes.length;
        }
        return bytes;
      } finally {
        if (identical(_pending[path], request)) _pending.remove(path);
      }
    }();
    _pending[path] = request;
    return request;
  }
}

class CommunityPostImage extends StatefulWidget {
  final String path;
  final bool thumbnail;
  const CommunityPostImage(
      {super.key, required this.path, this.thumbnail = false});
  @override
  State<CommunityPostImage> createState() => _PostImageState();
}

class _PostImageState extends State<CommunityPostImage> {
  late Future<Uint8List> _bytes;
  late String _scope;
  int _imageVersion = 0;
  final _memory = _CommunityImageMemory.instance;
  Future<Uint8List> _request({bool retry = false}) {
    final result = _memory.load(widget.path, retry: retry);
    // Logout may fail before the next frame attaches FutureBuilder.
    result.ignore();
    return result;
  }

  void _sessionChanged() {
    if (!mounted || _scope == _memory.scope) return;
    _scope = _memory.scope;
    setState(() {
      _imageVersion++;
      _bytes = _request();
    });
  }

  @override
  void initState() {
    super.initState();
    _scope = _memory.scope;
    AuthSession.instance.addListener(_sessionChanged);
    _bytes = _request();
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CommunityPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) _bytes = _request();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: widget.thumbnail ? 1 : 1.6,
      child: FutureBuilder<Uint8List>(
          key: ValueKey((widget.path, _imageVersion)),
          future: _bytes,
          initialData: _memory.peek(widget.path),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(snapshot.data!,
                  fit: BoxFit.cover,
                  cacheWidth: widget.thumbnail ? 400 : 900,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined));
            }
            if (snapshot.hasError) {
              if (widget.thumbnail) {
                return const Center(
                    child: Icon(Icons.image_not_supported_outlined));
              }
              return Center(
                  child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _bytes = _request(retry: true)),
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
