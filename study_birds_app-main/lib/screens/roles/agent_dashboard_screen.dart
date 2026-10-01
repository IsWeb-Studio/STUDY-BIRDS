import '../services_support/messaging_and_emergency_screens.dart';
import '../profile_account/security_settings_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/agent_repository.dart';
import 'agent_student_detail_screen.dart';
import 'agent_program_pricing_screen.dart';

// ─── status metadata ────────────────────────────────────────────────────────

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

// ─── dashboard ───────────────────────────────────────────────────────────────

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
  String? _statusFilter;
  String? _stageFilter;

  static const _statusOptions = [
    (key: 'under-review', label: 'قيد المراجعة'),
    (key: 'preliminary-accepted', label: 'قبول مبدئي'),
    (key: 'final-accepted', label: 'قبول نهائي'),
    (key: 'rejected', label: 'مرفوض'),
  ];

  static const _stageOptions = [
    (key: 'initial', label: 'استشارة مبدئية'),
    (key: 'documents', label: 'جمع الوثائق'),
    (key: 'submitted', label: 'تم التقديم'),
    (key: 'admission', label: 'القبول'),
    (key: 'visa', label: 'التأشيرة'),
    (key: 'enrolled', label: 'مسجّل'),
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
    setState(() { _loading = true; _error = null; });
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
      setState(() { _error = 'تعذر تحميل بيانات لوحتك.'; _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _students.where((s) {
        final st = s as Map<String, dynamic>;
        final nameMatch = q.isEmpty ||
            (st['name'] as String? ?? '').toLowerCase().contains(q) ||
            (st['desiredUniversity'] as String? ?? '').toLowerCase().contains(q) ||
            (st['country'] as String? ?? '').toLowerCase().contains(q);
        final statusMatch = _statusFilter == null || st['applicationStatus'] == _statusFilter;
        final stageMatch = _stageFilter == null || st['applicationStage'] == _stageFilter;
        return nameMatch && statusMatch && stageMatch;
      }).toList();
    });
  }

  String _stageLabel(String stage) {
    for (final opt in _stageOptions) {
      if (opt.key == stage) return opt.label;
    }
    return stage;
  }

  Future<void> _openAddStudent() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(builder: (_) => const AddAgentStudentScreen()));
    if (!mounted) return;
    if (result != null) {
      final name = result['name'] ?? 'الطالب';
      await _load();
      if (!mounted) return;
      _showAddedDialog(name);
    }
  }

  void _showAddedDialog(String studentName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 34),
            ),
            const SizedBox(height: 16),
            Text(studentName, style: AppTextStyles.cardTitle.copyWith(fontSize: 17), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'تمت إضافة الطالب بنجاح وهو الآن في قائمة الانتظار للمراجعة والموافقة من فريق Study Birds.\n\nيمكنك رفع مستنداته ومتابعة حالته من لوحتك.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً، فهمت'),
          ),
        ],
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'لوحة الوكيل',
      actions: [
        IconButton(tooltip: 'الرسائل', icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversationThreadScreen()))),
        IconButton(tooltip: 'أمان الحساب', icon: const Icon(Icons.security),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()))),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState(message: 'جاري تحميل لوحتك...')
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final stats = _overview?['stats'] as Map<String, dynamic>? ?? {};
    final pending = _students.where((s) => (s as Map)['applicationStatus'] == 'under-review').length;
    final accepted = (stats['acceptedStudents'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── hero banner ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, Color(0xFF1B3A6B)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مرحباً بك', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('لوحة تحكم الوكيل', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // summary row
              Row(
                children: [
                  _HeroBadge(value: '${stats['totalStudents'] ?? 0}', label: 'إجمالي الطلاب', icon: Icons.people_rounded),
                  const SizedBox(width: 10),
                  _HeroBadge(value: '$accepted', label: 'مقبولين', icon: Icons.check_circle_rounded, color: Colors.greenAccent),
                  const SizedBox(width: 10),
                  _HeroBadge(value: '$pending', label: 'قيد المراجعة', icon: Icons.hourglass_top_rounded, color: Colors.orangeAccent),
                ],
              ),
              if ((stats['pendingEarnings'] as num? ?? 0) > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: Colors.orangeAccent, size: 18),
                      const SizedBox(width: 8),
                      Text('\$${stats['pendingEarnings']} عمولات معلّقة', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyCommissionsScreen())),
                        child: const Text('عرض ←', style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── quick actions ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              _ActionTile(icon: Icons.person_add_alt_rounded, label: 'إضافة طالب', color: AppColors.navy, onTap: _openAddStudent),
              const SizedBox(width: 10),
              _ActionTile(icon: Icons.account_balance_wallet_outlined, label: 'محفظتي', color: AppColors.success, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyCommissionsScreen()))),
              const SizedBox(width: 10),
              _ActionTile(icon: Icons.sell_outlined, label: 'الأسعار', color: AppColors.warning, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgentProgramPricingScreen()))),
              const SizedBox(width: 10),
              _ActionTile(icon: Icons.forum_outlined, label: 'الرسائل', color: AppColors.info, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConversationThreadScreen()))),
            ],
          ),
        ),

        // ── notifications ────────────────────────────────────────────────
        _NotificationsSection(overview: _overview),

        // ── students section ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('قائمة الطلاب', style: AppTextStyles.sectionLabel),
                  GestureDetector(
                    onTap: _openAddStudent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text('إضافة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // search bar
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.border)),
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    hintText: 'ابحث بالاسم أو الجامعة أو البلد...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.navy),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // status filter row
              _FilterSection(
                label: 'الحالة',
                children: [
                  _FilterChip(label: 'الكل', selected: _statusFilter == null, onTap: () { setState(() => _statusFilter = null); _applyFilter(); }),
                  ..._statusOptions.map((opt) => _FilterChip(
                    label: opt.label,
                    selected: _statusFilter == opt.key,
                    color: agentStudentStatusMeta(opt.key).color,
                    onTap: () { setState(() => _statusFilter = _statusFilter == opt.key ? null : opt.key); _applyFilter(); },
                  )),
                ],
              ),
              const SizedBox(height: 8),

              // stage filter row
              _FilterSection(
                label: 'المرحلة',
                children: [
                  _FilterChip(label: 'الكل', selected: _stageFilter == null, onTap: () { setState(() => _stageFilter = null); _applyFilter(); }),
                  ..._stageOptions.map((opt) => _FilterChip(
                    label: opt.label,
                    selected: _stageFilter == opt.key,
                    color: AppColors.info,
                    onTap: () { setState(() => _stageFilter = _stageFilter == opt.key ? null : opt.key); _applyFilter(); },
                  )),
                ],
              ),
              const SizedBox(height: 14),

              // count
              Text(
                '${_filtered.length} طالب',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // ── student cards ────────────────────────────────────────────────
        if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: EmptyState(icon: Icons.people_outline_rounded, title: 'لا يوجد طلاب', message: 'أضف أول طالب من زر "إضافة" أعلاه.'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _filtered.map((s) {
                final student = s as Map<String, dynamic>;
                final meta = agentStudentStatusMeta(student['applicationStatus'] as String?);
                final name = student['name'] as String? ?? '—';
                final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
                final subtitle = [
                  if ((student['desiredUniversity'] as String?)?.isNotEmpty == true) student['desiredUniversity'] as String,
                  if ((student['country'] as String?)?.isNotEmpty == true) student['country'] as String,
                ].join(' · ');
                final stage = student['applicationStage'] as String?;

                return _StudentCard(
                  initials: initials,
                  name: name,
                  subtitle: subtitle.isNotEmpty ? subtitle : (student['email'] as String? ?? ''),
                  stage: stage != null ? _stageLabel(stage) : null,
                  statusLabel: meta.label,
                  statusColor: meta.color,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => AgentStudentDetailScreen(
                            studentId: student['_id'] as String,
                            initialData: student,
                          )))
                      .then((_) => _load()),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── notifications section ───────────────────────────────────────────────────

class _NotificationsSection extends StatelessWidget {
  final Map<String, dynamic>? overview;
  const _NotificationsSection({required this.overview});

  static const _typeColors = {
    'warning': AppColors.danger,
    'success': AppColors.success,
    'info': AppColors.info,
  };

  static const _typeIcons = {
    'warning': Icons.warning_amber_rounded,
    'success': Icons.check_circle_rounded,
    'info': Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final notifications = (overview?['notifications'] as List<dynamic>?) ?? [];
    if (notifications.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text('الإشعارات', style: AppTextStyles.sectionLabel),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${notifications.where((n) => (n as Map)['isRead'] != true).length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...notifications.take(5).map((n) {
            final notif = n as Map<String, dynamic>;
            final type = notif['type'] as String? ?? 'info';
            final color = _typeColors[type] ?? AppColors.info;
            final icon = _typeIcons[type] ?? Icons.info_rounded;
            final isRead = notif['isRead'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRead ? Colors.white : color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRead ? AppColors.border : color.withValues(alpha: 0.3),
                  width: isRead ? 1 : 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 17, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif['title'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notif['message'] as String? ?? '',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 3, right: 2),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── hero badge ─────────────────────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;
  const _HeroBadge({required this.value, required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: c.withValues(alpha: 0.8), fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── action tile ─────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 7),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── filter section ──────────────────────────────────────────────────────────

class _FilterSection extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _FilterSection({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── filter chip ─────────────────────────────────────────────────────────────

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
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: selected ? activeColor : AppColors.border),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        )),
      ),
    );
  }
}

// ─── student card ─────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final String initials;
  final String name;
  final String subtitle;
  final String? stage;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
  const _StudentCard({
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    this.stage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initials, style: const TextStyle(color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.cardTitle),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if (stage != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(stage!, style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: statusLabel, color: statusColor),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── add student screen ────────────────────────────────────────────────────

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
  final _country = TextEditingController();
  String _stage = 'initial';
  bool _saving = false;
  String? _error;

  static const _stageOptions = [
    (key: 'initial', label: 'استشارة مبدئية'),
    (key: 'documents', label: 'جمع الوثائق'),
    (key: 'submitted', label: 'تم التقديم'),
    (key: 'admission', label: 'القبول'),
    (key: 'visa', label: 'التأشيرة'),
    (key: 'enrolled', label: 'مسجّل'),
  ];

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose();
    _university.dispose(); _program.dispose(); _country.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _error = 'الاسم والبريد ورقم الهاتف مطلوبين');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final name = _name.text.trim();
      await AgentRepository.instance.createStudent(
        name: name,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        desiredUniversity: _university.text.trim(),
        desiredProgram: _program.text.trim(),
        country: _country.text.trim(),
        applicationStage: _stage,
      );
      if (mounted) Navigator.of(context).pop({'name': name});
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إضافة الطالب، تأكد من البيانات وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? type, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.caption),
              if (required)
                const Text(' *', style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: AppColors.border)),
            child: TextField(
                controller: controller,
                keyboardType: type,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 14))),
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
            // info banner
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'بعد الإضافة سيكون الطالب في انتظار مراجعة فريق Study Birds قبل البدء باستعراض التقديم.',
                      style: TextStyle(fontSize: 12, color: AppColors.info, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            _field('الاسم الكامل', _name, required: true),
            _field('البريد الإلكتروني', _email, type: TextInputType.emailAddress, required: true),
            _field('رقم الهاتف', _phone, type: TextInputType.phone, required: true),
            _field('بلد الدراسة', _country),
            _field('الجامعة المطلوبة', _university),
            _field('البرنامج المطلوب', _program),
            // stage selector
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مرحلة التقديم الحالية', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _stageOptions.map((opt) {
                      final sel = _stage == opt.key;
                      return GestureDetector(
                        onTap: () => setState(() => _stage = opt.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.info : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            border: Border.all(color: sel ? AppColors.info : AppColors.border),
                          ),
                          child: Text(opt.label, style: TextStyle(
                            color: sel ? Colors.white : AppColors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: _saving ? 'جاري الحفظ...' : 'إضافة الطالب',
              onPressed: _saving ? null : _submit,
              icon: Icons.person_add_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
