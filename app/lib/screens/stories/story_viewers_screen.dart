import '../../core/config/app_theme.dart';
import 'package:flutter/material.dart';
import '../../core/repositories/stories_repository.dart';
import '../../core/services/auth_session.dart';
import '../community/student_profile_link.dart';
import 'story_loading_indicator.dart';

bool _viewersIsArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _viewersText(BuildContext context, String arabic, String english) =>
    _viewersIsArabic(context) ? arabic : english;

class StoryViewersScreen extends StatefulWidget {
  final String storyId;
  const StoryViewersScreen({super.key, required this.storyId});
  @override
  State<StoryViewersScreen> createState() => _StoryViewersScreenState();
}

class _StoryViewersScreenState extends State<StoryViewersScreen> {
  String? _owner;
  bool _sessionEnded = false;
  final List<Map<String, dynamic>> _viewers = [];
  int _total = 0;
  bool _busy = false;
  bool _retryMore = false;
  String? _next, _error;
  @override
  void initState() {
    super.initState();
    _owner = AuthSession.instance.currentUser?.id;
    AuthSession.instance.addListener(_onSessionChanged);
    _load();
  }

  void _onSessionChanged() {
    if (_sessionEnded || _owner == AuthSession.instance.currentUser?.id) return;
    setState(() {
      _sessionEnded = true;
      _viewers.clear();
      _total = 0;
      _next = null;
      _error = null;
      _busy = false;
    });
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_sessionEnded || _busy || (more && _next == null)) return;
    final owner = AuthSession.instance.currentUser?.id;
    setState(() {
      _busy = true;
      _error = null;
      _retryMore = more;
    });
    try {
      final data = await StoriesRepository.instance
          .viewers(widget.storyId, before: more ? _next : null);
      if (!mounted ||
          _sessionEnded ||
          owner != AuthSession.instance.currentUser?.id) {
        return;
      }
      setState(() {
        if (!more) _viewers.clear();
        _viewers.addAll((data['viewers'] as List)
            .map((row) => Map<String, dynamic>.from(row)));
        _total = (data['total'] as num).toInt();
        _next = data['nextCursor'] as String?;
      });
    } catch (_) {
      if (mounted &&
          !_sessionEnded &&
          owner == AuthSession.instance.currentUser?.id) {
        setState(() => _error = _viewersText(
            context,
            'تعذر تحميل المشاهدين. قد تكون الستوري انتهت أو حُذفت. حاول مجددًا.',
            'Could not load viewers. The story may have expired or been deleted. Try again.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: _viewersText(context, 'مشاهدو الستوري', 'Story viewers'),
      body: _sessionEnded
          ? Center(
              child: Text(_viewersText(
                  context,
                  'انتهت الجلسة. افتح الستوري مجددًا من حسابك.',
                  'Your session ended. Reopen the story from your account.')))
          : RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                        _viewersText(context, 'شاهدها $_total شخص',
                            '$_total people viewed this story'),
                        key: const ValueKey('story-viewers-total'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(_error!),
                      TextButton(
                          onPressed: () => _load(more: _retryMore),
                          child: Text(
                              _viewersText(context, 'إعادة المحاولة', 'Retry')))
                    ],
                    if (_busy && _viewers.isEmpty)
                      const Center(
                          child: StoryLoadingIndicator(color: AppColors.greenInk)),
                    if (!_busy && _error == null && _viewers.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              _viewersText(context, 'لم يشاهد الستوري أحد بعد',
                                  'No one has viewed this story yet'),
                              textAlign: TextAlign.center)),
                    for (final viewer in _viewers)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: viewer['id'] == null
                              ? Text(viewer['name'] as String)
                              : StudentIdentity(
                                  id: viewer['id'] as String,
                                  name: viewer['name'] as String,
                                  avatar: viewer['avatar'] as String,
                                  role:
                                      viewer['role'] as String? ?? 'student')),
                    if (_next != null)
                      TextButton(
                          onPressed: _busy ? null : () => _load(more: true),
                          child: Text(_busy
                              ? _viewersText(
                                  context, 'جارٍ التحميل…', 'Loading…')
                              : _viewersText(
                                  context, 'عرض المزيد', 'Load more'))),
                  ])));
}
