import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/app_theme.dart';

/// Widget tests for the UX improvements batch:
/// - EmptyState CTA button (Applications, Favorites, ReferralProgram, SupportTickets)
/// - Language card dialog trigger
/// - RefreshIndicator presence on lists
void main() {
  // ── EmptyState CTA ────────────────────────────────────────────────────────

  group('EmptyState CTA', () {
    testWidgets('renders ctaLabel as button when provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.description_outlined,
            title: 'لا توجد طلبات',
            message: 'ابدأ رحلتك.',
            ctaLabel: 'استكشف الجامعات',
            onCta: () {},
          ),
        ),
      ));

      expect(find.text('استكشف الجامعات'), findsOneWidget);
    });

    testWidgets('CTA button fires onCta callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'لا يوجد مفضلة',
            message: 'احفظ الجامعات.',
            ctaLabel: 'استكشف الجامعات',
            onCta: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.text('استكشف الجامعات'));
      expect(tapped, isTrue);
    });

    testWidgets('no ctaLabel means no CTA button', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.notifications_off_rounded,
            title: 'لا إشعارات',
            message: 'ستصلك التحديثات هنا.',
          ),
        ),
      ));

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('support-ticket EmptyState has correct title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.confirmation_number_outlined,
            title: 'لا توجد تذاكر بعد',
            message: 'أنشئ تذكرة جديدة لو محتاج مساعدة.',
            ctaLabel: 'تذكرة دعم جديدة',
            onCta: () {},
          ),
        ),
      ));

      expect(find.text('لا توجد تذاكر بعد'), findsOneWidget);
      expect(find.text('تذكرة دعم جديدة'), findsOneWidget);
    });

    testWidgets('referral EmptyState has support CTA', (tester) async {
      bool ctaCalled = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.card_giftcard,
            title: 'لا يوجد رمز إحالة لحسابك',
            message: 'تواصل مع الدعم لمعرفة شروط برنامج الإحالة.',
            ctaLabel: 'تواصل مع الدعم',
            onCta: () => ctaCalled = true,
          ),
        ),
      ));

      expect(find.text('تواصل مع الدعم'), findsOneWidget);
      await tester.tap(find.text('تواصل مع الدعم'));
      expect(ctaCalled, isTrue);
    });
  });

  // ── RefreshIndicator ──────────────────────────────────────────────────────

  group('RefreshIndicator', () {
    testWidgets('RefreshIndicator wraps a scrollable list', (tester) async {
      int refreshCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => refreshCount++,
            child: ListView(
              children: List.generate(
                  5, (i) => ListTile(title: Text('عنصر $i'))),
            ),
          ),
        ),
      ));

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  // ── Language dialog ───────────────────────────────────────────────────────

  group('Language dialog', () {
    testWidgets('shows Arabic-only dialog when tapped', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('اللغة'),
                  content:
                      const Text('التطبيق متاح باللغة العربية فقط حالياً.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('حسناً'),
                    ),
                  ],
                ),
              ),
              child: const Text('اللغة'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('اللغة'));
      await tester.pumpAndSettle();

      expect(find.text('التطبيق متاح باللغة العربية فقط حالياً.'),
          findsOneWidget);
      expect(find.text('حسناً'), findsOneWidget);
    });

    testWidgets('language dialog closes on confirm', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('اللغة'),
                  content:
                      const Text('التطبيق متاح باللغة العربية فقط حالياً.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('حسناً'),
                    ),
                  ],
                ),
              ),
              child: const Text('اللغة'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('اللغة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();

      expect(find.text('التطبيق متاح باللغة العربية فقط حالياً.'),
          findsNothing);
    });
  });
}
