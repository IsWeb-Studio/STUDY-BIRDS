import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../core/analytics_service.dart';

class BirdAssistantScreen extends StatefulWidget {
  const BirdAssistantScreen({super.key});
  @override
  State<BirdAssistantScreen> createState() => _BirdAssistantScreenState();
}

class _BirdAssistantScreenState extends State<BirdAssistantScreen> {
  final input = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> threads = [], messages = [];
  List<String> suggestedQuestions = [];
  String? threadId, error;
  bool busy = false, loading = true;
  String? get token => AuthSession.instance.token;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.birdAiOpened();
    _load();
  }

  @override
  void dispose() {
    input.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/assistant/threads', token: token),
        ApiClient.instance.get('/assistant/suggested-questions', token: token),
      ]);
      if (mounted) {
        setState(() {
          threads = (results[0] as List?) ?? [];
          suggestedQuestions = ((results[1] as List?) ?? []).map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'تعذر تحميل المحادثات');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(String id) async {
    setState(() => loading = true);
    try {
      final data = await ApiClient.instance.get('/assistant/threads/$id', token: token) as Map;
      if (mounted) {
        setState(() {
          threadId = id;
          messages = data['messages'] as List;
          error = null;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر فتح المحادثة');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send([String? preset]) async {
    final body = (preset ?? input.text).trim();
    if (body.isEmpty || busy || loading) return;
    if (preset != null) input.clear();
    setState(() { busy = true; error = null; });
    try {
      final data = await ApiClient.instance.post('/assistant/message',
          token: token,
          body: { 'message': body, if (threadId != null) 'threadId': threadId }) as Map;
      if (mounted) {
        setState(() {
          threadId = data['threadId'] as String;
          messages = data['messages'] as List;
          input.clear();
        });
        _scrollToBottom();
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'تعذر الاتصال بالمساعد');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _newThread() => setState(() { threadId = null; messages = []; error = null; input.clear(); });

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'Bird AI',
      actions: [
        IconButton(
            tooltip: 'محادثة جديدة',
            onPressed: busy || loading ? null : _newThread,
            icon: const Icon(Icons.add_comment_outlined))
      ],
      bottomBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: input,
                        enabled: !busy && !loading,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => send(),
                        decoration: featureInput('رسالتك للمساعد...'))),
                const SizedBox(width: 4),
                IconButton(
                    onPressed: busy || loading ? null : () => send(),
                    icon: busy
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.send_rounded, color: AppColors.navy))
              ]))),
      body: loading
          ? const LoadingState()
          : ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                const InlineNotice(
                    'مساعد آلي للمعلومات العامة. رسائلك تُرسل لمزوّد الذكاء الاصطناعي وتُحفظ في حسابك. لا ترسل كلمات مرور أو مستندات هوية.'),
                if (error != null) ...[const SizedBox(height: 8), InlineNotice(error!, error: true)],

                // Empty state — show suggested questions + thread history
                if (messages.isEmpty) ...[
                  const SizedBox(height: 20),
                  Row(children: [
                    const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.orange),
                    const SizedBox(width: 8),
                    Text('اقتراحات لك', style: AppTextStyles.sectionLabel),
                  ]),
                  const SizedBox(height: 10),
                  if (suggestedQuestions.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestedQuestions.map((q) => GestureDetector(
                        onTap: busy ? null : () => send(q),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            border: Border.all(color: AppColors.navy.withValues(alpha: 0.18)),
                          ),
                          child: Text(q, style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.navy)),
                        ),
                      )).toList(),
                    ),
                  if (threads.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('محادثات سابقة', style: AppTextStyles.sectionLabel),
                    const SizedBox(height: 8),
                    for (final thread in threads)
                      ListTile(
                          dense: true,
                          leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                          title: Text('${thread['title']}',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(fontSize: 14)),
                          onTap: busy ? null : () => open('${thread['_id']}')),
                  ],
                ],

                // Messages
                for (final row in messages) ...[
                  const SizedBox(height: 12),
                  _MessageBubble(
                    role: row['role'] as String? ?? 'user',
                    content: row['content'] as String? ?? '',
                  ),
                ],

                // Typing indicator
                if (busy && messages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _TypingIndicator(),
                ],
                const SizedBox(height: 8),
              ]));
}

class _MessageBubble extends StatelessWidget {
  final String role, content;
  const _MessageBubble({required this.role, required this.content});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? AppColors.navy : Colors.grey.shade100,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.orange),
                    const SizedBox(width: 4),
                    Text('Bird AI', style: AppTextStyles.caption.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700)),
                  ]),
                ),
              SelectableText(
                content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: FadeTransition(
        opacity: _anim,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.orange),
          const SizedBox(width: 6),
          Text('Bird AI يكتب...', style: AppTextStyles.caption.copyWith(color: AppColors.orange)),
        ]),
      ),
    ),
  );
}
