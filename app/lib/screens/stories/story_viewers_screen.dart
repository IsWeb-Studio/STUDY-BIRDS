import 'package:flutter/material.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/auth_session.dart';
import '../../core/config/app_theme.dart';
import '../community/student_profile_link.dart';
import 'story_loading_indicator.dart';

class StoryViewersScreen extends StatefulWidget {
  final String storyId;
  const StoryViewersScreen({super.key, required this.storyId});
  @override
  State<StoryViewersScreen> createState() => _StoryViewersScreenState();
}

class _StoryViewersScreenState extends State<StoryViewersScreen> {
  final List<Map<String, dynamic>> _viewers = [];
  int _total = 0;
  bool _busy = false;
  bool _retryMore = false;
  String? _next, _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy || (more && _next == null)) return;
    final owner = AuthSession.instance.currentUser?.id;
    setState(() {
      _busy = true;
      _error = null;
      _retryMore = more;
    });
    try {
      final data = await StoriesRepository.instance
          .viewers(widget.storyId, before: more ? _next : null);
      if (!mounted || owner != AuthSession.instance.currentUser?.id) return;
      setState(() {
        if (!more) _viewers.clear();
        _viewers.addAll((data['viewers'] as List)
            .map((row) => Map<String, dynamic>.from(row)));
        _total = (data['total'] as num).toInt();
        _next = data['nextCursor'] as String?;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'تعذر تحميل المشاهدين. قد تكون الستوري انتهت أو حُذفت. حاول مجددًا.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'مشاهدو الستوري',
      body: RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text('شاهدها $_total شخص',
                    key: const ValueKey('story-viewers-total'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                      onPressed: () => _load(more: _retryMore),
                      child: const Text('إعادة المحاولة'))
                ],
                if (_busy && _viewers.isEmpty)
                  const Center(
                      child: StoryLoadingIndicator(color: Colors.indigo)),
                if (!_busy && _error == null && _viewers.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لم يشاهد الستوري أحد بعد',
                          textAlign: TextAlign.center)),
                for (final viewer in _viewers)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: viewer['id'] == null
                          ? Text(viewer['name'] as String)
                          : StudentIdentity(
                              id: viewer['id'] as String,
                              name: viewer['name'] as String,
                              avatar: viewer['avatar'] as String)),
                if (_next != null)
                  TextButton(
                      onPressed: _busy ? null : () => _load(more: true),
                      child: Text(_busy ? 'جارٍ التحميل…' : 'عرض المزيد')),
              ])));
}
