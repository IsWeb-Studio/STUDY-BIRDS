import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/catalog_repository.dart';

/// Shows the SAME public program catalog, but highlights the agent-only
/// price (Program.partnerTuition) instead of the public tuition — the
/// field is already returned by the public /programs endpoint, it just
/// wasn't surfaced for the agent role until now.
class AgentProgramPricingScreen extends StatefulWidget {
  const AgentProgramPricingScreen({super.key});

  @override
  State<AgentProgramPricingScreen> createState() => _AgentProgramPricingScreenState();
}

class _AgentProgramPricingScreenState extends State<AgentProgramPricingScreen> {
  List<dynamic> _programs = [];
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
      final data = await CatalogRepository.instance.getPrograms();
      if (!mounted) return;
      setState(() {
        _programs = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل البرامج.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'أسعار الوكلاء',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _programs.isEmpty
                    ? const EmptyState(icon: Icons.menu_book_outlined, title: 'لا توجد برامج', message: 'ستظهر هنا كل البرامج المتاحة بأسعار الوكلاء.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _programs.length,
                        itemBuilder: (context, i) {
                          final p = _programs[i] as Map<String, dynamic>;
                          final uni = p['university'] as Map<String, dynamic>?;
                          final publicPrice = p['tuition'];
                          final partnerPrice = p['partnerTuition'];
                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['title'] as String? ?? '—', style: AppTextStyles.cardTitle),
                                Text(uni?['name'] as String? ?? '', style: AppTextStyles.caption),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (publicPrice != null)
                                      Text('السعر العام: \$$publicPrice', style: AppTextStyles.caption.copyWith(decoration: TextDecoration.lineThrough)),
                                    if (partnerPrice != null)
                                      Text('سعرك: \$$partnerPrice', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 15))
                                    else
                                      const Text('لا يوجد سعر وكيل مسجّل', style: AppTextStyles.caption),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
