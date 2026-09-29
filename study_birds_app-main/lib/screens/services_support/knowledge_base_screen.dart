import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../core/student_repository.dart';
import '../../core/auth_session.dart';
import '../../core/catalog_repository.dart';

IconData _resourceIcon(String? type) {
  switch (type) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'video':
      return Icons.play_circle_outline_rounded;
    case 'link':
      return Icons.link_rounded;
    case 'article':
    default:
      return Icons.article_outlined;
  }
}

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
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
      final data = await StudentRepository.instance.getKnowledgeBase();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل مركز المعرفة.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مركز المعرفة',
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
                : _items.isEmpty
                    ? const EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'لا يوجد محتوى بعد',
                        message: 'سيتم إضافة مقالات ومصادر مفيدة قريبًا.')
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i] as Map<String, dynamic>;
                        return AppCard(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => KnowledgeBaseArticleScreen(item: item))),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_resourceIcon(item['resourceType'] as String?), color: AppColors.navy, size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['title'] as String? ?? '—', style: AppTextStyles.cardTitle),
                                    if ((item['summary'] as String?)?.isNotEmpty == true)
                                      Text(item['summary'] as String, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
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

class KnowledgeBaseArticleScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const KnowledgeBaseArticleScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: item['title'] as String? ?? 'مقال',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(item['body'] as String? ?? '', style: AppTextStyles.body),
      ),
    );
  }
}

// ─── محطة المعارض: مقالات ومحتوى تعليمي ──────────────────────────────────────

class ExhibitionsScreen extends StatefulWidget {
  const ExhibitionsScreen({super.key});
  @override
  State<ExhibitionsScreen> createState() => _ExhibitionsScreenState();
}

class _ExhibitionsScreenState extends State<ExhibitionsScreen> {
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
      final data = await CatalogRepository.instance.getExhibitions();
      if (!mounted) return;
      setState(() {
        _items = data
            .whereType<Map>()
            .where((e) => e['published'] != false)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'تعذر تحميل المقالات. أعد المحاولة.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'محطة المعارض',
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
                  : _items.isEmpty
                      ? const EmptyState(
                          icon: Icons.article_outlined,
                          title: 'لا توجد مقالات بعد',
                          message: 'ستظهر المقالات والمحتوى التعليمي هنا.')
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final item = Map<String, dynamic>.from(_items[i] as Map);
                            return _ExhibitionCard(
                              item: item,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ExhibitionArticleScreen(item: item))),
                            );
                          },
                        ),
        ),
      );
}

class _ExhibitionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _ExhibitionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item['image'] as String?;
    final featured = item['featured'] == true;
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 10),
        Row(children: [
          if (featured) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('مميز',
                  style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: Text(item['title'] as String? ?? '—',
                  style: AppTextStyles.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)),
        ]),
        if ((item['summary'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(item['summary'] as String,
              style: AppTextStyles.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.arrow_back_ios_new_rounded,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text('اقرأ المزيد',
              style: AppTextStyles.caption.copyWith(color: AppColors.navy,
                  fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class ExhibitionArticleScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const ExhibitionArticleScreen({super.key, required this.item});
  @override
  State<ExhibitionArticleScreen> createState() => _ExhibitionArticleScreenState();
}

class _ExhibitionArticleScreenState extends State<ExhibitionArticleScreen> {
  bool _favorited = false;
  bool _toggling = false;

  bool get _isLoggedIn => AuthSession.instance.token != null;

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط.')));
    }
  }

  Future<void> _toggleFavorite() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      final slug = widget.item['slug']?.toString() ?? '';
      final title = widget.item['title']?.toString() ?? '';
      final res = await StudentRepository.instance.toggleFavorite(
          itemType: 'article', articleSlug: slug, articleTitle: title);
      if (mounted) setState(() => _favorited = res['removed'] != true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث المفضلة.')));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.item['image'] as String?;
    final youtubeUrl = widget.item['youtubeUrl'] as String?;
    final body = (widget.item['body'] as String? ?? '').trim();

    return AppScaffold(
      title: widget.item['title'] as String? ?? 'مقال',
      actions: _isLoggedIn
          ? [
              IconButton(
                tooltip: _favorited ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                icon: _toggling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        _favorited
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _favorited ? AppColors.danger : null),
                onPressed: _toggleFavorite,
              ),
            ]
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 16),
          Text(widget.item['title'] as String? ?? '',
              style: AppTextStyles.screenTitle
                  .copyWith(fontSize: 20, height: 1.4)),
          if ((widget.item['summary'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(widget.item['summary'] as String,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          if (body.isNotEmpty)
            Text(body, style: AppTextStyles.body.copyWith(height: 1.7)),
          if (youtubeUrl != null && youtubeUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _openVideo(youtubeUrl),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
              label: const Text('شاهد الفيديو على يوتيوب'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AppColors.navy),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
