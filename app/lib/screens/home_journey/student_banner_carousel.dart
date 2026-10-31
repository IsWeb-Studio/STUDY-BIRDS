import '../../core/widgets/cached_resource.dart';
import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';

class _BannerSlide {
  final String tag;
  final String title;
  final String subtitle;
  final String action;
  final String destination;
  final String? imageUrl;
  const _BannerSlide({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.destination,
    this.imageUrl,
  });
}

class StudentBannerCarousel extends StatefulWidget {
  final ValueChanged<String> onExplore;
  final String placement;
  final int refreshVersion;
  const StudentBannerCarousel(
      {super.key,
      required this.onExplore,
      this.placement = 'home',
      this.refreshVersion = 0});

  @override
  State<StudentBannerCarousel> createState() => _StudentBannerCarouselState();
}

class _StudentBannerCarouselState extends State<StudentBannerCarousel>
    with WidgetsBindingObserver, CachedResource<StudentBannerCarousel> {
  String get _path => widget.placement == 'home'
      ? '/content/banners'
      : '/content/banners?placement=community';
  @override
  Iterable<String> get cachedPaths => [_path];
  @override
  Future<void> reloadCachedResource() => _loadBanners();
  final _pages = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  bool _dragging = false;
  bool _active = true;

  static const _fallback = [
    _BannerSlide(
      tag: 'وجهتك القادمة',
      title: 'جامعة تناسب طموحك',
      subtitle: 'اكتشف الجامعات وابدأ خطوتك القادمة بثقة.',
      action: 'استكشف الجامعات',
      destination: 'universities',
    ),
    _BannerSlide(
      tag: 'فرص تستحق الاكتشاف',
      title: 'طموحك يبدأ بفرصة',
      subtitle: 'تعرّف على المنح المتاحة واختر ما يناسبك.',
      action: 'اكتشف المنح',
      destination: 'scholarships',
    ),
    _BannerSlide(
      tag: 'مستقبلك بين يديك',
      title: 'تخصص تحبه، مستقبل تصنعه',
      subtitle: 'استكشف البرامج الدراسية وابنِ مسارك الجامعي.',
      action: 'تصفّح البرامج',
      destination: 'programs',
    ),
  ];

  // fallback local image per index (cycles if fewer remote banners)
  static const _localImages = ['campus', 'library', 'students'];

  late List<_BannerSlide> _slides = widget.placement == 'home' ? _fallback : [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBanners();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          _slides.length < 2 ||
          !_active ||
          _paused ||
          _dragging ||
          !_pages.hasClients ||
          MediaQuery.disableAnimationsOf(context) ||
          !TickerMode.valuesOf(context).enabled ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      _pages.animateToPage((_index + 1) % _slides.length,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic);
    });
  }

  Future<void> _loadBanners({bool cached = true}) async {
    try {
      final raw = await ApiClient.instance.get(_path, cached: cached);
      final list = Json.list(raw);

      final slides = list
          .where((b) {
            final m = Json.map(b);
            return m['active'] != false &&
                (m['placement'] == widget.placement ||
                    m['placement'] == 'both' ||
                    (widget.placement == 'home' && m['placement'] == null));
          })
          .map((b) {
            final m = Json.map(b);
            return _BannerSlide(
              tag: (m['tag'] as String?) ?? '',
              title: (m['title'] as String?) ?? '',
              subtitle: (m['subtitle'] as String?) ?? '',
              action: (m['actionLabel'] as String?) ?? 'اكتشف المزيد',
              destination: (m['destination'] as String?) ?? 'universities',
              imageUrl: (m['imageUrl'] as String?) ?? '',
            );
          })
          .where((s) => s.title.isNotEmpty)
          .toList();
      if (mounted) {
        if (_pages.hasClients) _pages.jumpToPage(0);
        setState(() {
          _slides =
              slides.isEmpty && widget.placement == 'home' ? _fallback : slides;
          _index = 0;
        });
      }
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/home_journey/student_banner_carousel.dart:113');
      // keep fallback
    }
  }

  @override
  void didUpdateWidget(covariant StudentBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _loadBanners(cached: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) return const SizedBox.shrink();
    final height = 286.0 +
        (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 80) * 4;
    return Container(
      margin: widget.placement == 'community'
          ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
          : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withValues(alpha: .14),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            NotificationListener<ScrollNotification>(
              onNotification: (event) {
                if (event is ScrollStartNotification) _dragging = true;
                if (event is ScrollEndNotification) _dragging = false;
                return false;
              },
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final localImg = _localImages[index % _localImages.length];
                  return Stack(fit: StackFit.expand, children: [
                    _buildBg(slide, localImg),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x50041E4A), Color(0xEE041E4A)]),
                    )),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (slide.tag.isNotEmpty ||
                              widget.placement == 'community')
                            Text(
                                slide.tag.isNotEmpty
                                    ? slide.tag
                                    : (Localizations.localeOf(context)
                                                .languageCode ==
                                            'ar'
                                        ? 'إعلان'
                                        : 'Advertisement'),
                                style: const TextStyle(
                                    color: AppColors.greenSoft,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(slide.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          if (slide.subtitle.isNotEmpty)
                            Text(slide.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12.5)),
                          const SizedBox(height: 10),
                          if (slide.action.isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  widget.onExplore(slide.destination),
                              style: TextButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  foregroundColor: AppColors.navy,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(slide.action,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 16),
                                  ]),
                            ),
                        ],
                      ),
                    ),
                  ]);
                },
              ),
            ),
            Positioned(
              bottom: 5,
              left: 12,
              right: 12,
              child: Row(children: [
                ...List.generate(
                    _slides.length,
                    (index) => Semantics(
                          label: 'الصورة ${index + 1} من ${_slides.length}',
                          selected: _index == index,
                          child: InkWell(
                            onTap: () => _pages.animateToPage(index,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 400),
                                curve: Curves.easeOut),
                            child: SizedBox(
                                width: 32,
                                height: 40,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: _index == index ? 24 : 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: _index == index
                                            ? AppColors.green
                                            : Colors.white54),
                                  ),
                                )),
                          ),
                        )),
                const Spacer(),
                IconButton(
                  tooltip:
                      _paused ? 'تشغيل الصور تلقائيًا' : 'إيقاف حركة الصور',
                  onPressed: () => setState(() => _paused = !_paused),
                  icon: Icon(
                      _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: Colors.white,
                      size: 20),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBg(_BannerSlide slide, String localImg) {
    final url = slide.imageUrl ?? '';
    if (url.isNotEmpty) {
      return AppNetworkImage(
        url,
        fit: BoxFit.cover,
        errorWidget: Image.asset(
          'assets/images/dashboard/$localImg.jpg',
          cacheWidth: 900,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      );
    }
    return Image.asset(
      'assets/images/dashboard/$localImg.jpg',
      cacheWidth: 900,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
    );
  }
}
