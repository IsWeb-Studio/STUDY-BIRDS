import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/admin_modules_repository.dart';
import '../services_support/support_team_ai_screens.dart' show ticketStatusMeta;

class AdminSupportTicketsScreen extends StatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  State<AdminSupportTicketsScreen> createState() => _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState extends State<AdminSupportTicketsScreen> {
  List<dynamic> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminModulesRepository.instance.getSupportTickets();
      if (!mounted) return;
      setState(() {
        _tickets = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل التذاكر.';
        _loading = false;
      });
    }
  }

  Future<void> _openReply(Map<String, dynamic> ticket) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ticket['subject'] as String? ?? 'تذكرة'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'اكتب ردك...'), maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('إرسال الرد')),
        ],
      ),
    );
    if (message == null || message.trim().isEmpty) return;
    try {
      final updated = await AdminModulesRepository.instance.replySupportTicket(ticket['_id'] as String, message: message.trim(), status: 'answered');
      if (!mounted) return;
      setState(() {
        _tickets = _tickets.map((t) => (t as Map<String, dynamic>)['_id'] == updated['_id'] ? updated : t).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر إرسال الرد')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تذاكر الدعم',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _tickets.isEmpty
                    ? const EmptyState(icon: Icons.confirmation_number_outlined, title: 'لا توجد تذاكر', message: 'ستظهر هنا تذاكر الدعم من الطلاب والوكلاء.')
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tickets.length,
                      itemBuilder: (context, i) {
                        final ticket = _tickets[i] as Map<String, dynamic>;
                        final requester = ticket['student'] as Map<String, dynamic>? ?? ticket['user'] as Map<String, dynamic>?;
                        final meta = ticketStatusMeta(ticket['status'] as String?);
                        return AppCard(
                          onTap: () => _openReply(ticket),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(ticket['subject'] as String? ?? '—', style: AppTextStyles.cardTitle)),
                                  StatusBadge(label: meta.label, color: meta.color),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(requester?['name'] as String? ?? '—', style: AppTextStyles.caption),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}

class AdminKnowledgeBaseScreen extends StatefulWidget {
  const AdminKnowledgeBaseScreen({super.key});

  @override
  State<AdminKnowledgeBaseScreen> createState() => _AdminKnowledgeBaseScreenState();
}

class _AdminKnowledgeBaseScreenState extends State<AdminKnowledgeBaseScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminModulesRepository.instance.getKnowledgeBase();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المحتوى.';
        _loading = false;
      });
    }
  }

  Future<void> _openCreateForm() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مقال جديد', style: AppTextStyles.cardTitle),
            const SizedBox(height: 10),
            TextField(controller: titleController, decoration: const InputDecoration(hintText: 'العنوان')),
            const SizedBox(height: 10),
            TextField(controller: bodyController, decoration: const InputDecoration(hintText: 'المحتوى'), maxLines: 5),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'نشر',
              onPressed: () async {
                if (titleController.text.trim().isEmpty || bodyController.text.trim().isEmpty) return;
                try {
                  await AdminModulesRepository.instance.createKnowledgeBaseItem(title: titleController.text.trim(), body: bodyController.text.trim());
                  if (context.mounted) Navigator.of(context).pop(true);
                } catch (_) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر النشر')));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(String id) async {
    try {
      await AdminModulesRepository.instance.deleteKnowledgeBaseItem(id);
      if (mounted) setState(() => _items.removeWhere((i) => (i as Map<String, dynamic>)['_id'] == id));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الحذف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مركز المعرفة',
      actions: [IconButton(onPressed: _openCreateForm, icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white))],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(icon: Icons.menu_book_outlined, title: 'لا يوجد محتوى', message: 'أضف أول مقال من زر الإضافة أعلى الشاشة.', ctaLabel: 'إضافة', onCta: _openCreateForm)
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i] as Map<String, dynamic>;
                        return AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['title'] as String? ?? '—', style: AppTextStyles.cardTitle),
                                    Text(item['body'] as String? ?? '', style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _delete(item['_id'] as String)),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}
