import '../services_support/messaging_and_emergency_screens.dart';
import '../profile_account/security_settings_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/agent_repository.dart';
import 'agent_student_detail_screen.dart';
import 'agent_program_pricing_screen.dart';

class AgentStudentStatusMeta {
  final String label;
  final Color color;
  const AgentStudentStatusMeta(this.label, this.color);
}

AgentStudentStatusMeta agentStudentStatusMeta(String? status) {
  switch (status) {
    case 'preliminary-accepted':
      return const AgentStudentStatusMeta('قبول مبدئي', AppColors.info);
    case 'final-accepted':
      return const AgentStudentStatusMeta('قبول نهائي', AppColors.success);
    case 'rejected':
      return const AgentStudentStatusMeta('مرفوض', AppColors.danger);
    case 'under-review':
    default:
      return const AgentStudentStatusMeta('قيد المراجعة', AppColors.warning);
  }
}

/// Agent Mode Home — student-management-first. Real data from
/// server/src/routes/partnerRoutes.js.
class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  Map<String, dynamic>? _overview;
  List<dynamic> _students = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String? _statusFilter; // null = all

  static const _statusOptions = [
    (key: 'under-review', label: 'قيد المراجعة'),
    (key: 'preliminary-accepted', label: 'قبول مبدئي'),
    (key: 'final-accepted', label: 'قبول نهائي'),
    (key: 'rejected', label: 'مرفوض'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
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
      final results = await Future.wait([
        AgentRepository.instance.getOverview(),
        AgentRepository.instance.getStudents(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _students = results[1] as List<dynamic>;
        _loading = false;
      });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل بيانات لوحتك.';
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _students.where((s) {
        final student = s as Map<String, dynamic>;
        final nameMatch = q.isEmpty ||
            (student['name'] as String? ?? '').toLowerCase().contains(q) ||
            (student['desiredUniversity'] as String? ?? '').toLowerCase().contains(q);
        final statusMatch = _statusFilter == null ||
            student['applicationStatus'] == _statusFilter;
        return nameMatch && statusMatch;
      }).toList();
    });
  }

  Future<void> _openAddStudent() async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AddAgentStudentScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _overview?['stats'] as Map<String, dynamic>? ?? {};

    return AppScaffold(
      title: 'لوحة الوكيل',
      actions: [
        IconButton(
            tooltip: 'الرسائل',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConversationThreadScreen()))),
        IconButton(
            tooltip: 'أمان الحساب',
            icon: const Icon(Icons.security),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SecuritySettingsScreen()))),
        IconButton(
            onPressed: _openAddStudent,
            icon:
                const Icon(Icons.person_add_alt_rounded, color: Colors.white)),
        IconButton(
          icon: const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white),
          tooltip: 'محفظتي',
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyCommissionsScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.sell_outlined, color: Colors.white),
          tooltip: 'أسعار الوكلاء',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AgentProgramPricingScreen())),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري تحميل لوحتك...')
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _StatCard(
                                value: '${stats['totalStudents'] ?? 0}',
                                label: 'إجمالي طلابي')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _StatCard(
                                value: '${stats['acceptedStudents'] ?? 0}',
                                label: 'مقبولين')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _StatCard(
                                value:
                                    '\$${stats['totalReceivedEarnings'] ?? 0}',
                                label: 'عمولتي المستلمة')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.border)),
                      child: TextField(
                        controller: _searchController,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          hintText: 'ابحث باسم الطالب...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          prefixIcon:
                              Icon(Icons.search_rounded, color: AppColors.navy),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: 'الكل',
                            selected: _statusFilter == null,
                            onTap: () {
                              setState(() => _statusFilter = null);
                              _applyFilter();
                            },
                          ),
                          ..._statusOptions.map((opt) => _FilterChip(
                                label: opt.label,
                                selected: _statusFilter == opt.key,
                                color: agentStudentStatusMeta(opt.key).color,
                                onTap: () {
                                  setState(() => _statusFilter =
                                      _statusFilter == opt.key ? null : opt.key);
                                  _applyFilter();
                                },
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('طلابي', style: AppTextStyles.sectionLabel),
                        Text('${_filtered.length}',
                            style: AppTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_filtered.isEmpty)
                      const EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'لا يوجد طلاب بعد',
                          message: 'أضف أول طالب من زر الإضافة أعلى الشاشة.')
                    else
                      ..._filtered.map((s) {
                        final student = s as Map<String, dynamic>;
                        final meta = agentStudentStatusMeta(
                            student['applicationStatus'] as String?);
                        return AppCard(
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (_) => AgentStudentDetailScreen(
                                      studentId: student['_id'] as String,
                                      initialData: student)))
                              .then((_) => _load()),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.border,
                                  child: Icon(Icons.person_rounded,
                                      color: AppColors.navy, size: 18)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(student['name'] as String? ?? '—',
                                        style: AppTextStyles.cardTitle),
                                    Text(
                                        student['desiredUniversity']
                                                as String? ??
                                            student['email'] as String? ??
                                            '',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                              StatusBadge(label: meta.label, color: meta.color),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.navy;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: selected ? activeColor : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Text(value, style: AppTextStyles.screenTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class AddAgentStudentScreen extends StatefulWidget {
  const AddAgentStudentScreen({super.key});

  @override
  State<AddAgentStudentScreen> createState() => _AddAgentStudentScreenState();
}

class _AddAgentStudentScreenState extends State<AddAgentStudentScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _university = TextEditingController();
  final _program = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _university.dispose();
    _program.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) {
      setState(() => _error = 'الاسم والبريد ورقم الهاتف مطلوبين');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AgentRepository.instance.createStudent(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        desiredUniversity: _university.text.trim(),
        desiredProgram: _program.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'تعذر إضافة الطالب، تأكد من البيانات وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.border)),
            child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 12, horizontal: 12))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إضافة طالب جديد',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('الاسم الكامل', _name),
            _field('البريد الإلكتروني', _email),
            _field('رقم الهاتف', _phone),
            _field('الجامعة المطلوبة (اختياري)', _university),
            _field('البرنامج المطلوب (اختياري)', _program),
            if (_error != null) ...[
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              const SizedBox(height: 10),
            ],
            PrimaryButton(
                label: _saving ? 'جاري الحفظ...' : 'إضافة الطالب',
                onPressed: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }
}
