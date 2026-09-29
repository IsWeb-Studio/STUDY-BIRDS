import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/app_theme.dart';
import '../../core/animations.dart';

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final String imageUrl;
  const OnboardingSlide(
      {required this.icon, required this.title, required this.description, required this.imageUrl});
}

class OnboardingIntroScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const OnboardingIntroScreen({super.key, this.onDone});

  @override
  State<OnboardingIntroScreen> createState() => _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends State<OnboardingIntroScreen> with SingleTickerProviderStateMixin {
  late final PageController _controller;
  int _index = 0;
  double _page = 0;

  late final AnimationController _entrance;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  // Themed photos per slide — in production swap for real illustrations/brand photography.
  static const List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: Icons.travel_explore_rounded,
      title: 'رحلتك الدراسية بين يديك',
      description: 'من اختيار الجامعة لحد وصولك لمقاعد الدراسة، كلها في مكان واحد.',
      imageUrl: 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=800&q=80',
    ),
    OnboardingSlide(
      icon: Icons.fact_check_rounded,
      title: 'تابع كل خطوة أول بأول',
      description: 'مستنداتك، دفعاتك، وحالة طلبك — واضحة وبدون تعقيد.',
      imageUrl: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800&q=80',
    ),
    OnboardingSlide(
      icon: Icons.support_agent_rounded,
      title: 'فريق ودعم دايمًا معك',
      description: 'مستشارك التعليمي و Bird AI جاهزين يجاوبوك في أي وقت.',
      imageUrl: 'https://images.unsplash.com/photo-1600880292203-757bb62b4baf?w=800&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController()..addListener(() => setState(() => _page = _controller.page ?? 0));
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entranceFade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOut));
    _entrance.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('تخطي',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    _entrance.forward(from: 0);
                  },
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    final delta = (i - _page).clamp(-1.0, 1.0).abs();
                    final signedDelta = (i - _page).clamp(-1.0, 1.0); // signed, for parallax direction
                    final scale = 1 - (delta * 0.12);
                    final opacity = 1 - delta;
                    // Parallax: the illustration drifts noticeably more than the
                    // text as the page is dragged, so they feel like separate
                    // depth layers instead of one flat block moving together.
                    final imageParallax = signedDelta * 55;
                    final textParallax = signedDelta * 18;

                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: FadeTransition(
                          opacity: _entranceFade,
                          child: SlideTransition(
                            position: _entranceSlide,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.translate(
                                    offset: Offset(imageParallax, 0),
                                    child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 220,
                                        height: 220,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.orange.withValues(alpha: 0.15), width: 6),
                                          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
                                        ),
                                        child: ClipOval(
                                          child: Image.network(
                                            s.imageUrl,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, progress) {
                                              if (progress == null) return child;
                                              return Container(
                                                color: AppColors.navy.withValues(alpha: 0.06),
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange)),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: AppColors.navy.withValues(alpha: 0.06),
                                              child: Icon(s.icon, size: 60, color: AppColors.navy),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: -6,
                                        left: -6,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.orange,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 3),
                                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                                          ),
                                          child: Icon(s.icon, size: 22, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  Transform.translate(
                                    offset: Offset(textParallax, 0),
                                    child: Column(
                                      children: [
                                        Text(s.title,
                                            style: AppTextStyles.screenTitle,
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 10),
                                        Text(s.description,
                                            style: AppTextStyles.body,
                                            textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.orange : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: BreathingPulse(
                  maxScale: 1.03,
                  child: PrimaryButton(
                    label: _index == _slides.length - 1 ? 'ابدأ الآن' : 'التالي',
                    onPressed: () {
                      if (_index == _slides.length - 1) {
                        widget.onDone?.call();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceHighlight {
  final IconData icon;
  final String title;
  const ServiceHighlight({required this.icon, required this.title});
}

class OnboardingServicesScreen extends StatelessWidget {
  final VoidCallback? onContinue;
  const OnboardingServicesScreen({super.key, this.onContinue});

  static const List<ServiceHighlight> _services = [
    ServiceHighlight(icon: Icons.account_balance_rounded, title: 'اختيار الجامعة والبرنامج'),
    ServiceHighlight(icon: Icons.description_rounded, title: 'إدارة المستندات والطلب'),
    ServiceHighlight(icon: Icons.flight_takeoff_rounded, title: 'التأشيرة والسفر'),
    ServiceHighlight(icon: Icons.home_work_rounded, title: 'السكن والاستقرار'),
    ServiceHighlight(icon: Icons.support_agent_rounded, title: 'دعم مستمر حتى التخرج'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'خدماتنا',
      showBackButton: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('كل شيء تحتاجه في رحلتك', style: AppTextStyles.screenTitle),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final s = _services[i];
                  return AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(s.icon, color: AppColors.orange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.title, style: AppTextStyles.cardTitle)),
                      ],
                    ),
                  );
                },
              ),
            ),
            PrimaryButton(label: 'متابعة', onPressed: onContinue),
          ],
        ),
      ),
    );
  }
}

class AccountTypeSelectionScreen extends StatefulWidget {
  final void Function(String type)? onSelected;
  const AccountTypeSelectionScreen({super.key, this.onSelected});

  @override
  State<AccountTypeSelectionScreen> createState() =>
      _AccountTypeSelectionScreenState();
}

class _AccountTypeSelectionScreenState
    extends State<AccountTypeSelectionScreen> {
  String? _selected;

  static const List<Map<String, dynamic>> _types = [
    {'key': 'student', 'label': 'طالب', 'icon': Icons.school_rounded},
    {'key': 'parent', 'label': 'ولي أمر', 'icon': Icons.family_restroom_rounded},
    {'key': 'agent', 'label': 'وكيل', 'icon': Icons.handshake_rounded},
    {'key': 'university', 'label': 'جامعة', 'icon': Icons.account_balance_rounded},
    {'key': 'employee', 'label': 'موظف Study Birds', 'icon': Icons.badge_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'نوع الحساب',
      showBackButton: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('من أنت؟', style: AppTextStyles.screenTitle),
            const SizedBox(height: 6),
            const Text('اختر نوع الحساب المناسب للمتابعة', style: AppTextStyles.caption),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: _types.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, i) {
                  final t = _types[i];
                  final selected = _selected == t['key'];
                  return BounceTap(
                    onTap: () => setState(() => _selected = t['key'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.orange.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: selected ? AppColors.orange : AppColors.border,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            child: Icon(t['icon'] as IconData,
                                size: 34,
                                color: selected ? AppColors.orange : AppColors.navy),
                          ),
                          const SizedBox(height: 10),
                          Text(t['label'] as String, style: AppTextStyles.cardTitle),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            PrimaryButton(
              label: 'متابعة',
              onPressed: _selected == null
                  ? null
                  : () => widget.onSelected?.call(_selected!),
            ),
          ],
        ),
      ),
    );
  }
}
