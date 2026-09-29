import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/feature_ui.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import 'support_team_ai_screens.dart';

class ConversationThreadScreen extends StatefulWidget {
  final String contactName;
  const ConversationThreadScreen({super.key, this.contactName = 'الرسائل'});
  @override
  State<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState extends State<ConversationThreadScreen> {
  List<dynamic> contacts = [], messages = [];
  Map? contact;
  HttpClient? _httpClient;
  StreamSubscription<String>? _sseSub;
  bool loading = true, sending = false, older = false;
  String? error;
  final text = TextEditingController();
  String? get token => AuthSession.instance.token;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    _httpClient?.close(force: true);
    text.dispose();
    super.dispose();
  }

  // Opens SSE connection to receive real-time messages from the server.
  void _connectSse() {
    _sseSub?.cancel();
    _httpClient?.close(force: true);
    final tok = token;
    if (tok == null) return;
    final baseUrl = ApiClient.instance.baseUrl;
    final uri = Uri.parse('$baseUrl/mobile-workspace/events');
    _httpClient = HttpClient();
    _httpClient!.getUrl(uri).then((req) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $tok');
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      return req.close();
    }).then((res) {
      _sseSub = res
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .listen((line) {
        if (!line.startsWith('data:')) return;
        try {
          final payload = jsonDecode(line.substring(5).trim());
          if (payload is! Map) return;
          final senderId = '${payload['sender']}';
          final currentId = '${contact?['_id']}';
          if (senderId != currentId || !mounted) return;
          setState(() {
            final existing = {'${payload['_id']}'};
            for (final m in messages) existing.add('${m['_id']}');
            if (!existing.contains('${payload['_id']}')) {
              messages = [...messages, payload];
            }
          });
          // Mark as read immediately
          ApiClient.instance.post('/mobile-workspace/messages/read',
              token: token, body: {'sender': senderId}).catchError((_) {});
        } catch (_) {}
      }, onError: (_) {
        // Reconnect after 5s on connection error
        if (mounted) Future.delayed(const Duration(seconds: 5), _connectSse);
      }, cancelOnError: true);
    }).catchError((_) {
      if (mounted) Future.delayed(const Duration(seconds: 5), _connectSse);
    });
  }

  Future<void> load({bool previous = false}) async {
    final selected = contact;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (selected == null) {
        final value = await ApiClient.instance
            .get('/mobile-workspace/contacts', token: token);
        if (mounted) setState(() => contacts = value as List);
      } else {
        final query = Uri(queryParameters: {
          'recipient': '${selected['_id']}',
          if (previous && messages.isNotEmpty)
            'before': '${messages.first['_id']}'
        }).query;
        final value = await ApiClient.instance
            .get('/mobile-workspace/messages?$query', token: token) as List;
        if (!mounted) return;
        setState(() {
          messages = previous ? [...value, ...messages] : value;
          older = value.length == 50;
        });
        await ApiClient.instance.post('/mobile-workspace/messages/read',
            token: token, body: {'sender': selected['_id']});
        // Start SSE real-time stream (replaces polling)
        _connectSse();
      }
    } catch (e) {
      if (mounted)
        setState(() => error = e is ApiException && e.statusCode == 404
            ? 'المحادثات لم تُفعّل على السيرفر بعد. يمكنك استخدام تذاكر الدعم.'
            : 'تعذر تحميل الرسائل. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final body = text.text.trim();
    if (body.isEmpty || contact == null || sending) return;
    setState(() => sending = true);
    try {
      final value = await ApiClient.instance.post('/mobile-workspace/messages',
          token: token, body: {'recipient': contact!['_id'], 'body': body});
      if (!mounted) return;
      setState(() {
        messages = [...messages, value];
        text.clear();
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException
                ? e.message
                : 'تعذر الإرسال؛ رسالتك محفوظة في الحقل')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
      title: contact?['name']?.toString() ?? 'الرسائل',
      actions: [
        if (contact != null)
          IconButton(
              tooltip: 'جهات الاتصال',
              onPressed: loading || sending
                  ? null
                  : () {
                      setState(() {
                        contact = null;
                        messages = [];
                        text.clear();
                      });
                      load();
                    },
              icon: const Icon(Icons.people_outline)),
        IconButton(
            tooltip: 'تحديث',
            onPressed: loading || sending ? null : load,
            icon: const Icon(Icons.refresh)),
      ],
      bottomBar: contact == null || error != null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                            child: TextField(
                                controller: text,
                                enabled: !sending,
                                maxLength: 4000,
                                minLines: 1,
                                maxLines: 4,
                                decoration: featureInput('رسالتك')
                                    .copyWith(counterText: ''))),
                        const SizedBox(width: 8),
                        IconButton.filled(
                            tooltip: 'إرسال',
                            onPressed: sending ? null : send,
                            icon: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.send_rounded)),
                      ]))),
      body: loading
          ? const LoadingState()
          : error != null
              ? FeatureBody(children: [
                  InlineNotice(error!, error: true),
                  PrimaryButton(label: 'إعادة المحاولة', onPressed: load),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const NewSupportTicketScreen())),
                      child: const Text('إرسال تذكرة دعم')),
                ])
              : contact == null
                  ? FeatureBody(children: [
                      const FeatureIntro(
                          title: 'تواصل مع فريقك',
                          subtitle: 'جهات الاتصال المتاحة حسب حسابك وطلباتك.',
                          icon: Icons.forum_outlined),
                      if (contacts.isEmpty)
                        const InlineNotice('لا توجد جهات اتصال متاحة حاليًا.'),
                      for (final row in contacts)
                        FeaturePanel(
                            child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                    child: Icon(Icons.person_outline)),
                                title: Text('${row['name']}',
                                    style: AppTextStyles.cardTitle),
                                trailing: const Icon(Icons.chevron_left),
                                onTap: () {
                                  setState(() => contact = row as Map);
                                  load();
                                })),
                    ])
                  : ListView(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      children: [
                          for (final row in messages.reversed)
                            Align(
                                alignment: '${row['sender']}' ==
                                        AuthSession.instance.currentUser?.id
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: Container(
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width *
                                              .8),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: '${row['sender']}' ==
                                              AuthSession
                                                  .instance.currentUser?.id
                                          ? AppColors.navy
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${row['body']}',
                                            style: TextStyle(
                                                color: '${row['sender']}' ==
                                                        AuthSession.instance
                                                            .currentUser?.id
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                                height: 1.5)),
                                        const SizedBox(height: 5),
                                        Text(
                                            '${row['createdAt'] ?? ''}'
                                                .replaceFirst('T', ' ')
                                                .split('.')
                                                .first,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: '${row['sender']}' ==
                                                        AuthSession.instance
                                                            .currentUser?.id
                                                    ? Colors.white70
                                                    : AppColors.textSecondary)),
                                        if ('${row['sender']}' ==
                                            AuthSession
                                                .instance.currentUser?.id)
                                          Text(
                                              row['readAt'] != null
                                                  ? 'مقروءة'
                                                  : 'تم الإرسال',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white70))
                                      ]),
                                )),
                          if (older)
                            TextButton(
                                onPressed: () => load(previous: true),
                                child: const Text('رسائل أقدم')),
                          if (messages.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('ابدأ المحادثة بإرسال رسالة.',
                                    textAlign: TextAlign.center)),
                        ]));
}

class EmergencySupportScreen extends StatelessWidget {
  const EmergencySupportScreen({super.key});

  static const _phone = '+905000000000';
  static const _whatsapp = 'https://wa.me/905000000000';

  Future<void> _launch(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw '';
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح التطبيق الخارجي')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مساعدة عاجلة',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.emergency_share_rounded,
                    color: AppColors.danger, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('خط الطوارئ متاح 24/7',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.danger)),
                      SizedBox(height: 4),
                      Text(
                        'للحالات الحرجة فقط: مشاكل في المطار، أزمات السكن، موعد السفارة الغد.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('تواصل فوري مع مسؤول الطوارئ',
              style: AppTextStyles.sectionLabel),
          const SizedBox(height: 14),
          _EmergencyButton(
            icon: Icons.phone_rounded,
            label: 'اتصل بمسؤول الطوارئ',
            subtitle: _phone,
            color: AppColors.success,
            onTap: () => _launch(context, 'tel:$_phone'),
          ),
          const SizedBox(height: 12),
          _EmergencyButton(
            icon: Icons.chat_rounded,
            label: 'تواصل عبر واتساب',
            subtitle: 'ردّ فوري خلال دقائق',
            color: const Color(0xFF25D366),
            onTap: () => _launch(context, _whatsapp),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          const Text('بديل: تذكرة دعم عاجلة',
              style: AppTextStyles.sectionLabel),
          const SizedBox(height: 8),
          const Text(
            'إذا لم تستطع الاتصال، أرسل تذكرة دعم وسيرد عليك الفريق فور رؤيتها.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'إرسال تذكرة عاجلة',
            icon: Icons.confirmation_number_outlined,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const NewSupportTicketScreen(
                    initialSubject: '[عاجل] '))),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('أو تحدّث مع فريقك',
              style: AppTextStyles.sectionLabel),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.message_outlined),
            label: const Text('فتح المحادثة الداخلية'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConversationThreadScreen())),
          ),
        ],
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _EmergencyButton(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white60, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
