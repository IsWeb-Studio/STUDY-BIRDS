import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';

class BirdsAiScreen extends StatefulWidget {
  const BirdsAiScreen({super.key});
  @override
  State<BirdsAiScreen> createState() => _BirdsAiScreenState();
}

class _BirdsAiScreenState extends State<BirdsAiScreen> {
  String? _threadId;
  final List<_Msg> _messages = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _enabled = true;
  List<String> _suggested = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final cfg = await ApiClient.instance
          .get('/assistant/config', token: AuthSession.instance.token);
      if (cfg is Map && cfg['enabled'] == false) {
        setState(() => _enabled = false);
        return;
      }
      final q = await ApiClient.instance
          .get('/assistant/suggested-questions', token: AuthSession.instance.token);
      if (q is List) {
        setState(() => _suggested = List<String>.from(q.whereType<String>()));
      }
    } catch (_) {}
  }

  Future<void> _send([String? text]) async {
    final msg = (text ?? _ctrl.text).trim();
    if (msg.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_Msg(role: 'user', content: msg));
      _sending = true;
    });
    _scrollBottom();
    try {
      final body = <String, dynamic>{'message': msg};
      if (_threadId != null) body['threadId'] = _threadId;
      final res = await ApiClient.instance.post(
        '/assistant/message',
        body: body,
        token: AuthSession.instance.token,
      );
      if (res is Map) {
        _threadId = res['threadId'] as String?;
        final msgs = res['messages'];
        if (msgs is List && msgs.isNotEmpty) {
          final last = msgs.last;
          if (last is Map && last['role'] == 'assistant') {
            setState(() {
              _messages.add(_Msg(
                  role: 'assistant',
                  content: last['content'] as String? ?? ''));
              _suggested = [];
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _messages.add(_Msg(
            role: 'assistant',
            content: 'حدث خطأ. يرجى المحاولة مرة أخرى.',
            isError: true));
      });
    } finally {
      setState(() => _sending = false);
      _scrollBottom();
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
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6FA),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          elevation: 0,
          automaticallyImplyLeading: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Birds AI',
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
              ? _DisabledView()
              : Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? _WelcomeView(
                              suggested: _suggested, onTap: _send)
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              itemCount:
                                  _messages.length + (_sending ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == _messages.length) {
                                  return const _TypingBubble();
                                }
                                return _MessageBubble(msg: _messages[i]);
                              },
                            ),
                    ),
                    _InputBar(
                      ctrl: _ctrl,
                      sending: _sending,
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
  final bool isError;
  _Msg({required this.role, required this.content, this.isError = false});
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
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.orange, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        const Text('مرحباً! أنا Birds AI',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
        const SizedBox(height: 8),
        const Text(
          'مساعدك الذكي للدراسة في الخارج.\nاسألني عن البرامج والجامعات والتأشيرات والإجراءات.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6),
        ),
        if (suggested.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text('اقتراحات لك:',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  fontSize: 13)),
          const SizedBox(height: 12),
          ...suggested.map((q) => _SuggestedChip(text: q, onTap: onTap)),
        ] else ...[
          const SizedBox(height: 28),
          ..._defaultQ.map((q) => _SuggestedChip(text: q, onTap: onTap)),
        ],
      ],
    );
  }

  static const _defaultQ = [
    'ما هي الجامعات المتاحة في تركيا؟',
    'كيف أبدأ بالتقديم على برنامج دراسي؟',
    'ما المستندات المطلوبة للتأشيرة؟',
    'ما الفرق بين البكالوريوس والماجستير المتاح؟',
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.chevron_left_rounded,
                color: AppColors.navy, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.navy,
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
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.orange, size: 14),
            ),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.navy : Colors.white,
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
              child: Text(
                msg.content,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : msg.isError
                          ? AppColors.danger
                          : AppColors.textPrimary,
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
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.orange, size: 14),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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
        color: Colors.white,
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
              textDirection: TextDirection.rtl,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'اكتب سؤالك هنا…',
                hintStyle: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF3F6FA),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
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
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome_rounded,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text('Birds AI غير متاح حالياً',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
          SizedBox(height: 8),
          Text('سيتم تفعيل المساعد الذكي قريباً.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.textSecondary, height: 1.6)),
        ]),
      ),
    );
  }
}
