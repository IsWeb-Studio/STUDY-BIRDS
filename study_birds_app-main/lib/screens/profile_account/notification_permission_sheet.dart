import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';

class NotificationPermissionSheet extends StatelessWidget {
  const NotificationPermissionSheet({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(context).padding.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 24),
            Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                    color: AppColors.orangeSoft, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active_rounded,
                    color: AppColors.orange, size: 42)),
            const SizedBox(height: 20),
            const Text('خطوتك القادمة… تصلك بوقتها',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const SizedBox(height: 10),
            const Text(
                'تابع أخبار قبولك ومواعيدك المهمة حتى وأنت خارج التطبيق.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: AppColors.textSecondary, height: 1.6)),
            const SizedBox(height: 20),
            const _BulletRow(
                icon: Icons.school_rounded, text: 'تحديثات القبول والمستندات'),
            const _BulletRow(
                icon: Icons.event_available_rounded,
                text: 'تذكيرات الاستشارات والمدفوعات'),
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.orangeSoft,
                    borderRadius: BorderRadius.circular(16)),
                child: const _BulletRow(
                    icon: Icons.volume_up_rounded,
                    text: 'تنبيه بصوت حسب إعدادات الصوت في جهازك')),
            const SizedBox(height: 24),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.notifications_rounded),
                  label: const Text('تفعيل الإشعارات',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                )),
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ليس الآن',
                    style: TextStyle(color: AppColors.textSecondary))),
            const Text('يمكنك تغيير اختيارك من إعدادات الإشعارات في أي وقت.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      );
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BulletRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: AppColors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5))),
        ]),
      );
}
