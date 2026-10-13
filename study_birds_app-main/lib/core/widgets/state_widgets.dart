import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/connectivity_service.dart';
import '../utils/app_error.dart';

/// Skeleton loading screen — replaces circular spinners with shimmer cards.
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    Widget item(int i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: i == 0 && message != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SkeletonBox(height: 14, width: 140),
                  ),
                  const SkeletonCard(),
                ])
              : const SkeletonCard(),
        );
    return LayoutBuilder(builder: (context, constraints) {
      // Used both as a full-screen body and inside other scrollables (parent
      // dashboard). A ListView inside an unbounded parent throws "Vertical
      // viewport was given unbounded height" - so fall back to a plain Column.
      if (!constraints.hasBoundedHeight) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [for (var i = 0; i < 3; i++) item(i)]),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, i) => item(i),
      );
    });
  }
}

/// Skeleton shimmer placeholder — for loading states that need layout fidelity.
/// Animates opacity 0.3→0.7→0.3 to communicate "loading in progress".
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const SkeletonBox(
      {super.key,
      this.width = double.infinity,
      this.height = 16,
      this.borderRadius = 8});
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.65).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        ),
      );
}

/// A skeleton card that mimics an AppCard with two text lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(height: 14, width: 160),
            SizedBox(height: 10),
            SkeletonBox(height: 12),
            SizedBox(height: 6),
            SkeletonBox(height: 12, width: 120),
          ],
        ),
      );
}

/// Standard error state — never a blank/broken screen, per spec point 69.
class ErrorState extends StatefulWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState(
      {super.key,
      this.message = 'حدث خطأ غير متوقع، حاول مرة أخرى.',
      this.onRetry});

  @override
  State<ErrorState> createState() => _ErrorStateState();
}

class _ErrorStateState extends State<ErrorState> {
  StreamSubscription<void>? _reconnectSub;
  bool _checking = false;
  bool _autoRetried = false;

  bool get _offline {
    final text = AppError.safeText(widget.message);
    // Only a genuine connectivity failure gets the offline treatment; a message
    // that merely mentions the connection (e.g. a 503) must not claim "no internet".
    return text == AppError.connection;
  }

  @override
  void initState() {
    super.initState();
    // Connectivity errors recover by themselves: when the verified connection
    // returns, retry exactly once (no loops, no duplicate loads).
    _reconnectSub = ConnectivityService.instance.onReconnected.listen((_) {
      if (!mounted || _autoRetried || widget.onRetry == null || !_offline) return;
      _autoRetried = true;
      widget.onRetry!();
    });
  }

  @override
  void dispose() {
    _reconnectSub?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_checking) return; // ignore double taps
    setState(() => _checking = true);
    try {
      // Bounded so "Try again" can never hang on a dead network.
      if (_offline) {
        await ConnectivityService.instance
            .checkNow()
            .timeout(const Duration(seconds: 4), onTimeout: () => false);
      }
      if (mounted) widget.onRetry?.call();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = _offline;
    final text = offline
        ? 'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.'
        : AppError.safeText(widget.message);
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
        child: Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .04), blurRadius: 24, offset: const Offset(0, 8))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .85, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Opacity(opacity: scale.clamp(0, 1), child: Transform.scale(scale: scale, child: child)),
              child: Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(color: AppColors.orangeSoft, shape: BoxShape.circle),
                child: Icon(offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded, size: 34, color: AppColors.orange)),
            ),
            const SizedBox(height: 20),
            Text(offline ? 'لا يوجد اتصال بالإنترنت' : 'نحتاج لحظة لإكمال طلبك', style: AppTextStyles.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(text, style: AppTextStyles.caption.copyWith(fontSize: 14, height: 1.8), textAlign: TextAlign.center),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 22),
              PrimaryButton(label: 'إعادة المحاولة', onPressed: _checking ? null : _retry, expand: false, icon: Icons.refresh_rounded),
            ],
          ]),
        ),
      ),
    ));
  }
}

/// Persistent banner shown when the device is offline. Per spec point 67:
/// cached data can still show, but sensitive actions should be blocked
/// elsewhere in the screen while this banner is visible.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.neutral,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text('لا يوجد اتصال بالإنترنت — يتم عرض آخر بيانات محفوظة',
              style: TextStyle(color: Colors.white, fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// Standard confirmation dialog for sensitive actions (submit application,
/// delete, cancel appointment, confirm payment, replace document — spec point 70).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool danger = false,
  bool scrollable = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        scrollable: scrollable,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(title, style: AppTextStyles.cardTitle),
        content: Text(message, style: AppTextStyles.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: danger ? AppColors.danger : AppColors.orange,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
            if (ctaLabel != null) ...[
              const SizedBox(height: 16),
              PrimaryButton(label: ctaLabel!, onPressed: onCta, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

