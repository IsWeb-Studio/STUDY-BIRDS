import '../../core/widgets/cached_resource.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';

/// Published website content shared through the existing public API.
class PublicStudentContentScreen extends StatefulWidget {
  final bool offices;
  const PublicStudentContentScreen({super.key, this.offices = false});
  @override
  State<PublicStudentContentScreen> createState() => _PublicContentState();
}

class _PublicContentState extends State<PublicStudentContentScreen> with CachedResource<PublicStudentContentScreen> {
  @override
  Iterable<String> get cachedPaths => const ["/content/site-settings","/content/testimonials"];
  @override
  Future<void> reloadCachedResource() => _refreshContent();
  Future<void> _refreshContent() async { if (mounted) setState(() => _content = _load()); }
  late Future<dynamic> _content;
  Future<dynamic> _load() async {
    final data = await ApiClient.instance.get(
        widget.offices ? '/content/site-settings' : '/content/testimonials');
    if (widget.offices
        ? data is! Map
        : !(data is List ||
            data is Map && (data['items'] is List || data['data'] is List))) {
      throw const ApiException(502, 'Unable to load published content');
    }
    return data;
  }

  @override
  void initState() {
    super.initState();
    _content = _load();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final title = widget.offices
        ? (ar ? 'مكاتبنا' : 'Our offices')
        : (ar ? 'قصص النجاح' : 'Success stories');
    return AppScaffold(
        cachedPaths: [widget.offices ? '/content/site-settings' : '/content/testimonials'],
        title: title,
        body: FutureBuilder<dynamic>(
          future: _content,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
              return const LoadingState();
            }
            if (snapshot.hasError) {
              return ErrorState(
                  message: ar
                      ? 'تعذر تحميل المحتوى. حاول مجددًا.'
                      : 'Unable to load content. Try again.',
                  onRetry: () => setState(() => _content = _load()));
            }
            final data = snapshot.data;
            if (widget.offices) {
              final offices =
                  data is Map ? '${data['officeLocations'] ?? ''}'.trim() : '';
              if (offices.isEmpty) {
                return EmptyState(
                    icon: Icons.location_on_outlined,
                    message: ar
                        ? 'تظهر هنا عناوين المكاتب عند نشرها.'
                        : 'Office addresses will appear here when published.',
                    title: ar
                        ? 'لا توجد عناوين مكاتب منشورة حاليًا'
                        : 'No office locations are published yet');
              }
              return ListView(padding: const EdgeInsets.all(20), children: [
                const Icon(Icons.location_on_outlined,
                    size: 36, color: AppColors.greenInk),
                const SizedBox(height: 20),
                SelectableText(offices,
                    style: AppTextStyles.body.copyWith(height: 1.8)),
                if (data is Map &&
                    '${data['supportHours'] ?? ''}'.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(ar ? 'ساعات العمل' : 'Support hours',
                      style: AppTextStyles.cardTitle),
                  Text('${data['supportHours']}', style: AppTextStyles.body),
                ],
              ]);
            }
            final raw = data is List
                ? data
                : data is Map
                    ? data['items'] ?? data['data']
                    : null;
            final stories =
                raw is List ? raw.whereType<Map>().toList() : <Map>[];
            if (stories.isEmpty) {
              return EmptyState(
                  icon: Icons.emoji_events_outlined,
                  message: ar
                      ? 'تظهر هنا تجارب الطلاب عند نشرها.'
                      : 'Student experiences will appear here when published.',
                  title: ar
                      ? 'لا توجد قصص منشورة حاليًا'
                      : 'No stories are published yet');
            }
            return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: stories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final story = stories[index];
                  return AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Icon(Icons.format_quote_rounded,
                            color: AppColors.greenInk),
                        Text('${story['quote'] ?? ''}',
                            style: AppTextStyles.body.copyWith(height: 1.8)),
                        const SizedBox(height: 14),
                        Text('${story['studentName'] ?? ''}',
                            style: AppTextStyles.cardTitle),
                        if ('${story['destination'] ?? ''}'.isNotEmpty)
                          Text('${story['destination']}',
                              style: AppTextStyles.caption),
                      ]));
                });
          },
        ));
  }
}
