import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/admin_modules_repository.dart';

class _SimpleAdminListScreen extends StatefulWidget {
  final String title;
  final Future<List<dynamic>> Function() fetchItems;
  final Widget Function(Map<String, dynamic> item) itemBuilder;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;

  const _SimpleAdminListScreen({
    required this.title,
    required this.fetchItems,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  State<_SimpleAdminListScreen> createState() => _SimpleAdminListScreenState();
}

class _SimpleAdminListScreenState extends State<_SimpleAdminListScreen> {
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
      final data = await widget.fetchItems();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل البيانات.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(icon: widget.emptyIcon, title: widget.emptyTitle, message: widget.emptyMessage)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, i) => widget.itemBuilder(_items[i] as Map<String, dynamic>),
                      ),
      ),
    );
  }
}

class AdminStudentNotificationsScreen extends StatelessWidget {
  const AdminStudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SimpleAdminListScreen(
      title: 'إشعارات الطلاب',
      fetchItems: () => AdminModulesRepository.instance.getStudentNotifications(),
      emptyIcon: Icons.notifications_off_outlined,
      emptyTitle: 'لا توجد إشعارات',
      emptyMessage: 'ستظهر هنا كل الإشعارات المرسلة للمستخدمين.',
      itemBuilder: (n) {
        final user = n['user'] as Map<String, dynamic>?;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n['title'] as String? ?? '', style: AppTextStyles.cardTitle),
              Text(n['message'] as String? ?? '', style: AppTextStyles.caption),
              const SizedBox(height: 4),
              Text('إلى: ${user?['name'] ?? '—'}', style: AppTextStyles.caption),
            ],
          ),
        );
      },
    );
  }
}

class AdminStudentFavoritesScreen extends StatelessWidget {
  const AdminStudentFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SimpleAdminListScreen(
      title: 'مفضلة الطلاب',
      fetchItems: () => AdminModulesRepository.instance.getStudentFavorites(),
      emptyIcon: Icons.favorite_border_rounded,
      emptyTitle: 'لا توجد مفضلات',
      emptyMessage: 'ستظهر هنا العناصر المفضلة لدى الطلاب.',
      itemBuilder: (f) {
        final student = f['student'] as Map<String, dynamic>?;
        final university = f['university'] as Map<String, dynamic>?;
        final program = f['program'] as Map<String, dynamic>?;
        return AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student?['name'] as String? ?? '—', style: AppTextStyles.cardTitle),
                    Text(university?['name'] as String? ?? program?['title'] as String? ?? '—', style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminOrientationResultsScreen extends StatelessWidget {
  const AdminOrientationResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SimpleAdminListScreen(
      title: 'نتائج اختبار التوجيه',
      fetchItems: () => AdminModulesRepository.instance.getOrientationResults(),
      emptyIcon: Icons.quiz_outlined,
      emptyTitle: 'لا توجد نتائج',
      emptyMessage: 'ستظهر هنا نتائج اختبارات التوجيه اللي عملها الطلاب.',
      itemBuilder: (r) {
        final student = r['student'] as Map<String, dynamic>?;
        final fields = (r['suggestedFields'] as List<dynamic>? ?? []).join('، ');
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(student?['name'] as String? ?? '—', style: AppTextStyles.cardTitle),
              if (fields.isNotEmpty) Text('مجالات مقترحة: $fields', style: AppTextStyles.caption),
            ],
          ),
        );
      },
    );
  }
}
