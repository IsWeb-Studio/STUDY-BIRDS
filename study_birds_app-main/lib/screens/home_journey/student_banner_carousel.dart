import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

/// Local photographs keep the carousel available even without a connection.
class StudentBannerCarousel extends StatefulWidget {
  final ValueChanged<String> onExplore;
  const StudentBannerCarousel({super.key, required this.onExplore});

  @override
  State<StudentBannerCarousel> createState() => _StudentBannerCarouselState();
}

class _StudentBannerCarouselState extends State<StudentBannerCarousel>
    with WidgetsBindingObserver {
  final _pages = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  bool _dragging = false;
  bool _active = true;

  static const _slides = [
    (
      image: 'campus',
      tag: 'وجهتك القادمة',
      title: 'جامعة تناسب طموحك',
      subtitle: 'اكتشف الجامعات وابدأ خطوتك القادمة بثقة.',
      action: 'استكشف الجامعات',
      destination: 'universities',
    ),
    (
      image: 'library',
      tag: 'فرص تستحق الاكتشاف',
      title: 'طموحك يبدأ بفرصة',
      subtitle: 'تعرّف على المنح المتاحة واختر ما يناسبك.',
      action: 'اكتشف المنح',
      destination: 'scholarships',
    ),
    (
      image: 'students',
      tag: 'مستقبلك بين يديك',
      title: 'تخصص تحبه، مستقبل تصنعه',
      subtitle: 'استكشف البرامج الدراسية وابنِ مسارك الجامعي.',
      action: 'تصفّح البرامج',
      destination: 'programs',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !_active ||
          _paused ||
          _dragging ||
          !_pages.hasClients ||
          MediaQuery.disableAnimationsOf(context) ||
          !TickerMode.of(context) ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      _pages.animateToPage((_index + 1) % _slides.length,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic);
    });
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
    final height = 286.0 +
        (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(0, 80) * 4;
    return Container(
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
                  return Stack(fit: StackFit.expand, children: [
                    Image.asset('assets/images/dashboard/${slide.image}.jpg',
                        fit: BoxFit.cover, excludeFromSemantics: true),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x500C223A), Color(0xEE0C223A)]),
                    )),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(slide.tag,
                              style: const TextStyle(
                                  color: Color(0xFFFFCE91),
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
                          Text(slide.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12.5)),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () =>
                                widget.onExplore(slide.destination),
                            style: TextButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(slide.action,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
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
                                            ? AppColors.orange
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
}
