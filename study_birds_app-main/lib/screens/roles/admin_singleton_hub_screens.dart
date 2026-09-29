import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/admin_modules_repository.dart';
import 'admin_content_crud_screens.dart';

/// "content" section covers BOTH countries and study-fields
/// (employeeSections.json: resources: ["countries", "study-fields"]).
class AdminContentHubScreen extends StatelessWidget {
  const AdminContentHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الدول والمجالات الدراسية',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminCountriesScreen())),
            child: const Row(children: [Icon(Icons.public_rounded, color: AppColors.navy), SizedBox(width: 12), Expanded(child: Text('الدول', style: AppTextStyles.cardTitle)), Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textSecondary)]),
          ),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminStudyFieldsScreen())),
            child: const Row(children: [Icon(Icons.category_outlined, color: AppColors.navy), SizedBox(width: 12), Expanded(child: Text('المجالات الدراسية', style: AppTextStyles.cardTitle)), Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textSecondary)]),
          ),
        ],
      ),
    );
  }
}

/// "events" section covers upcoming-event (singleton), past-events (list),
/// and event-registrations (read-only).
class AdminEventsHubScreen extends StatelessWidget {
  const AdminEventsHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الفعاليات',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUpcomingEventScreen())),
            child: const Row(children: [Icon(Icons.event_available_outlined, color: AppColors.navy), SizedBox(width: 12), Expanded(child: Text('الفعالية القادمة', style: AppTextStyles.cardTitle)), Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textSecondary)]),
          ),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPastEventsScreen())),
            child: const Row(children: [Icon(Icons.event_note_outlined, color: AppColors.navy), SizedBox(width: 12), Expanded(child: Text('الفعاليات السابقة', style: AppTextStyles.cardTitle)), Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textSecondary)]),
          ),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminEventRegistrationsScreen())),
            child: const Row(children: [Icon(Icons.how_to_reg_outlined, color: AppColors.navy), SizedBox(width: 12), Expanded(child: Text('تسجيلات الحضور', style: AppTextStyles.cardTitle)), Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.textSecondary)]),
          ),
        ],
      ),
    );
  }
}

class AdminEventRegistrationsScreen extends StatefulWidget {
  const AdminEventRegistrationsScreen({super.key});
  @override
  State<AdminEventRegistrationsScreen> createState() => _AdminEventRegistrationsScreenState();
}

class _AdminEventRegistrationsScreenState extends State<AdminEventRegistrationsScreen> {
  List<dynamic> _regs = [];
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
      final data = await AdminModulesRepository.instance.getEventRegistrations();
      if (!mounted) return;
      setState(() { _regs = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'تعذر تحميل التسجيلات.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تسجيلات الحضور',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _regs.isEmpty
                    ? const EmptyState(icon: Icons.how_to_reg_outlined, title: 'لا توجد تسجيلات', message: 'ستظهر هنا تسجيلات الحضور للفعاليات.')
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _regs.length,
                      itemBuilder: (context, i) {
                        final reg = _regs[i] as Map<String, dynamic>;
                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reg['name'] as String? ?? reg['email'] as String? ?? '—', style: AppTextStyles.cardTitle),
                              Text((reg['upcomingEvent'] as Map<String, dynamic>?)?['title'] as String? ?? '', style: AppTextStyles.caption),
                            ],
                          ),
                        );
                      },
                    ),
      ),
    );
  }
}

/// Shared base for a singleton get/update form (site-settings, our-story,
/// upcoming-event) — fetch once, edit flat text fields, save with PUT.
class _SingletonEditScreen extends StatefulWidget {
  final String title;
  final Future<Map<String, dynamic>> Function() fetch;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) save;
  final List<MapEntry<String, String>> fields; // key -> label
  const _SingletonEditScreen({required this.title, required this.fetch, required this.save, required this.fields});

  @override
  State<_SingletonEditScreen> createState() => _SingletonEditScreenState();
}

class _SingletonEditScreenState extends State<_SingletonEditScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      _controllers[f.key] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.fetch();
      if (!mounted) return;
      for (final f in widget.fields) {
        _controllers[f.key]!.text = data[f.key]?.toString() ?? '';
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل البيانات.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = {for (final f in widget.fields) f.key: _controllers[f.key]!.text.trim()};
      await widget.save(payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'تعذر الحفظ.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      body: _loading
          ? const LoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.fields.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextField(
                          controller: _controllers[f.key],
                          maxLines: f.value.contains('نص') || f.value.contains('وصف') || f.value.contains('محتوى') ? 4 : 1,
                          decoration: InputDecoration(labelText: f.value),
                        ),
                      )),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                    const SizedBox(height: 10),
                  ],
                  PrimaryButton(label: _saving ? 'جاري الحفظ...' : 'حفظ التغييرات', onPressed: _saving ? null : _save),
                ],
              ),
            ),
    );
  }
}

class AdminSiteSettingsScreen extends StatelessWidget {
  const AdminSiteSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return _SingletonEditScreen(
      title: 'بيانات التواصل وإعدادات الموقع',
      fetch: repo.getSiteSettings,
      save: repo.updateSiteSettings,
      fields: const [
        MapEntry('contactEmail', 'البريد الإلكتروني للتواصل'),
        MapEntry('whatsappUrl', 'رابط واتساب'),
        MapEntry('facebookUrl', 'رابط فيسبوك'),
        MapEntry('instagramUrl', 'رابط إنستجرام'),
        MapEntry('tiktokUrl', 'رابط تيك توك'),
        MapEntry('supportHours', 'ساعات الدعم'),
        MapEntry('officeLocations', 'مواقع المكاتب'),
      ],
    );
  }
}

class AdminOurStoryScreen extends StatelessWidget {
  const AdminOurStoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return _SingletonEditScreen(
      title: 'قصتنا',
      fetch: repo.getOurStory,
      save: repo.updateOurStory,
      fields: const [
        MapEntry('heroTitle', 'العنوان الرئيسي'),
        MapEntry('heroBody', 'نص المقدمة'),
        MapEntry('storyTitle', 'عنوان القصة'),
        MapEntry('storyBody', 'نص القصة'),
        MapEntry('missionTitle', 'عنوان الرسالة'),
        MapEntry('missionBody', 'نص الرسالة'),
        MapEntry('visionTitle', 'عنوان الرؤية'),
        MapEntry('visionBody', 'نص الرؤية'),
      ],
    );
  }
}

class AdminUpcomingEventScreen extends StatelessWidget {
  const AdminUpcomingEventScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AdminModulesRepository.instance;
    return _SingletonEditScreen(
      title: 'الفعالية القادمة',
      fetch: repo.getUpcomingEvent,
      save: repo.updateUpcomingEvent,
      fields: const [
        MapEntry('title', 'العنوان'),
        MapEntry('subtitle', 'العنوان الفرعي'),
        MapEntry('eventType', 'نوع الفعالية'),
        MapEntry('ctaText', 'نص زر الدعوة'),
      ],
    );
  }
}
