import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/auth_session.dart';
import '../../core/widgets/sponsor_credit.dart';
import '../stories/friends_screen.dart';
import '../../main.dart' show RootChooserScreen;
import '../applications_documents_payments/applications_screens.dart';
import '../applications_documents_payments/documents_screens.dart';
import '../applications_documents_payments/payments_screens.dart';
import '../services_support/services_consultation_screens.dart';
import '../services_support/support_team_ai_screens.dart';
import '../services_support/messaging_and_emergency_screens.dart';
import '../services_support/knowledge_base_screen.dart';
import '../services_support/faq_screen.dart';
import '../services_support/public_student_content.dart';
import '../universities_programs_countries/explore_hub_screen.dart';
import '../universities_programs_countries/universities_screens.dart';
import '../universities_programs_countries/programs_screens.dart';
import '../universities_programs_countries/countries_scholarships_screens.dart';
import '../visa_travel_accommodation/accommodation_arrival_screens.dart';
import '../visa_travel_accommodation/arrival_services_screen.dart';
import '../visa_travel_accommodation/visa_travel_screens.dart';
import 'journey_tracker_screen.dart';

void showStudentMenu(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween(begin: const Offset(-1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child),
    pageBuilder: (panelContext, _, __) => Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: (MediaQuery.sizeOf(context).width * .9).clamp(0, 420),
        height: double.infinity,
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          borderRadius:
              const BorderRadius.horizontal(right: Radius.circular(26)),
          child: StudentMenuPanel(
            onClose: () => Navigator.pop(panelContext),
            onOpen: (screen) {
              Navigator.pop(panelContext);
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => screen));
            },
            onLogout: () async {
              Navigator.pop(panelContext);
              final confirmed = await showAppConfirmDialog(context,
                  title: 'تسجيل الخروج',
                  message: 'هل تريد تسجيل الخروج من حسابك؟',
                  confirmLabel: 'تسجيل الخروج',
                  danger: true);
              if (!confirmed || !context.mounted) return;
              await AuthSession.instance.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const RootChooserScreen()),
                    (_) => false);
              }
            },
          ),
        ),
      ),
    ),
  );
}

class StudentMenuPanel extends StatelessWidget {
  final VoidCallback onClose, onLogout;
  final ValueChanged<Widget> onOpen;
  const StudentMenuPanel(
      {super.key,
      required this.onClose,
      required this.onOpen,
      required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String text(String arabic, String english) => ar ? arabic : english;
    Widget item(String id, IconData icon, String arabic, String english,
            Widget screen) =>
        ListTile(
            key: ValueKey('menu-item-$id'),
            contentPadding:
                const EdgeInsetsDirectional.only(start: 24, end: 16),
            leading: Icon(icon, size: 21, color: AppColors.navy),
            title: Text(text(arabic, english),
                style: const TextStyle(fontSize: 14)),
            trailing: Icon(ar ? Icons.chevron_left : Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
            onTap: () => onOpen(screen));
    Widget section(String id, IconData icon, String arabic, String english,
            List<Widget> items) =>
        ExpansionTile(
            key: ValueKey('menu-section-$id'),
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            leading: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 21, color: AppColors.greenInk)),
            title: Text(text(arabic, english),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            children: items);
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              const Icon(Icons.menu_rounded, color: AppColors.greenInk),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text('القائمة', 'Menu'),
                      style: AppTextStyles.screenTitle)),
              IconButton(
                  tooltip: text('إغلاق القائمة', 'Close menu'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded)),
            ])),
        const Divider(height: 1),
        Expanded(
            child: Scrollbar(
                child: ListView(
          key: const ValueKey('student-menu-scroll'),
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            section('discover', Icons.explore_outlined, 'الاستكشاف والمحتوى',
                'Discover and content', [
              item('explore', Icons.explore_outlined, 'الاستكشاف', 'Explore',
                  const ExploreHubScreen()),
              item('success', Icons.emoji_events_outlined, 'قصص النجاح',
                  'Success stories', const PublicStudentContentScreen()),
              item(
                  'offices',
                  Icons.location_on_outlined,
                  'مكاتبنا',
                  'Our offices',
                  const PublicStudentContentScreen(offices: true)),
              item('universities', Icons.account_balance_outlined, 'الجامعات',
                  'Universities', const UniversitiesExplorerScreen()),
              item('programs', Icons.menu_book_outlined, 'البرامج', 'Programs',
                  const ProgramsExplorerScreen()),
              item('scholarships', Icons.school_outlined, 'المنح',
                  'Scholarships', const ScholarshipsScreen()),
            ]),
            section('journey', Icons.route_outlined, 'رحلة التقديم والمتابعة',
                'Applications and progress', [
              item('journey', Icons.route_outlined, 'الرحلة', 'My journey',
                  const JourneyTrackerScreen()),
              item('applications', Icons.description_outlined, 'طلباتي',
                  'My applications', const ApplicationsListScreen()),
              item(
                  'documents',
                  Icons.upload_file_outlined,
                  'رفع مستند',
                  'Upload document',
                  const MyDocumentsScreen(openUploadOnStart: true)),
              item('payments', Icons.payments_outlined, 'المدفوعات', 'Payments',
                  const PaymentsSummaryScreen()),
            ]),
            section('services', Icons.support_agent_outlined,
                'الخدمات الاستشارية واللوجستية', 'Consultation and services', [
              item('services', Icons.grid_view_outlined, 'الخدمات',
                  'All services', const ServicesCenterScreen()),
              item(
                  'consultation',
                  Icons.event_available_outlined,
                  'حجز استشارة',
                  'Book consultation',
                  const ConsultationBookingScreen()),
              item('housing', Icons.home_work_outlined, 'السكن',
                  'Accommodation', const AccommodationScreen()),
              item('travel', Icons.flight_takeoff_rounded, 'السفر', 'Travel',
                  const TravelCenterScreen()),
              item(
                  'arrival',
                  Icons.airport_shuttle_outlined,
                  'خدمات الوصول والإقامة',
                  'Arrival and residence support',
                  const ArrivalServicesScreen()),
            ]),
            section('visa', Icons.badge_outlined, 'التأشيرة', 'Visa', [
              item('visa', Icons.badge_outlined, 'التأشيرة', 'Visa center',
                  const VisaCenterScreen()),
              item('visa-steps', Icons.checklist_rounded, 'خطوات التأشيرة',
                  'Visa steps', const VisaStepsScreen()),
            ]),
            section('support', Icons.headset_mic_outlined, 'مركز الدعم',
                'Support center', [
              item('support', Icons.help_outline, 'المساعدة والدعم',
                  'Help and support', const SupportCenterScreen()),
              item('ticket-new', Icons.add_comment_outlined, 'تذكرة دعم جديدة',
                  'New support ticket', const NewSupportTicketScreen()),
              item('tickets', Icons.confirmation_number_outlined, 'تذاكري',
                  'My tickets', const SupportTicketsListScreen()),
              item('team', Icons.groups_outlined, 'فريقي', 'My team',
                  const MyTeamScreen()),
              item('knowledge', Icons.menu_book_outlined, 'مركز المعرفة',
                  'Knowledge center', const KnowledgeBaseScreen()),
              item('exhibitions', Icons.article_outlined, 'محطة المعارض',
                  'Exhibitions', const ExhibitionsScreen()),
              item('emergency', Icons.emergency_outlined, 'مساعدة عاجلة',
                  'Urgent help', const EmergencySupportScreen()),
            ]),
            section('more', Icons.more_horiz_rounded, 'المزيد', 'More', [
              item('faq', Icons.quiz_outlined, 'الأسئلة الشائعة',
                  'Frequently asked questions', const FaqScreen()),
              ListTile(
                  key: const ValueKey('menu-item-share'),
                  contentPadding:
                      const EdgeInsetsDirectional.only(start: 24, end: 16),
                  leading:
                      const Icon(Icons.link_rounded, color: AppColors.navy),
                  title: Text(text('نسخ رابط التطبيق', 'Copy app link')),
                  onTap: () async {
                    await Clipboard.setData(
                        const ClipboardData(text: 'https://studybirds.net'));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(text('تم نسخ الرابط للمشاركة',
                              'Link copied for sharing'))));
                    }
                  }),
            ]),
          ],
        ))),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('menu-refer-friends'),
                onPressed: () => onOpen(const FriendsScreen()),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Refer Friends'),
              )),
        ),
        ListTile(
            key: const ValueKey('menu-logout'),
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: Text(text('تسجيل الخروج', 'Sign out'),
                style: const TextStyle(color: AppColors.danger)),
            onTap: onLogout),
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SponsorCredit()),
      ])),
    );
  }
}
