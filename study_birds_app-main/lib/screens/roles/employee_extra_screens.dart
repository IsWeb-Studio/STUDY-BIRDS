import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/repositories/employee_repository.dart';
import '../services_support/messaging_and_emergency_screens.dart' show ConversationThreadScreen;
import 'admin_content_crud_screens.dart' show AdminServicesScreen;

/// Real data from GET /api/admin/students — ALL students on the platform.
/// Relabeled honestly: the backend has no per-employee assignment, so this
/// isn't "my" students, it's every student. Search/filter locally for now.
class MyStudentsQueueScreen extends StatefulWidget {
  const MyStudentsQueueScreen({super.key});

  @override
  State<MyStudentsQueueScreen> createState() => _MyStudentsQueueScreenState();
}

class _MyStudentsQueueScreenState extends State<MyStudentsQueueScreen> {
  List<dynamic> _students = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await EmployeeRepository.instance.getAllStudents();
      if (!mounted) return;
      setState(() {
        _students = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل قائمة الطلاب.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _students
        : _students.where((s) => ((s as Map<String, dynamic>)['name'] as String? ?? '').toLowerCase().contains(q)).toList();

    return AppScaffold(
      title: 'كل الطلاب',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(hintText: 'ابحث باسم الطالب...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12), prefixIcon: Icon(Icons.search_rounded, color: AppColors.navy)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingState(message: 'جاري تحميل الطلاب...')
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : filtered.isEmpty
                        ? const EmptyState(icon: Icons.people_outline_rounded, title: 'لا يوجد طلاب', message: 'لا توجد نتائج مطابقة.')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final s = filtered[i] as Map<String, dynamic>;
                              final profile = s['profile'] as Map<String, dynamic>?;
                              final stage = profile?['applicationStage'] as String?;
                              return AppCard(
                                child: Row(
                                  children: [
                                    const CircleAvatar(radius: 20, backgroundColor: AppColors.border, child: Icon(Icons.person_rounded, color: AppColors.navy, size: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s['name'] as String? ?? '—', style: AppTextStyles.cardTitle),
                                          Text(s['email'] as String? ?? '', style: AppTextStyles.caption),
                                        ],
                                      ),
                                    ),
                                    if (stage != null) StatusBadge(label: stage, color: AppColors.info),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class MessageThread {
  final String name;
  final String lastMessage;
  final String time;
  final bool unread;
  const MessageThread({required this.name, required this.lastMessage, required this.time, this.unread = false});
}

class MessagesInboxScreen extends StatelessWidget {
  const MessagesInboxScreen({super.key});

  static const List<MessageThread> _threads = [
    MessageThread(name: 'أحمد خالد', lastMessage: 'هل الترجمة المعتمدة مقبولة؟', time: '10:24 ص', unread: true),
    MessageThread(name: 'جامعة إسطنبول التقنية', lastMessage: 'تم استلام الطلب، جاري المراجعة', time: 'أمس'),
    MessageThread(name: 'منى سالم', lastMessage: 'شكرًا جزيلًا على المساعدة!', time: 'أمس'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الرسائل (تجريبي)',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _threads.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text('بيانات توضيحية — الباك اند لسه مفيهوش نظام رسائل حقيقي بين الموظف والطالب.', style: TextStyle(color: AppColors.warning, fontSize: 12)),
            );
          }
          final t = _threads[i - 1];
          return AppCard(
            margin: EdgeInsets.zero,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ConversationThreadScreen(contactName: t.name))),
            child: Row(
              children: [
                const CircleAvatar(radius: 20, backgroundColor: AppColors.border, child: Icon(Icons.person_rounded, color: AppColors.navy, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: t.unread ? AppTextStyles.cardTitle : AppTextStyles.body),
                      Text(t.lastMessage, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t.time, style: AppTextStyles.caption),
                    if (t.unread) Container(margin: const EdgeInsets.only(top: 4), width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Manager Overview — spec point 110: short indicators only, not a full ERP.
/// Real platform-wide numbers from GET /api/admin/overview. These are NOT
/// personal-to-this-employee (the backend has no such concept) — they're
/// the whole platform's numbers, labeled honestly as such.
class ManagerOverviewScreen extends StatefulWidget {
  const ManagerOverviewScreen({super.key});

  @override
  State<ManagerOverviewScreen> createState() => _ManagerOverviewScreenState();
}

class _ManagerOverviewScreenState extends State<ManagerOverviewScreen> {
  Map<String, dynamic>? _overview;
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
      final data = await EmployeeRepository.instance.getOverview();
      if (!mounted) return;
      setState(() {
        _overview = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل نظرة عامة على المنصة.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'نظرة عامة على المنصة',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري التحميل...')
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _buildContent(_overview!),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> overview) {
    final stats = overview['stats'] as Map<String, dynamic>? ?? {};
    final metrics = [
      {'label': 'إجمالي الطلاب', 'value': '${stats['students'] ?? 0}', 'color': AppColors.info},
      {'label': 'إجمالي الطلبات', 'value': '${stats['applications'] ?? 0}', 'color': AppColors.navy},
      {'label': 'قيد المراجعة', 'value': '${stats['underReviewApplications'] ?? 0}', 'color': AppColors.warning},
      {'label': 'تم تقديمها', 'value': '${stats['submittedApplications'] ?? 0}', 'color': AppColors.info},
      {'label': 'الجامعات', 'value': '${stats['universities'] ?? 0}', 'color': AppColors.success},
      {'label': 'البرامج', 'value': '${stats['programs'] ?? 0}', 'color': AppColors.success},
      {'label': 'الوكلاء (Partners)', 'value': '${stats['partners'] ?? 0}', 'color': AppColors.orange},
      {'label': 'حسابات غير نشطة', 'value': '${stats['inactiveUsers'] ?? 0}', 'color': AppColors.danger},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'إجماليات المنصة — نظرة عامة على جميع الحسابات والطلبات.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3),
          itemBuilder: (context, i) {
            final m = metrics[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(m['value'] as String, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: m['color'] as Color)),
                  Text(m['label'] as String, style: AppTextStyles.caption),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── طلبات الخدمات — للموظفين والمشرفين ─────────────────────────────────────

class EmployeeServiceRequestsScreen extends StatefulWidget {
  const EmployeeServiceRequestsScreen({super.key});
  @override
  State<EmployeeServiceRequestsScreen> createState() => _EmployeeServiceRequestsScreenState();
}

class _EmployeeServiceRequestsScreenState extends State<EmployeeServiceRequestsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error, _statusFilter;
  final _statuses = ['pending', 'assigned', 'in-progress', 'completed', 'cancelled'];
  final _statusLabels = {
    'pending': 'قيد الانتظار', 'assigned': 'تم التعيين',
    'in-progress': 'جارٍ', 'completed': 'مكتمل', 'cancelled': 'ملغي',
  };
  final _statusColors = {
    'pending': AppColors.warning, 'assigned': AppColors.navy,
    'in-progress': AppColors.orange, 'completed': AppColors.success,
    'cancelled': AppColors.textSecondary,
  };
  String? get _token => AuthSession.instance.token;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final url = '/service-requests${_statusFilter != null ? '?status=$_statusFilter' : ''}';
      final data = await ApiClient.instance.get(url, token: _token);
      if (mounted) setState(() { _requests = data is List ? data : []; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'تعذر تحميل الطلبات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(String id, Map<String, dynamic> body) async {
    try {
      await ApiClient.instance.patch('/service-requests/$id', token: _token, body: body);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(content: Text(e is ApiException ? e.message : 'تعذر التحديث')));
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'طلبات الخدمات',
    body: Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          _filterChip(null, 'الكل'),
          for (final s in _statuses) _filterChip(s, _statusLabels[s] ?? s),
        ]),
      ),
      Expanded(child: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _requests.isEmpty
                  ? const EmptyState(icon: Icons.inbox_outlined, title: 'لا توجد طلبات', message: '')
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.navy,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: _requests.length,
                        itemBuilder: (_, i) => _RequestCard(
                          key: ValueKey('${_requests[i]['_id']}:${_requests[i]['__v']}'),
                          req: _requests[i] as Map,
                          statusLabels: _statusLabels,
                          statusColors: _statusColors,
                          statuses: _statuses,
                          onUpdate: _update,
                        ),
                      ),
                    )),
    ]),
  );

  Widget _filterChip(String? val, String label) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _statusFilter == val,
      onSelected: (_) { setState(() => _statusFilter = val); _load(); },
      selectedColor: AppColors.navy,
      labelStyle: TextStyle(color: _statusFilter == val ? Colors.white : AppColors.navy),
    ),
  );
}

class _RequestCard extends StatefulWidget {
  final Map req;
  final Map<String, String> statusLabels;
  final Map<String, Color> statusColors;
  final List<String> statuses;
  final Future<void> Function(String id, Map<String, dynamic> body) onUpdate;
  const _RequestCard({super.key, required this.req, required this.statusLabels,
      required this.statusColors, required this.statuses, required this.onUpdate});
  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _expanded = false;
  late String _status;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = '${widget.req['status'] ?? 'pending'}';
    _noteCtrl.text = '${widget.req['staffNote'] ?? ''}';
  }
  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final studentName = (req['student'] as Map?)?['name'] ?? 'طالب';
    final color = widget.statusColors[_status] ?? AppColors.textSecondary;
    final label = widget.statusLabels[_status] ?? _status;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${req['serviceTitle'] ?? ''}', style: AppTextStyles.cardTitle),
            const SizedBox(height: 2),
            Text('$studentName', style: AppTextStyles.caption),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: Icon(_expanded ? Icons.expand_less : Icons.edit_outlined, size: 20, color: AppColors.navy),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ]),
        if (_expanded) ...[
          const Divider(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            value: _status,
            items: widget.statuses.map((s) => DropdownMenuItem(value: s, child: Text(widget.statusLabels[s] ?? s))).toList(),
            onChanged: (v) { if (v != null) setState(() => _status = v); },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظة داخلية للفريق', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
          const SizedBox(height: 8),
          Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(
            onPressed: _saving ? null : () async {
              setState(() => _saving = true);
              await widget.onUpdate('${req['_id']}', {'status': _status, 'staffNote': _noteCtrl.text.trim(), 'expectedVersion': req['__v'] ?? 0});
              if (mounted) setState(() { _saving = false; _expanded = false; });
            },
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ'),
          )),
        ],
      ]),
    );
  }
}

class EmployeeServicesHubScreen extends StatelessWidget {
  const EmployeeServicesHubScreen({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'الخدمات',
    body: ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmployeeServiceRequestsScreen())),
        child: const ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.receipt_long_rounded, color: AppColors.navy),
          title: Text('طلبات الخدمات', style: AppTextStyles.cardTitle),
          subtitle: Text('راجع وأدر طلبات الطلاب النشطة', style: AppTextStyles.caption),
          trailing: Icon(Icons.chevron_left)),
      ),
      const SizedBox(height: 8),
      AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminServicesScreen())),
        child: const ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.design_services_outlined, color: AppColors.navy),
          title: Text('كتالوج الخدمات', style: AppTextStyles.cardTitle),
          subtitle: Text('أضف وعدّل قائمة الخدمات المتاحة', style: AppTextStyles.caption),
          trailing: Icon(Icons.chevron_left)),
      ),
    ]),
  );
}
