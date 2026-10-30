import 'package:flutter/material.dart';

import '../../core/config/app_theme.dart';
import '../../core/repositories/community_repository.dart';
import '../roles/employee_community_screen.dart';

bool _adminCommunityArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _adminCommunityText(BuildContext context, String ar, String en) =>
    _adminCommunityArabic(context) ? ar : en;

/// A compact entry point into existing, server-authorized moderation tools.
/// Counts come from the backend and are never inferred from the loaded feed.
class AdminCommunityControlCenter extends StatefulWidget {
  const AdminCommunityControlCenter({super.key});

  @override
  State<AdminCommunityControlCenter> createState() =>
      _AdminCommunityControlCenterState();
}

class _AdminCommunityControlCenterState
    extends State<AdminCommunityControlCenter> {
  Map<String, dynamic>? _overview;
  bool _loading = false;
  String? _error;

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await CommunityRepository.instance.adminOverview();
      if (mounted) setState(() => _overview = overview);
    } catch (_) {
      if (mounted) {
        setState(() => _error = _adminCommunityText(
            context, 'تعذر تحميل إحصاءات المجتمع.', 'Could not load community insights.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _count(String key) => (_overview?[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ExpansionTile(
          key: const ValueKey('admin-community-control-center'),
          leading: const CircleAvatar(
            backgroundColor: AppColors.greenSoft,
            child: Icon(Icons.admin_panel_settings_outlined,
                color: AppColors.greenInk),
          ),
          title: Text(_adminCommunityText(
              context, 'مركز إدارة المجتمع', 'Community control center')),
          subtitle: Text(_adminCommunityText(
              context, 'إحصاءات فعلية وأدوات الإشراف الحالية',
              'Live counts and existing moderation tools')),
          onExpansionChanged: (expanded) {
            if (expanded && _overview == null) _load();
          },
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (_loading && _overview == null)
              const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_error != null && _overview == null)
              Row(children: [
                Expanded(child: Text(_error!)),
                IconButton(
                  tooltip: _adminCommunityText(context, 'إعادة المحاولة', 'Retry'),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ])
            else if (_overview != null) ...[
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth >= 520
                    ? (constraints.maxWidth - 24) / 4
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  _Metric(
                    width: width,
                    value: _count('publishedPosts'),
                    label: _adminCommunityText(context, 'منشورات منشورة', 'Published posts'),
                    icon: Icons.forum_outlined,
                  ),
                  _Metric(
                    width: width,
                    value: _count('activeStories'),
                    label: _adminCommunityText(context, 'قصص نشطة', 'Active stories'),
                    icon: Icons.auto_stories_outlined,
                  ),
                  _Metric(
                    width: width,
                    value: _count('openReports'),
                    label: _adminCommunityText(context, 'بلاغات مفتوحة', 'Open reports'),
                    icon: Icons.flag_outlined,
                    highlight: _count('openReports') > 0,
                  ),
                  _Metric(
                    width: width,
                    value: _count('recentActivity'),
                    label: _adminCommunityText(context, 'نشاط آخر 7 أيام', 'Activity · 7 days'),
                    icon: Icons.insights_outlined,
                  ),
                ]);
              }),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const EmployeeCommunityScreen()),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(_adminCommunityText(
                      context, 'فتح أدوات الإشراف', 'Open moderation tools')),
                ),
              ),
              if (_error != null)
                TextButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_adminCommunityText(context, 'تحديث البيانات', 'Refresh data')),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_adminCommunityText(
                    context, 'وسّع اللوحة لتحميل إحصاءات المجتمع.',
                    'Expand the panel to load community insights.')),
              ),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  final double width;
  final int value;
  final String label;
  final IconData icon;
  final bool highlight;

  const _Metric({
    required this.width,
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: highlight ? AppColors.greenSoft : AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  color: highlight ? AppColors.green : AppColors.navy, size: 19),
              const SizedBox(height: 6),
              Text('$value',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 20)),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption),
            ],
          ),
        ),
      );
}
