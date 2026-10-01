import 'package:shared_preferences/shared_preferences.dart';
import 'screens/profile_account/notification_permission_sheet.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/analytics_service.dart';
import 'core/google_sign_in_service.dart';
import 'core/app_config.dart';
import 'core/realtime_sync_service.dart';
import 'core/currency_service.dart';
import 'core/device_lock.dart';
import 'core/api_client.dart';
import 'core/deep_link_service.dart';
import 'core/notification_scheduler.dart';
import 'core/push_notification_service.dart';
import 'screens/auth/email_challenge_screen.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/auth_session.dart';
import 'core/animations.dart';

import 'screens/auth/splash_screen.dart';
import 'screens/auth/onboarding_and_account_type_screens.dart';
import 'screens/auth/login_register_screens.dart';
import 'screens/auth/otp_and_password_reset_screens.dart';
import 'screens/auth/student_registration_wizard_screen.dart';

import 'screens/home_journey/home_dashboard_screen.dart';
import 'screens/home_journey/journey_tracker_screen.dart';
import 'screens/home_journey/calendar_screen.dart';
import 'screens/home_journey/activity_log_screen.dart';
import 'screens/home_journey/notifications_screen.dart';
import 'screens/home_journey/important_dates_screen.dart';
import 'screens/home_journey/global_search_screen.dart';

import 'screens/auth/verify_contact_screen.dart';
import 'screens/profile_account/security_settings_screen.dart';

import 'screens/universities_programs_countries/compare_list_screen.dart';
import 'screens/services_support/messaging_and_emergency_screens.dart';

import 'screens/roles/agent_student_detail_screen.dart';
import 'screens/roles/employee_extra_screens.dart';

import 'screens/applications_documents_payments/applications_screens.dart';
import 'screens/applications_documents_payments/documents_screens.dart';
import 'screens/applications_documents_payments/payments_screens.dart';

import 'screens/universities_programs_countries/universities_screens.dart';
import 'screens/universities_programs_countries/programs_screens.dart';
import 'screens/universities_programs_countries/countries_scholarships_screens.dart';

import 'screens/visa_travel_accommodation/visa_travel_screens.dart';
import 'screens/visa_travel_accommodation/accommodation_arrival_screens.dart';

import 'screens/services_support/services_consultation_screens.dart';
import 'screens/services_support/support_team_ai_screens.dart';

import 'screens/profile_account/profile_account_screens.dart';

import 'screens/roles/parent_dashboard_screen.dart';
import 'screens/roles/agent_dashboard_screen.dart';
import 'screens/roles/university_dashboard_screen.dart';
import 'screens/roles/employee_dashboard_screen.dart';
import 'screens/roles/admin_users_access_screen.dart';

/// Root messenger key — lets us show a SnackBar right after
/// pushAndRemoveUntil, when the route that triggered the action has
/// already been disposed and its own context is no longer valid.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Navigator key shared with DeepLinkService so incoming links can push
/// screens without a BuildContext.
final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.sentryDsn;
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.1;
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
    },
    appRunner: () async {
      await PushNotificationService.instance.init();
      await CurrencyService.instance.load();
      await AnalyticsService.instance.init();
      await GoogleSignInService.instance.init();
      RealtimeSyncService.instance.start();
      runApp(SentryWidget(child: const StudyBirdsApp()));
    },
  );
}

class StudyBirdsApp extends StatefulWidget {
  const StudyBirdsApp({super.key});

  @override
  State<StudyBirdsApp> createState() => _StudyBirdsAppState();
}

class _StudyBirdsAppState extends State<StudyBirdsApp> {
  @override
  void initState() {
    super.initState();
    DeepLinkService.instance.init(rootNavigatorKey);
    NotificationScheduler.instance.init();
    PushNotificationService.instance.setTapHandler(_onPushTap);
    // Show the notification rationale sheet only once, ever.
    // We persist a flag in SharedPreferences so the sheet never re-appears
    // after the user has interacted with it — even if OneSignal.permission
    // returns false transiently on startup while the SDK is still loading.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!PushNotificationService.instance.supported) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('_notif_sheet_shown') == true) return;
      // Already granted before we ever showed the sheet — just record it.
      if (PushNotificationService.instance.permissionGranted) {
        await prefs.setBool('_notif_sheet_shown', true);
        return;
      }
      if (!mounted) return;
      final navigatorContext = rootNavigatorKey.currentContext;
      if (navigatorContext == null) return;
      // Mark shown regardless of the user's choice so we never show again.
      await prefs.setBool('_notif_sheet_shown', true);
      final allow = await showModalBottomSheet<bool>(
        context: navigatorContext,
        useRootNavigator: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const NotificationPermissionSheet(),
      );
      if (allow == true) {
        try {
          await PushNotificationService.instance.requestPermission();
        } catch (_) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
                content: Text(
                    'تعذر تفعيل الإشعارات. حاول مجددًا من إعدادات الإشعارات.')),
          );
        }
      }
    });
  }

  void _onPushTap(String screen, Map<String, dynamic> data) {
    DeepLinkService.instance.open(data['link']?.toString() ?? screen);
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Birds',
      navigatorKey: rootNavigatorKey,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => DeviceLockGate(
          child: OfflineBannerWrapper(child: child ?? const SizedBox.shrink())),
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light
          .copyWith(pageTransitionsTheme: appPageTransitionsTheme),
      home: const RootChooserScreen(),
    );
  }
}

/// Restores the account and opens its role-specific home, or onboarding.
class RootChooserScreen extends StatefulWidget {
  const RootChooserScreen({super.key});

  @override
  State<RootChooserScreen> createState() => _RootChooserScreenState();
}

class _RootChooserScreenState extends State<RootChooserScreen> {
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await AuthSession.instance.restore();
    } catch (_) {
      if (mounted)
        _error = 'تعذر استعادة الحساب. تحقق من الاتصال وحاول مجددًا.';
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: LoadingState());
    if (_error != null)
      return Scaffold(body: ErrorState(message: _error!, onRetry: _restore));
    return ListenableBuilder(
        listenable: AuthSession.instance,
        builder: (context, _) {
          final user = AuthSession.instance.currentUser;
          return user == null
              ? const ConnectedPrototypeEntry()
              : getHomeRouteForUser(user);
        });
  }
}

/// Opens onboarding and login. The authenticated server role decides the home.
class ConnectedPrototypeEntry extends StatelessWidget {
  const ConnectedPrototypeEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return SplashScreen(onFinished: () => _goOnboardingIntro(context));
  }

  static void _goOnboardingIntro(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (ctx) =>
          OnboardingIntroScreen(onDone: () => _goOnboardingServices(ctx)),
    ));
  }

  static void _goOnboardingServices(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (ctx) =>
          OnboardingServicesScreen(onContinue: () => _goAccountType(ctx)),
    ));
  }

  static void _goAccountType(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (ctx) => AccountTypeSelectionScreen(
        onSelected: (type) {
          AnalyticsService.instance.onboardingCompleted();
          _goLogin(ctx, selectedRole: type);
        },
      ),
    ));
  }

  static void _goLogin(BuildContext context, {String? selectedRole}) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (ctx) => LoginScreen(
        onForgotPassword: () => Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => const PasswordReset2FAScreen())),
        onLoginAttempt: (email, password) =>
            _attemptLogin(ctx, email, password),
        onGoRegister: () => Navigator.of(ctx).push(MaterialPageRoute(
          builder: (ctx2) => RegisterScreen(
              onRegisterAttempt: (name, email, password) =>
                  _attemptRegister(ctx2, name, email, password,
                      role: selectedRole)),
        )),
        onGoogleSignInSuccess: () {
          if (!ctx.mounted) return;
          Navigator.of(ctx).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RootChooserScreen()),
              (route) => false);
        },
      ),
    ));
  }

  /// Returns true/false to the LoginScreen (for its own error display), and
  /// on success performs the ONE centralized redirect — by real role only.
  /// There is no "claimed role" anymore (the account-type-selection step was
  /// removed) — the person just logs in, and is told their real role here.
  static Future<bool> _attemptLogin(
    BuildContext context,
    String email,
    String password,
  ) async {
    late ({AuthUser user, String token, String? refreshToken}) result;
    try {
      result = await AuthService.instance.loginOrThrow(email, password);
    } on ApiException catch (e) {
      if (e.statusCode != 428 || !context.mounted) return false;
      final confirmed =
          await Navigator.of(context).push<bool>(MaterialPageRoute(
              builder: (_) => EmailChallengeScreen(confirm: (code) async {
                    result = await AuthService.instance
                        .loginOrThrow(email, password, twoFactorCode: code);
                  })));
      if (confirmed != true) return false;
    } catch (_) {
      return false;
    }
    final user = result.user;
    final token = result.token;

    await AuthSession.instance
        .login(user, authToken: token, refreshToken: result.refreshToken);

    if (!context.mounted) return true;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootChooserScreen()),
        (route) => false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
              'تم تسجيل دخولك كـ "${user.role.label}". لتغيير نوع حسابك، تواصل مع الإدارة.'),
          backgroundColor: AppColors.navy,
        ),
      );
    });
    return true;
  }

  /// Public registration. Student, parent, and agent (partner) roles are accepted;
  /// university and employee accounts must be created by an admin.
  static Future<bool> _attemptRegister(
    BuildContext context,
    String name,
    String email,
    String password, {
    String? role,
  }) async {
    final AuthUser user;
    final String token;
    String? refreshToken;
    try {
      final result = await AuthService.instance
          .register(name: name, email: email, password: password, role: role);
      user = result.user;
      token = result.token;
      refreshToken = result.refreshToken;
    } catch (_) {
      return false; // RegisterScreen shows its generic "couldn't create account" message.
    }

    await AuthSession.instance
        .login(user, authToken: token, refreshToken: refreshToken);
    if (!context.mounted) return true;
    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootChooserScreen()),
        (route) => false);
    // Only students get the profile setup wizard after registration.
    if (user.role == UserRole.student) {
      navigator.push(MaterialPageRoute(
          builder: (_) => const StudentRegistrationWizardScreen()));
    }
    return true;
  }
}

/// A simple gallery so you (or a reviewer) can open any screen instantly
/// without wiring up full navigation/routing yet. Not part of the final app.
class ScreensGallery extends StatefulWidget {
  const ScreensGallery({super.key});

  @override
  State<ScreensGallery> createState() => _ScreensGalleryState();
}

class _ScreensGalleryState extends State<ScreensGallery> {
  String _query = '';

  static final Map<String, List<_GalleryEntry>> _sections = {
    'Auth': [
      _GalleryEntry('Splash', () => const SplashScreen()),
      _GalleryEntry(
          'Onboarding Intro', () => OnboardingIntroScreen(onDone: () {})),
      _GalleryEntry('Onboarding Services',
          () => OnboardingServicesScreen(onContinue: () {})),
      _GalleryEntry('Account Type Selection',
          () => AccountTypeSelectionScreen(onSelected: (_) {})),
      _GalleryEntry('Login', () => const LoginScreen()),
      _GalleryEntry('Register (simple)', () => const RegisterScreen()),
      _GalleryEntry('Register (3-step wizard, per spec)',
          () => StudentRegistrationWizardScreen(onFinished: () {})),
      _GalleryEntry('OTP Verification', () => const OTPVerificationScreen()),
      _GalleryEntry(
          'Verify Email', () => const VerifyContactScreen(isEmail: true)),
      _GalleryEntry(
          'Verify Phone',
          () => const VerifyContactScreen(
              isEmail: false, contact: '+90 5XX XXX XX 12')),
      _GalleryEntry(
          'Password Reset (2FA)', () => const PasswordReset2FAScreen()),
    ],
    'Home & Journey': [
      _GalleryEntry(
          'Home Dashboard (live data)', () => const HomeDashboardScreen()),
      _GalleryEntry('Journey Tracker', () => const JourneyTrackerScreen()),
      _GalleryEntry('Calendar', () => const CalendarScreen()),
      _GalleryEntry('Activity Log', () => const ActivityLogScreen()),
      _GalleryEntry('Notifications', () => const NotificationsScreen()),
      _GalleryEntry('Important Dates', () => const ImportantDatesScreen()),
      _GalleryEntry('Global Search', () => const GlobalSearchScreen()),
    ],
    'Applications, Documents & Payments': [
      _GalleryEntry('Applications List (live data)',
          () => const ApplicationsListScreen()),
      _GalleryEntry('My Documents', () => const MyDocumentsScreen()),
      _GalleryEntry(
          'Document Detail (sample)',
          () => DocumentDetailScreen(document: const {
                'type': 'passport',
                'fileName': 'passport-scan.pdf',
                'status': 'rejected',
                'reviewNote': 'الصورة غير واضحة، برجاء رفع نسخة أوضح.',
                'createdAt': '2026-09-10T00:00:00.000Z',
              })),
      _GalleryEntry(
          'Payments Summary (live data)', () => const PaymentsSummaryScreen()),
      _GalleryEntry(
          'Payment Detail (sample)',
          () => PaymentDetailScreen(invoice: const {
                '_id': 'sample',
                'description': 'دفعة القبول الأولى',
                'invoiceNumber': 'INV-0001',
                'amount': 500,
                'status': 'unpaid',
              })),
      _GalleryEntry(
          'Payment History (live data)', () => const PaymentHistoryScreen()),
    ],
    'Universities, Programs, Countries & Scholarships': [
      _GalleryEntry(
          'Universities Explorer', () => const UniversitiesExplorerScreen()),
      _GalleryEntry('University Detail (needs real ID via Explorer)',
          () => const UniversitiesExplorerScreen()),
      _GalleryEntry(
          'Compare Universities', () => const CompareUniversitiesScreen()),
      _GalleryEntry('Programs Explorer', () => const ProgramsExplorerScreen()),
      _GalleryEntry('Program Detail (needs real ID via Explorer)',
          () => const ProgramsExplorerScreen()),
      _GalleryEntry('Program Finder', () => const ProgramFinderScreen()),
      _GalleryEntry('Program Finder Results (needs real data via Finder)',
          () => const ProgramFinderScreen()),
      _GalleryEntry(
          'Countries Explorer', () => const CountriesExplorerScreen()),
      _GalleryEntry('Country Detail (needs real data via Explorer)',
          () => const CountriesExplorerScreen()),
      _GalleryEntry('Scholarships', () => const ScholarshipsScreen()),
      _GalleryEntry('Compare List (saved)', () => const CompareListScreen()),
    ],
    'Visa, Travel, Accommodation & After Arrival': [
      _GalleryEntry('Visa Center', () => const VisaCenterScreen()),
      _GalleryEntry('Visa Steps', () => const VisaStepsScreen()),
      _GalleryEntry('Travel Center', () => const TravelCenterScreen()),
      _GalleryEntry('Airport Pickup', () => const AirportPickupScreen()),
      _GalleryEntry('Accommodation', () => const AccommodationScreen()),
      _GalleryEntry('University Registration',
          () => const UniversityRegistrationScreen()),
      _GalleryEntry('Insurance', () => const InsuranceScreen()),
      _GalleryEntry('Equivalency', () => const EquivalencyScreen()),
    ],
    'Services, Support & Consultation': [
      _GalleryEntry('Services Center', () => const ServicesCenterScreen()),
      _GalleryEntry(
          'Service Detail (sample)',
          () => ServiceDetailScreen(service: const {
                'name': 'الترجمة',
                'price': '20\$',
                'icon': Icons.translate_rounded
              })),
      _GalleryEntry(
          'Consultation Booking', () => const ConsultationBookingScreen()),
      _GalleryEntry(
          'Consultation Confirmation',
          () => const ConsultationConfirmationScreen(slot: {
                '_id': 'demo',
                'startsAt': '2026-09-25T09:00:00.000Z',
                'mode': 'online',
                'advisor': {'name': 'سارة أحمد'},
                'meetingUrl': 'https://meet.studybirds.com/xyz',
              })),
      _GalleryEntry('Support Center', () => const SupportCenterScreen()),
      _GalleryEntry('New Support Ticket', () => const NewSupportTicketScreen()),
      _GalleryEntry('My Support Tickets (live data)',
          () => const SupportTicketsListScreen()),
      _GalleryEntry('My Team', () => const MyTeamScreen()),
      _GalleryEntry('Bird AI Chat', () => const BirdAIChatScreen()),
      _GalleryEntry('Conversation Thread (In-App Messaging)',
          () => const ConversationThreadScreen()),
      _GalleryEntry('Emergency Support', () => const EmergencySupportScreen()),
    ],
    'Profile & Account': [
      _GalleryEntry('Profile', () => const ProfileScreen()),
      _GalleryEntry('Settings', () => const SettingsScreen()),
      _GalleryEntry('Security Settings (2FA/Sessions)',
          () => const SecuritySettingsScreen()),
      _GalleryEntry('Referral Program', () => const ReferralProgramScreen()),
      _GalleryEntry('My Wallet', () => const MyWalletScreen()),
      _GalleryEntry('Favorites', () => const FavoritesScreen()),
    ],
    'Other Account Types (Parent / Agent / University / Employee)': [
      _GalleryEntry('Parent Dashboard', () => const ParentDashboardScreen()),
      _GalleryEntry('Agent Dashboard', () => const AgentDashboardScreen()),
      _GalleryEntry('Agent — Student Detail (needs real data via Dashboard)',
          () => const AgentDashboardScreen()),
      _GalleryEntry(
          'Agent — My Commissions', () => const MyCommissionsScreen()),
      _GalleryEntry(
          'University Dashboard', () => const UniversityDashboardScreen()),
      _GalleryEntry(
          'University — Application Review (needs real data via Dashboard)',
          () => const UniversityDashboardScreen()),
      _GalleryEntry(
          'Employee Dashboard (sample, live overview if role allows)',
          () => EmployeeDashboardScreen(
              user: const AuthUser(
                  id: 'sample',
                  name: 'موظف تجريبي',
                  email: 'sample@studybirds.demo',
                  role: UserRole.employee,
                  permissions: {'students', 'parent-links'}))),
      _GalleryEntry('Employee/Admin Dashboard (live data)',
          () => const AdminUsersAccessScreen()),
      _GalleryEntry(
          'Employee — My Students Queue', () => const MyStudentsQueueScreen()),
      _GalleryEntry(
          'Employee — Messages Inbox', () => const MessagesInboxScreen()),
      _GalleryEntry('Manager Overview', () => const ManagerOverviewScreen()),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final filtered = <String, List<_GalleryEntry>>{};
    for (final entry in _sections.entries) {
      final matches = _query.isEmpty
          ? entry.value
          : entry.value
              .where(
                  (e) => e.title.toLowerCase().contains(_query.toLowerCase()))
              .toList();
      if (matches.isNotEmpty) filtered[entry.key] = matches;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('Study Birds — Screens Gallery',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search screens...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: filtered.entries.expand((section) sync* {
                yield Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(section.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          fontSize: 13)),
                );
                for (final e in section.value) {
                  yield ListTile(
                    title: Text(e.title),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => e.builder()),
                    ),
                  );
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryEntry {
  final String title;
  final Widget Function() builder;
  const _GalleryEntry(this.title, this.builder);
}
