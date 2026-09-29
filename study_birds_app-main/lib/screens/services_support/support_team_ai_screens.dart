import 'package:url_launcher/url_launcher.dart';
import '../../core/document_access.dart';
import 'bird_ai_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_theme.dart';
import '../../core/analytics_service.dart';
import '../../core/student_repository.dart';
import 'faq_screen.dart';
import 'knowledge_base_screen.dart';
import 'messaging_and_emergency_screens.dart';

class TicketStatusMeta {
  final String label;
  final Color color;
  const TicketStatusMeta(this.label, this.color);
}

TicketStatusMeta ticketStatusMeta(String? status) {
  switch (status) {
    case 'in-progress':
      return const TicketStatusMeta('قيد المعالجة', AppColors.info);
    case 'answered':
      return const TicketStatusMeta('تم الرد', AppColors.success);
    case 'closed':
      return const TicketStatusMeta('مغلقة', AppColors.neutral);
    case 'open':
    default:
      return const TicketStatusMeta('مفتوحة', AppColors.warning);
  }
}

String _categoryLabel(String? key) {
  return StudentRepository.supportCategories.firstWhere((c) => c['key'] == key,
      orElse: () => {'label': key ?? '—'})['label']!;
}

class SupportCenterScreen extends StatelessWidget {
  const SupportCenterScreen({super.key});

  static const List<Map<String, dynamic>> _options = [
    {'label': 'تذكرة دعم جديدة', 'icon': Icons.confirmation_number_outlined},
    {'label': 'تذاكري', 'icon': Icons.list_alt_rounded},
    {'label': 'فريقي', 'icon': Icons.groups_outlined},
    {'label': 'مركز المعرفة', 'icon': Icons.menu_book_outlined},
    {'label': 'محطة المعارض', 'icon': Icons.article_outlined},
    {'label': 'مساعدة عاجلة', 'icon': Icons.emergency_share_rounded},
    {'label': 'الأسئلة الشائعة', 'icon': Icons.help_outline_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مركز الدعم',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final o = _options[i];
          return AppCard(
            margin: EdgeInsets.zero,
            onTap: () {
              if (o['label'] == 'تذكرة دعم جديدة') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NewSupportTicketScreen()));
              } else if (o['label'] == 'تذاكري') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SupportTicketsListScreen()));
              } else if (o['label'] == 'الأسئلة الشائعة') {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const FaqScreen()));
              } else if (o['label'] == 'فريقي') {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyTeamScreen()));
              } else if (o['label'] == 'مركز المعرفة') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const KnowledgeBaseScreen()));
              } else if (o['label'] == 'محطة المعارض') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ExhibitionsScreen()));
              } else if (o['label'] == 'مساعدة عاجلة') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const EmergencySupportScreen()));
              }
            },
            child: Row(
              children: [
                Icon(o['icon'] as IconData, color: AppColors.navy, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(o['label'] as String,
                        style: AppTextStyles.cardTitle)),
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: AppColors.textSecondary),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NewSupportTicketScreen extends StatefulWidget {
  final VoidCallback? onSubmit;
  final String initialSubject;
  const NewSupportTicketScreen(
      {super.key, this.onSubmit, this.initialSubject = ''});

  @override
  State<NewSupportTicketScreen> createState() => _NewSupportTicketScreenState();
}

class _NewSupportTicketScreenState extends State<NewSupportTicketScreen> {
  @override
  void initState() {
    super.initState();
    _subject.text = widget.initialSubject;
    if (widget.initialSubject.isNotEmpty) _category = 'other';
  }

  String _category = StudentRepository.supportCategories.first['key']!;
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _submitting = false;
  String? _error;
  PlatformFile? _attachedFile;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _attachedFile = result.files.single);
    }
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _error = 'الموضوع والرسالة مطلوبين');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await StudentRepository.instance.createSupportTicket(
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        category: _category,
        fileBytes: _attachedFile?.bytes,
        fileName: _attachedFile?.name,
      );
      if (!mounted) return;
      widget.onSubmit?.call();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'تعذر إرسال التذكرة، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تذكرة دعم جديدة',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الفئة', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(color: AppColors.border)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _category,
                  items: StudentRepository.supportCategories
                      .map((c) => DropdownMenuItem(
                          value: c['key'], child: Text(c['label']!)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('الموضوع', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(color: AppColors.border)),
              child: TextField(
                  controller: _subject,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 12))),
            ),
            const SizedBox(height: 14),
            const Text('الرسالة', style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(color: AppColors.border)),
              child: TextField(
                  controller: _message,
                  maxLines: 5,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12))),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(_attachedFile?.name ?? 'إرفاق ملف'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
                label: _submitting ? 'جاري الإرسال...' : 'إرسال',
                onPressed: _submitting ? null : _submit),
          ],
        ),
      ),
    );
  }
}

class SupportTicketsListScreen extends StatefulWidget {
  const SupportTicketsListScreen({super.key});

  @override
  State<SupportTicketsListScreen> createState() =>
      _SupportTicketsListScreenState();
}

class _SupportTicketsListScreenState extends State<SupportTicketsListScreen> {
  List<dynamic> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('support_tickets');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StudentRepository.instance.getSupportTickets();
      if (!mounted) return;
      setState(() {
        _tickets = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل تذاكرك.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تذاكري',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _tickets.isEmpty
                    ? EmptyState(
                        icon: Icons.confirmation_number_outlined,
                        title: 'لا توجد تذاكر بعد',
                        message: 'أنشئ تذكرة جديدة لو محتاج مساعدة.',
                        ctaLabel: 'تذكرة دعم جديدة',
                        onCta: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const NewSupportTicketScreen())))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length,
                        itemBuilder: (context, i) {
                          final t = _tickets[i] as Map<String, dynamic>;
                          final meta = ticketStatusMeta(t['status'] as String?);
                          return AppCard(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        SupportTicketDetailScreen(ticket: t))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t['subject'] as String? ?? '—',
                                          style: AppTextStyles.cardTitle),
                                      Text(
                                          _categoryLabel(
                                              t['category'] as String?),
                                          style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                    label: meta.label, color: meta.color),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class SupportTicketDetailScreen extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const SupportTicketDetailScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final attachment = ticket['attachment'] as Map<String, dynamic>?;
    final replies = ticket['replies'] as List<dynamic>? ?? [];
    final meta = ticketStatusMeta(ticket['status'] as String?);

    return AppScaffold(
      title: ticket['subject'] as String? ?? 'تذكرة دعم',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(label: meta.label, color: meta.color)),
          const SizedBox(height: 16),
          if (attachment?['filePath'] is String)
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(attachment?['fileName'] as String? ?? 'فتح المرفق'),
              onPressed: () async {
                try {
                  final uri = await resolveDocumentDownload(
                      attachment!['filePath'] as String);
                  if (!await launchUrl(uri,
                      mode: LaunchMode.externalApplication))
                    throw Exception('Cannot open attachment');
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'تعذر فتح المرفق. تحقق من الجلسة والصلاحيات.')));
                }
              },
            ),
          ...replies.map((r) {
            final reply = r as Map<String, dynamic>;
            final isStudent = reply['fromRole'] == 'student';
            return Align(
              alignment:
                  isStudent ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isStudent ? AppColors.navy : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      isStudent ? null : Border.all(color: AppColors.border),
                ),
                child: Text(reply['message'] as String? ?? '',
                    style: TextStyle(
                        color: isStudent ? Colors.white : AppColors.textPrimary,
                        fontSize: 13.5)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});
  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  DashboardOverview? _overview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await StudentRepository.instance.getOverview();
      if (mounted) setState(() => _overview = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل بيانات الفريق.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = _overview?.home;
    final consultantName = home?['consultantName'] as String?
        ?? home?['consultant'] as String?
        ?? _overview?.profile?['consultantName'] as String?;

    return AppScaffold(
      title: 'فريقي',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري تحميل الفريق...')
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const Text(
                          'هذا هو الفريق المخصص لك في Study Birds. يمكنك التواصل معهم مباشرة عبر المحادثة.',
                          style: AppTextStyles.body),
                      const SizedBox(height: 20),
                      _TeamMemberCard(
                        role: 'المستشار التعليمي',
                        name: consultantName?.isNotEmpty == true
                            ? consultantName!
                            : 'سيتم تعيين مستشارك قريبًا',
                        icon: Icons.school_rounded,
                        available: consultantName?.isNotEmpty == true,
                        onMessage: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ConversationThreadScreen())),
                      ),
                      const SizedBox(height: 12),
                      _TeamMemberCard(
                        role: 'مسؤول القبول',
                        name: 'فريق القبول',
                        icon: Icons.assignment_ind_rounded,
                        available: true,
                        onMessage: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ConversationThreadScreen())),
                      ),
                      const SizedBox(height: 12),
                      _TeamMemberCard(
                        role: 'منسق الدعم',
                        name: 'فريق الدعم',
                        icon: Icons.support_agent_rounded,
                        available: true,
                        onMessage: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ConversationThreadScreen())),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final String role;
  final String name;
  final IconData icon;
  final bool available;
  final VoidCallback onMessage;

  const _TeamMemberCard({
    required this.role,
    required this.name,
    required this.icon,
    required this.available,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.navy, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(name, style: AppTextStyles.cardTitle),
              ],
            ),
          ),
          if (available)
            IconButton(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.navy),
              tooltip: 'مراسلة',
            ),
        ],
      ),
    );
  }
}

class BirdAIChatScreen extends StatelessWidget {
  const BirdAIChatScreen({super.key});
  @override
  Widget build(BuildContext context) => const BirdAssistantScreen();
}
