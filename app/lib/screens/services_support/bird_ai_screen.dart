import '../ai/assistant_contract.dart';
import '../../core/widgets/ai_consent.dart';
import '../ai/assistant_avatar.dart';
import '../ai/assistant_answer.dart';
import '../../core/utils/json_safe.dart';
import 'dart:async';
import '../../core/services/error_reporter.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/locale_controller.dart';
import '../ai/assistant_navigation.dart';

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
  bool _contractReady = false;
  bool _aiConsent = false;
  bool _askingConsent = false;
  String? get token => AuthSession.instance.token;

  String? _sessionToken, _sessionOwner;
  bool _sessionValid = true;
  void _sessionChanged() {
    final session = AuthSession.instance;
    final sameOwner = _sessionOwner == null
        ? session.token == _sessionToken
        : session.currentUser?.id == _sessionOwner && session.token != null;
    if (!_sessionValid || sameOwner) return;
    _sessionValid = false;
    if (mounted) {
      setState(() {
        threads = [];
        messages = [];
        suggestedQuestions = [];
        threadId = null;
        error = null;
        busy = false;
        loading = false;
        input.clear();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _sessionToken = AuthSession.instance.token;
    _sessionOwner = AuthSession.instance.currentUser?.id;
    AuthSession.instance.addListener(_sessionChanged);
    unawaited(AssistantNavigation.loadAppVersion());
    AnalyticsService.instance.birdAiOpened();
    _load();
  }

  @override
  void dispose() {
    input.dispose();
    _scrollCtrl.dispose();
    AuthSession.instance.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final config = await ApiClient.instance
          .get('/assistant/config', token: token, cached: false);
      if (!mounted || !_sessionValid) return;
      if (!AssistantContract.accepts(config)) {
        setState(() {
          _contractReady = false;
          messages = [];
          threads = [];
          error = Localizations.localeOf(context).languageCode == 'en'
              ? 'The verified assistant is unavailable on this server. Please use Support Center.'
              : 'المساعد الموثق غير متاح على هذا السيرفر. استخدم مركز الدعم.';
        });
        return;
      }
      _contractReady = true;
      final results = await Future.wait([
        ApiClient.instance.get('/assistant/threads', token: token),
        ApiClient.instance.get(
            '/assistant/suggested-questions?language=${LocaleController.instance.locale.languageCode}',
            token: token),
      ]);
      if (mounted && _sessionValid) {
        setState(() {
          threads = (Json.listOrNull(results[0])) ?? [];
          suggestedQuestions = ((Json.listOrNull(results[1])) ?? [])
              .map((e) => e.toString())
              .toList();
        });
      }
    } catch (e) {
      if (mounted && _sessionValid) {
        setState(() =>
            error = e is ApiException ? e.message : 'تعذر تحميل المحادثات');
      }
    } finally {
      if (mounted && _sessionValid) setState(() => loading = false);
    }
  }

  Future<void> open(String id) async {
    setState(() => loading = true);
    try {
      final data = Json.rawMap(
          await ApiClient.instance.get('/assistant/threads/$id', token: token));
      if (!AssistantContract.acceptsResponse(data)) {
        throw StateError('Verified assistant response unavailable');
      }
      if (mounted && _sessionValid) {
        setState(() {
          threadId = id;
          messages = Json.list(data['messages']);
          error = null;
        });
        _scrollToBottom();
      }
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/services_support/bird_ai_screen.dart:69');
      if (mounted && _sessionValid) setState(() => error = 'تعذر فتح المحادثة');
    } finally {
      if (mounted && _sessionValid) setState(() => loading = false);
    }
  }

  Future<void> send([String? preset]) async {
    final body = (preset ?? input.text).trim();
    if (!_sessionValid || !_contractReady || body.isEmpty || busy || loading) {
      return;
    }
    if (_askingConsent) return;
    if (!_aiConsent) {
      _askingConsent = true;
      final accepted = await requestAiConsent(context);
      _askingConsent = false;
      if (!mounted || !_sessionValid || !accepted) return;
      _aiConsent = true;
    }
    if (preset != null) input.clear();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = Json.rawMap(await ApiClient.instance
          .post('/assistant/message', token: token, body: {
        'message': body,
        'screen': 'assistant',
        'context': AssistantNavigation.context(
            'assistant', Localizations.localeOf(context).languageCode),
        if (threadId != null) 'threadId': threadId
      }));
      if (!AssistantContract.acceptsResponse(data)) {
        throw StateError('Verified assistant response unavailable');
      }
      if (mounted && _sessionValid) {
        setState(() {
          threadId = data['threadId'] as String;
          messages = Json.list(data['messages']);
          input.clear();
        });
        _scrollToBottom();
        await _load();
      }
    } catch (e) {
      if (mounted && _sessionValid) {
        setState(() =>
            error = e is ApiException ? e.message : 'تعذر الاتصال بالمساعد');
      }
    } finally {
      if (mounted && _sessionValid) setState(() => busy = false);
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

  void _newThread() => setState(() {
        threadId = null;
        messages = [];
        error = null;
        input.clear();
      });

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'COVEY AI',
      actions: [
        IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'en'
                ? 'New conversation'
                : 'محادثة جديدة',
            onPressed: busy || loading ? null : _newThread,
            icon: const Icon(Icons.add_comment_outlined))
      ],
      body: loading
          ? const LoadingState()
          : Column(children: [
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    InlineNotice(Localizations.localeOf(context).languageCode ==
                            'en'
                        ? 'COVEY app support only. Conversations are saved to your account; only approved topic IDs go to the AI provider. Never send passwords or identity documents.'
                        : 'مساعد مختص بتطبيق COVEY فقط. تُحفظ المحادثات في حسابك، ويُرسل للمزوّد معرّف الموضوع فقط. لا ترسل كلمات مرور أو مستندات هوية.'),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      InlineNotice(error!, error: true)
                    ],
                    if (messages.isEmpty) ...[
                      const SizedBox(height: 20),
                      Row(children: [
                        const AssistantAvatar(size: 28),
                        const SizedBox(width: 8),
                        Text(
                            Localizations.localeOf(context).languageCode == 'en'
                                ? 'Suggested questions'
                                : 'اقتراحات لك',
                            style: AppTextStyles.sectionLabel),
                      ]),
                      const SizedBox(height: 10),
                      if (suggestedQuestions.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: suggestedQuestions
                              .map((q) => GestureDetector(
                                    onTap: busy ? null : () => send(q),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: AppColors.navy
                                            .withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.chip),
                                        border: Border.all(
                                            color: AppColors.navy
                                                .withValues(alpha: 0.18)),
                                      ),
                                      child: Text(q,
                                          style: AppTextStyles.body.copyWith(
                                              fontSize: 13,
                                              color: AppColors.navy)),
                                    ),
                                  ))
                              .toList(),
                        ),
                      if (threads.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('محادثات سابقة',
                            style: AppTextStyles.sectionLabel),
                        const SizedBox(height: 8),
                        for (final thread in threads)
                          ListTile(
                              dense: true,
                              leading: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 20),
                              title: Text('${thread['title']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body
                                      .copyWith(fontSize: 14)),
                              onTap:
                                  busy ? null : () => open('${thread['_id']}')),
                      ],
                    ],
                    for (final row in messages) ...[
                      const SizedBox(height: 12),
                      _MessageBubble(
                        role: row['role'] as String? ?? 'user',
                        content: row['content'] as String? ?? '',
                        details: row['details'] as String? ?? '',
                        version: row['knowledgeVersion'] as String?,
                      ),
                      if (row['role'] == 'assistant')
                        AssistantActions(
                            actions: row['actions'] is List
                                ? row['actions'] as List
                                : const [],
                            version: row['knowledgeVersion'] as String?),
                    ],
                    if (busy && messages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _TypingIndicator(),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // Input bar — inside body so keyboard pushes it up
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                            controller: input,
                            enabled: _sessionValid &&
                                _contractReady &&
                                !busy &&
                                !loading,
                            maxLength: 2000,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => send(),
                            decoration: featureInput(
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? 'Ask about COVEY…'
                                    : 'رسالتك عن COVEY…'))),
                    const SizedBox(width: 4),
                    IconButton(
                        tooltip:
                            Localizations.localeOf(context).languageCode == 'en'
                                ? 'Send'
                                : 'إرسال',
                        onPressed:
                            !_sessionValid || !_contractReady || busy || loading
                                ? null
                                : () => send(),
                        icon: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5))
                            : const Icon(Icons.send_rounded,
                                color: AppColors.navy))
                  ]),
                ),
              ),
            ]));
}

class _MessageBubble extends StatelessWidget {
  final String role, content, details;
  final String? version;
  const _MessageBubble(
      {required this.role,
      required this.content,
      this.details = '',
      this.version});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.navy
                : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    const AssistantAvatar(size: 23),
                    const SizedBox(width: 4),
                    Text('COVEY AI',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.greenInk,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              AssistantAnswer(
                reportable: !isUser,
                content: content,
                details: isUser ? '' : details,
                knowledgeVersion: version,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
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

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16)),
          child: FadeTransition(
            opacity: _anim,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const AssistantAvatar(size: 23),
              const SizedBox(width: 6),
              Text('COVEY AI يكتب...',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.greenInk)),
            ]),
          ),
        ),
      );
}
