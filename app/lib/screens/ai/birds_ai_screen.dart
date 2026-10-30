import 'assistant_contract.dart';
import '../../core/widgets/ai_consent.dart';
import 'assistant_avatar.dart';
import 'assistant_answer.dart';
import '../../core/services/error_reporter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/utils/app_error.dart';
import '../services_support/support_team_ai_screens.dart'
    show SupportCenterScreen;
import 'assistant_navigation.dart';

class BirdsAiScreen extends StatefulWidget {
  final String originScreen;
  const BirdsAiScreen({super.key, this.originScreen = 'assistant'});
  @override
  State<BirdsAiScreen> createState() => _BirdsAiScreenState();
}

class _BirdsAiScreenState extends State<BirdsAiScreen> {
  String? _threadId;
  final List<_Msg> _messages = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _aiConsent = false;
  bool _askingConsent = false;
  bool _enabled = true;
  bool _contractReady = false;
  String? _disabledMessage;
  List<String> _suggested = [];

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
        _messages.clear();
        _threadId = null;
        _suggested = [];
        _enabled = false;
        _disabledMessage = Localizations.localeOf(context).languageCode == 'en'
            ? 'Your session changed. Sign in again to use the assistant.'
            : 'انتهت جلستك. سجّل الدخول مجددًا لاستخدام المساعد.';
        _sending = false;
        _ctrl.clear();
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
    _loadConfig();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    AuthSession.instance.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final cfg = await ApiClient.instance.get('/assistant/config',
          token: AuthSession.instance.token, cached: false);
      if (!mounted || !_sessionValid) return;
      if (!AssistantContract.accepts(cfg)) {
        final english = Localizations.localeOf(context).languageCode == 'en';
        setState(() {
          _enabled = false;
          _disabledMessage = !AssistantContract.matchesProtocol(cfg)
              ? (english
                  ? 'The assistant service needs an update to match this app. Please try again later or contact Support Center.'
                  : 'خدمة المساعد تحتاج إلى تحديث ليتوافق إصدارها مع التطبيق. جرّب لاحقًا أو تواصل مع مركز الدعم.')
              : (english
                  ? 'The assistant service is temporarily unavailable. Please try again later or contact Support Center.'
                  : 'خدمة المساعد غير متاحة مؤقتًا. جرّب لاحقًا أو تواصل مع مركز الدعم.');
        });
        return;
      }
      setState(() => _contractReady = true);
      final q = await ApiClient.instance.get(
          '/assistant/suggested-questions?language=${Localizations.localeOf(context).languageCode}',
          token: AuthSession.instance.token);
      if (!mounted || !_sessionValid) return;
      if (q is List) {
        setState(() => _suggested = List<String>.from(q.whereType<String>()));
      }
    } catch (swallowedError, swallowedStack) {
      if (mounted && _sessionValid) {
        final english = Localizations.localeOf(context).languageCode == 'en';
        setState(() {
          _contractReady = false;
          _enabled = false;
          _disabledMessage = swallowedError is ApiException &&
                  (swallowedError.statusCode == 401 ||
                      swallowedError.statusCode == 403)
              ? (english
                  ? 'Your session expired. Sign in again to use the assistant.'
                  : 'انتهت جلستك. سجّل الدخول مجددًا لاستخدام المساعد.')
              : (english
                  ? 'Could not reach the assistant service. Check your connection and try again later, or contact Support Center.'
                  : 'تعذر الاتصال بخدمة المساعد. تحقق من اتصالك وحاول لاحقًا، أو تواصل مع مركز الدعم.');
        });
      }
      ErrorReporter.swallowed(
          swallowedError, swallowedStack, 'screens/ai/birds_ai_screen.dart:51');
    }
  }

  Future<void> _send([String? text]) async {
    final msg = (text ?? _ctrl.text).trim();
    if (!_sessionValid || !_contractReady || msg.isEmpty || _sending) return;
    if (_askingConsent) return;
    if (!_aiConsent) {
      _askingConsent = true;
      final accepted = await requestAiConsent(context);
      _askingConsent = false;
      if (!mounted || !_sessionValid || !accepted) return;
      _aiConsent = true;
    }
    _ctrl.clear();
    setState(() {
      _messages.add(_Msg(role: 'user', content: msg));
      _sending = true;
    });
    _scrollBottom();
    try {
      final body = <String, dynamic>{
        'message': msg,
        'screen': widget.originScreen,
        'context': AssistantNavigation.context(
            widget.originScreen, Localizations.localeOf(context).languageCode)
      };
      if (_threadId != null) body['threadId'] = _threadId;
      final res = await ApiClient.instance.post(
        '/assistant/message',
        body: body,
        token: AuthSession.instance.token,
      );
      if (!mounted || !_sessionValid) return;
      if (!AssistantContract.acceptsResponse(res)) {
        throw StateError('Verified assistant response unavailable');
      }
      if (res is Map) {
        _threadId = res['threadId'] as String?;
        final msgs = res['messages'];
        if (msgs is List && msgs.isNotEmpty) {
          final last = msgs.last;
          if (last is Map && last['role'] == 'assistant') {
            setState(() {
              _messages.add(_Msg(
                  role: 'assistant',
                  content: last['content'] as String? ?? '',
                  details: last['details'] as String? ?? '',
                  actions: last['actions'] is List
                      ? last['actions'] as List
                      : const [],
                  knowledgeVersion: last['knowledgeVersion'] as String?));
              _suggested = [];
            });
          }
        }
      }
    } catch (e) {
      if (!mounted || !_sessionValid) return;
      // Never claim the assistant answered; keep the question so it can be
      // re-sent. The server may or may not have received it, so no auto-retry.
      final offline = AppError.isOffline(e);
      setState(() {
        if (_ctrl.text.isEmpty) _ctrl.text = msg;
        _messages.add(_Msg(
            role: 'assistant',
            content: offline
                ? (Localizations.localeOf(context).languageCode == 'en'
                    ? 'You are offline. Reconnect and retry your message.'
                    : 'لا يوجد اتصال بالإنترنت. أعد المحاولة عند عودة الاتصال.')
                : AppError.message(e),
            isError: true));
      });
    } finally {
      if (mounted && _sessionValid) {
        setState(() => _sending = false);
        _scrollBottom();
      }
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'en'
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          elevation: 0,
          automaticallyImplyLeading: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              tooltip: Localizations.localeOf(context).languageCode == 'en'
                  ? 'Support Center'
                  : 'مركز الدعم',
              icon: const Icon(Icons.support_agent_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SupportCenterScreen())),
            )
          ],
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const AssistantAvatar(size: 28),
              ),
              const SizedBox(width: 10),
              const Text('COVEY AI',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
        body: SafeArea(
          child: !_enabled
              ? _DisabledView(message: _disabledMessage)
              : Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? _WelcomeView(suggested: _suggested, onTap: _send)
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              itemCount: _messages.length + (_sending ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == _messages.length) {
                                  return const _TypingBubble();
                                }
                                final message = _messages[i];
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _MessageBubble(msg: message),
                                      if (message.role == 'assistant')
                                        AssistantActions(
                                            actions: message.actions,
                                            version: message.knowledgeVersion),
                                      if (message.isError)
                                        TextButton.icon(
                                          icon:
                                              const Icon(Icons.refresh_rounded),
                                          label: Text(
                                              Localizations.localeOf(context)
                                                          .languageCode ==
                                                      'en'
                                                  ? 'Retry'
                                                  : 'إعادة المحاولة'),
                                          onPressed:
                                              _sending ? null : () => _send(),
                                        ),
                                    ]);
                              },
                            ),
                    ),
                    _InputBar(
                      ctrl: _ctrl,
                      sending: _sending || !_contractReady,
                      onSend: _send,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _Msg {
  final String role;
  final String content;
  final String details;
  final bool isError;
  final List<dynamic> actions;
  final String? knowledgeVersion;
  _Msg(
      {required this.role,
      required this.content,
      this.details = '',
      this.isError = false,
      this.actions = const [],
      this.knowledgeVersion});
}

// ── Welcome view ──────────────────────────────────────────────────────────────

class _WelcomeView extends StatelessWidget {
  final List<String> suggested;
  final void Function(String) onTap;
  const _WelcomeView({required this.suggested, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const AssistantAvatar(size: 46),
          ),
        ),
        const SizedBox(height: 20),
        Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? 'COVEY support assistant'
                : 'مساعد COVEY',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        Text(
          Localizations.localeOf(context).languageCode == 'en'
              ? 'Help with COVEY, your applications and documents.\nApp support only; never share passwords or verification codes.'
              : 'أساعدك باستخدام COVEY ومتابعة طلباتك ومستنداتك.\nمختص بالتطبيق فقط؛ لا ترسل كلمات مرور أو أكواد تحقق.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6),
        ),
        if (suggested.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
              Localizations.localeOf(context).languageCode == 'en'
                  ? 'Suggested questions'
                  : 'اقتراحات لك:',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13)),
          const SizedBox(height: 12),
          ...suggested.map((q) => _SuggestedChip(text: q, onTap: onTap)),
        ] else ...[
          const SizedBox(height: 28),
          ...(Localizations.localeOf(context).languageCode == 'en'
                  ? _defaultEn
                  : _defaultQ)
              .map((q) => _SuggestedChip(text: q, onTap: onTap)),
        ],
      ],
    );
  }

  static const _defaultQ = [
    'كيف أبحث عن جامعة داخل التطبيق؟',
    'كيف أتابع طلباتي؟',
    'كيف أرفع المستندات؟',
    'كيف أتواصل مع الدعم؟',
  ];
  static const _defaultEn = [
    'How do I find a university in the app?',
    'How do I track my applications?',
    'How do I upload documents?',
    'How do I contact support?',
  ];
}

class _SuggestedChip extends StatelessWidget {
  final String text;
  final void Function(String) onTap;
  const _SuggestedChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(text),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }
}

// ── Message bubbles ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const AssistantAvatar(size: 24),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.navy
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                  bottomRight: isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: AssistantAnswer(
                reportable: !isUser && !msg.isError,
                content: msg.content,
                details: msg.details,
                knowledgeVersion: msg.knowledgeVersion,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : msg.isError
                          ? AppColors.danger
                          : Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const AssistantAvatar(size: 24),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(
                          alpha: 0.3 + 0.7 * _anim.value * (i == 1 ? 1 : 0.6)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar(
      {required this.ctrl, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              enabled: !sending,
              textDirection:
                  Localizations.localeOf(context).languageCode == 'en'
                      ? TextDirection.ltr
                      : TextDirection.rtl,
              maxLength: 2000,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: Localizations.localeOf(context).languageCode == 'en'
                    ? 'Ask about COVEY…'
                    : 'اسأل عن COVEY…',
                hintStyle: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sending
                    ? AppColors.navy.withValues(alpha: 0.4)
                    : AppColors.navy,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Disabled view ─────────────────────────────────────────────────────────────

class _DisabledView extends StatelessWidget {
  final String? message;
  const _DisabledView({this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
              message ??
                  (Localizations.localeOf(context).languageCode == 'en'
                      ? 'The assistant is temporarily unavailable. Please contact Support Center.'
                      : 'المساعد غير متاح مؤقتًا. تواصل مع مركز الدعم.'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
}
