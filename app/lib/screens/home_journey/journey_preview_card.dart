import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

String journeyStatusLabel(String? status) => switch (status) {
  'submitted' || 'pending' => 'قيد الانتظار',
  'under-review' || 'under_review' || 'reviewing' => 'قيد المراجعة',
  'draft' || 'ready-to-apply' => 'بحاجة إلى استكمال',
  'additional-documents-required' || 'pending_docs' => 'مستندات مطلوبة',
  'conditional-admission' => 'قبول مشروط',
  'payment-required' => 'بانتظار الدفع',
  'payment-verification' => 'مراجعة الدفع',
  'accepted' || 'approved' || 'final-admission' => 'مقبول',
  'visa-preparation' => 'تجهيز التأشيرة',
  'completed' => 'مكتملة',
  'rejected' => 'مرفوض',
  _ => 'قيد المتابعة',
};

/// Design 10: orange corner, circular destination photo, navy stage and CTA.
class JourneyPreviewCard extends StatelessWidget {
  final String title, university, location, status, currentStage;
  final String? imageUrl, countryCode;
  final int number, total, completedStages, totalStages;
  final double progress;
  final VoidCallback onTap;
  const JourneyPreviewCard({super.key, required this.title,
    required this.university, required this.location, required this.status,
    required this.number, required this.total, required this.progress,
    required this.onTap, this.imageUrl, this.countryCode,
    this.currentStage = 'بانتظار تحديث الرحلة',
    this.completedStages = 0, this.totalStages = 0});

  static double heightFor(BuildContext context) =>
      440 + (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 28) * 20;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final segments = totalStages > 0 ? totalStages.clamp(1, 12) : 8;
    final extra = (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 28);
    return Material(
      color: Colors.white, elevation: 3,
      shadowColor: AppColors.navy.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(24), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Column(children: [
        SizedBox(height: 206 + extra * 12, child: Stack(children: [
          const Positioned(top: 0, left: 0, width: 144, height: 180,
              child: CustomPaint(painter: _OrangeJourneyCorner())),
          Positioned(top: 26, left: 14, child: Container(
            width: 88, height: 88, padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: ClipOval(child: imageUrl?.isNotEmpty == true
                ? AppNetworkImage(imageUrl!, fit: BoxFit.cover, errorWidget: _photoFallback())
                : _photoFallback()))),
          const Positioned(top: 133, left: 26,
              child: Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 24)),
          Positioned.fill(child: Padding(
            padding: const EdgeInsets.fromLTRB(112, 16, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('رحلة $number من $total', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11)),
              const SizedBox(height: 8),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(color: AppColors.navy, fontSize: 19, height: 1.4)),
              if (university.isNotEmpty) ...[
                const SizedBox(height: 6),
                _detail(Icons.school_outlined, university, AppColors.navy),
              ],
              if (location.isNotEmpty) ...[
                const SizedBox(height: 5),
                _detail(Icons.location_on_outlined, location, AppColors.textSecondary),
              ],
              const SizedBox(height: 9),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFFFF0E2), borderRadius: BorderRadius.circular(18)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.orange, size: 14),
                  const SizedBox(width: 4),
                  Flexible(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: const Color(0xFFAD4B00), fontSize: 11, fontWeight: FontWeight.w700))),
                ])),
            ]))),
        ])),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Icon(Icons.description_outlined, color: Colors.white70, size: 25),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('المرحلة الحالية', style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(currentStage, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ])),
              ])),
            const Spacer(),
            Row(children: [
              Expanded(child: Text('تقدّم الرحلة', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption)),
              const SizedBox(width: 8),
              Flexible(child: Text(totalStages > 0 ? '$completedStages من $totalStages مراحل' : '${(value * 100).round()}%',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: AppColors.navy))),
            ]),
            const SizedBox(height: 10),
            Row(children: List.generate(segments, (index) => Expanded(child: Container(
              height: 7, margin: EdgeInsetsDirectional.only(end: index == segments - 1 ? 0 : 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: const Color(0xFFE8EDF3)),
              child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(widthFactor: (value * segments - index).clamp(0.0, 1.0),
                  child: Container(color: AppColors.orange)),
              )),
            )))),
            const SizedBox(height: 16),
            FilledButton(onPressed: onTap, style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy, foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text('متابعة الرحلة', maxLines: 1, overflow: TextOverflow.ellipsis)),
                SizedBox(width: 10), Icon(Icons.arrow_forward_rounded, size: 20),
              ])),
          ]))),
      ])),
    );
  }

  Widget _photoFallback() => Container(color: const Color(0xFFE8F2FA),
      child: const Icon(Icons.travel_explore_rounded, color: AppColors.navy, size: 39));

  Widget _detail(IconData icon, String text, Color color) => Row(children: [
    Icon(icon, size: 15, color: color), const SizedBox(width: 5),
    Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(color: color, fontSize: 12))),
  ]);
}

class _OrangeJourneyCorner extends CustomPainter {
  const _OrangeJourneyCorner();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..lineTo(size.width, 0)
      ..cubicTo(size.width * .7, size.height * .63, size.width * .4,
          size.height * .8, 0, size.height)..close();
    canvas.drawPath(path, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFFF8F13), AppColors.orange])
        .createShader(Offset.zero & size));
  }
  @override
  bool shouldRepaint(covariant _OrangeJourneyCorner oldDelegate) => false;
}
