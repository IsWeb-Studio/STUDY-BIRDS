import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

/// Home summary for older overview responses without per-application records.
class HomeJourneySummaryCard extends StatelessWidget {
  final String path, step, description, stepLabel;
  final double progress;
  final int applications, documents;
  final VoidCallback onTap;
  const HomeJourneySummaryCard({super.key, required this.path,
    required this.step, required this.description, required this.stepLabel,
    required this.progress, required this.applications, required this.documents,
    required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, elevation: 3,
    shadowColor: AppColors.navy.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(24), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [AppColors.navy, Color(0xFF194E75)])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.orange, size: 22)),
              const SizedBox(width: 10),
              const Expanded(child: Text('رحلتك الدراسية', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17))),
              const SizedBox(width: 8),
              Text('${(progress.clamp(0.0, 1.0) * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            ]),
            const SizedBox(height: 16),
            Text(path, style: AppTextStyles.body.copyWith(color: Colors.white, height: 1.7)),
            const SizedBox(height: 15),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0), minHeight: 6,
              color: AppColors.orange, backgroundColor: Colors.white24)),
          ])),
        Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF1F7FC), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.route_outlined, color: AppColors.orange, size: 18),
                  const SizedBox(width: 7),
                  Expanded(child: Text(stepLabel, style: AppTextStyles.caption)),
                ]),
                if (step.isNotEmpty) ...[
                  const SizedBox(height: 8), Text(step, style: AppTextStyles.cardTitle),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6), Text(description, style: AppTextStyles.caption.copyWith(height: 1.7)),
                ],
              ])),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _stat(Icons.folder_outlined, applications, 'الطلبات النشطة')),
              const SizedBox(width: 12),
              Expanded(child: _stat(Icons.verified_outlined, documents, 'مستندات مقبولة')),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onTap,
              style: FilledButton.styleFrom(backgroundColor: AppColors.navy,
                foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.arrow_forward_rounded, size: 19),
              label: const Text('متابعة الرحلة')),
          ])),
      ])),
  );

  Widget _stat(IconData icon, int value, String label) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: AppColors.navy, size: 18), const SizedBox(width: 8),
        Expanded(child: Text('$value', style: AppTextStyles.cardTitle))]),
      const SizedBox(height: 6), Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
    ]));
}
