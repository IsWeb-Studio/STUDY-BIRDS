import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/catalog_repository.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  List<dynamic> _faqs = [];
  bool _loading = true;
  String? _error;
  int? _expandedIndex;

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
      final data = await CatalogRepository.instance.getFaqs();
      if (!mounted) return;
      setState(() {
        _faqs = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الأسئلة الشائعة.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الأسئلة الشائعة',
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _faqs.isEmpty
                    ? const EmptyState(
                        icon: Icons.help_outline_rounded,
                        title: 'لا توجد أسئلة بعد',
                        message: 'سيتم إضافتها من لوحة التحكم قريبًا.')
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _faqs.length,
                      itemBuilder: (context, i) {
                        final faq = _faqs[i] as Map<String, dynamic>;
                        final expanded = _expandedIndex == i;
                        return AppCard(
                          onTap: () => setState(() => _expandedIndex = expanded ? null : i),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(faq['question'] as String? ?? '', style: AppTextStyles.cardTitle)),
                                  Icon(expanded ? Icons.remove_rounded : Icons.add_rounded, color: AppColors.orange),
                                ],
                              ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 220),
                                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                firstChild: const SizedBox(width: double.infinity, height: 0),
                                secondChild: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(faq['answer'] as String? ?? '', style: AppTextStyles.body),
                                ),
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
