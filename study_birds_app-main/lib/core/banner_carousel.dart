import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// A single banner slide. In production this comes from the admin panel/CMS
/// (spec points 75/76: dynamic content, never hardcoded) — imageUrl and
/// linkUrl are both editable there, not in app code.
class BannerItem {
  final String imageUrl;
  final String linkUrl;
  const BannerItem({required this.imageUrl, required this.linkUrl});
}

/// Auto-rotating banner carousel. Place it directly under the app bar/header
/// on the Home screen. Tapping a banner opens its linkUrl via [onBannerTap].
class BannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;
  final Duration interval;
  final double height;
  final void Function(String url) onBannerTap;

  const BannerCarousel({
    super.key,
    required this.banners,
    required this.onBannerTap,
    this.interval = const Duration(seconds: 3),
    this.height = 140,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(widget.interval, (_) => _advance());
    }
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) return;
    final next = (_index + 1) % widget.banners.length;
    _controller.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final banner = widget.banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: GestureDetector(
                  onTap: () => widget.onBannerTap(banner.linkUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Image.network(
                      banner.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const LoadingState();
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.navy.withValues(alpha: 0.06),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary, size: 32),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? AppColors.orange : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
