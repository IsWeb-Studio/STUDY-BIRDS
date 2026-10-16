import 'dart:async';
import 'l10n/l10n.dart';
import 'core/services/locale_controller.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/app_update_service.dart';
import 'core/widgets/update_gate.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/profile_account/login_notification_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/analytics_service.dart';
import 'core/services/google_sign_in_service.dart';
import 'core/config/app_config.dart';
import 'core/services/realtime_sync_service.dart';
import 'core/services/currency_service.dart';
import 'core/network/api_client.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/notification_scheduler.dart';
import 'core/services/push_notification_service.dart';
import 'screens/auth/email_challenge_screen.dart';
import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/services/auth_session.dart';
import 'core/utils/app_error.dart';
import 'core/services/error_reporter.dart';
import 'core/utils/animations.dart';
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

class _BouncingScrollBehavior extends ScrollBehavior {
  const _BouncingScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

/// Root messenger key — lets us show a SnackBar right after
/// pushAndRemoveUntil, when the route that triggered the action has
/// already been disposed and its own context is no longer valid.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Navigator key shared with DeepLinkService so incoming links can push
/// screens without a BuildContext.
final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const Directionality(textDirection: TextDirection.rtl,
      child: Material(color: AppColors.background, child: ErrorState()));
  }
  // Sentry is initialised BEFORE the first frame (it is local and fast, capped
  // at 3s) so errors during startup are captured, not lost.
  await _initSentry();
  // Render the splash on the first frame - nothing else blocks it.
  runApp(SentryWidget(child: const StudyBirdsApp()));
  _initServicesInBackground();
}

Future<void> _initSentry() async {
  try {
    await SentryFlutter.init((options) {
      // An empty DSN disables Sentry entirely.
      const enabled = kReleaseMode ||
          bool.fromEnvironment('SENTRY_ENABLED', defaultValue: false);
      options.dsn = enabled ? AppConfig.sentryDsn : '';
      // Debug runs never pollute the production project.
      options.environment = const String.fromEnvironment('SENTRY_ENV',
          defaultValue: kReleaseMode ? 'production' : 'development');
      // Sampling kept low: profiling and tracing are costly on weak devices.
      options.tracesSampleRate = 0.05;
      options.attachScreenshot = false;
      options.sendDefaultPii = false;
      // Keep view contents out of telemetry, including experimental SDK capture.
      // ignore: experimental_member_use
      options.attachViewHierarchy = false;
      options.maxBreadcrumbs = 60;
      options.beforeSend = (event, hint) {
        // Offline / timeout noise is expected, not a defect.
        final error = event.throwable;
        if (error != null && ErrorReporter.isExpected(error)) return null;
        return event;
      };
      options.beforeBreadcrumb = (crumb, hint) {
        if (crumb == null) return null;
        // HTTP breadcrumbs may carry URLs with ids/tokens in the query string.
        final data = crumb.data;
        final url = data?['url'];
        return crumb.copyWith(
          message: crumb.message == null ? null : AppError.redact(crumb.message!),
          data: (url is String && url.contains('?'))
              ? {...data!, 'url': url.split('?').first}
              : data,
        );
      };
    }).timeout(const Duration(seconds: 3));
  } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'main.dart:132');
    // Monitoring must never stop the app from starting.
  }
}

Future<void> _initServicesInBackground() async {
  // All four services run in parallel instead of sequentially
  await Future.wait([
    _safeInit(PushNotificationService.instance.init),
    _safeInit(CurrencyService.instance.load),
    _safeInit(AnalyticsService.instance.init),
    _safeInit(GoogleSignInService.instance.init),
  ]);
  RealtimeSyncService.instance.start();
  unawaited(LocaleController.instance.load());
  // Forced-update check (no restriction if offline or the server has no policy).
  unawaited(AppUpdateService.instance.check());
  ConnectivityService.instance.onReconnected
      .listen((_) => unawaited(AppUpdateService.instance.check()));
}

Future<void> _safeInit(Future<void> Function() initialize) async {
  try { await initialize(); } catch (error, stack) {
    try { await Sentry.captureException(error, stackTrace: stack); } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'main.dart:150');
      // Optional services and diagnostic delivery must not block startup.
    }
  }
}

class StudyBirdsApp extends StatefulWidget {
  const StudyBirdsApp({super.key});

  @override
  State<StudyBirdsApp> createState() => _StudyBirdsAppState();
}

class _StudyBirdsAppState extends State<StudyBirdsApp> {
  StreamSubscription<void>? _reconnectSub;
  @override
  void initState() {
    super.initState();
    DeepLinkService.instance.init(rootNavigatorKey);
    NotificationScheduler.instance.init();
    PushNotificationService.instance.setTapHandler(_onPushTap);
    // Sign-outs that happened offline are finished once the server is reachable.
    _reconnectSub = ConnectivityService.instance.onReconnected
        .listen((_) => AuthSession.instance.flushPendingRevocations());

  }

  void _onPushTap(String screen, Map<String, dynamic> data) {
    DeepLinkService.instance.open(data['link']?.toString() ?? screen);
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    _reconnectSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => MaterialApp(
      title: 'Study Birds',
      navigatorKey: rootNavigatorKey,
      locale: LocaleController.instance.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => UpdateGate(
          service: AppUpdateService.instance,
          child: OfflineBannerWrapper(child: child ?? const SizedBox.shrink())),
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _BouncingScrollBehavior(),
      theme: AppTheme.light
          .copyWith(pageTransitionsTheme: appPageTransitionsTheme),
      home: const RootChooserScreen(),
    ));
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
  bool _onboardingDone = false;

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
      final prefs = await SharedPreferences.getInstance();
      _onboardingDone = prefs.getBool('_onboarding_done') ?? false;
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'main.dart:272');
      if (mounted)
        _error = 'تعذر استعادة الحساب. تحقق من الاتصال وحاول مجددًا.';
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const SplashScreen();
    if (_error != null)
      return Scaffold(body: ErrorState(message: _error!, onRetry: _restore));
    return ListenableBuilder(
        listenable: AuthSession.instance,
        builder: (context, _) {
          final user = AuthSession.instance.currentUser;
          if (user == null && AuthSession.instance.restoreNeedsNetwork) {
            return Scaffold(
                body: SafeArea(
                    child: ErrorState(
                        message: AppError.connection, onRetry: _restore)));
          }
          if (user == null) {
            // Onboarding (splash + intro) shows only once ever.
            // Returning logged-out users choose their role before logging in.
            return _onboardingDone || AuthSession.instance.hasSignedOut
                ? const AccountTypeEntry()
                : const ConnectedPrototypeEntry();
          }
          if (AuthSession.instance.requiresGooglePasswordSetup || (!user.hasPassword && user.authProvider != 'apple')) return const SetPasswordScreen();
          // GATE DISABLED — re-enable when needed
          // if (user.verifiedPhone == null || user.verifiedPhone!.isEmpty) {
          //   return _PhoneVerificationGate(user: user);
          // }
          return LoginNotificationGate(
              key: ValueKey(user.id),
              homeBuilder: (_) => getHomeRouteForUser(user));
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
        onSelected: (type) async {
          AnalyticsService.instance.onboardingCompleted();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('_onboarding_done', true);
          if (!ctx.mounted) return;
          _goLogin(ctx, selectedRole: type);
        },
      ),
    ));
  }

  // Roles that require admin to create — self-registration is disabled.
  static const _adminCreatedRoles = {'university', 'employee'};

  static void _goLogin(BuildContext context,
      {String? selectedRole, bool replaceAll = false}) {
    final adminOnly = _adminCreatedRoles.contains(selectedRole);
    final route = MaterialPageRoute(
      builder: (ctx) => LoginScreen(
        onForgotPassword: () => Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => const PasswordReset2FAScreen())),
        onLoginAttempt: (email, password) =>
            _attemptLogin(ctx, email, password, selectedRole: selectedRole),
        onGoRegister: adminOnly
            ? () => showDialog(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    title: const Text('إنشاء الحساب'),
                    content: Text(
                      selectedRole == 'university'
                          ? 'حسابات الجامعات يتم إنشاؤها من قبل فريق Study Birds.\n\nإذا كان لديك حساب بالفعل، سجّل دخولك مباشرة.'
                          : 'حسابات الموظفين يتم إنشاؤها من قبل الإدارة.\n\nإذا كان لديك حساب، سجّل دخولك مباشرة.',
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('حسنًا')),
                    ],
                  ),
                )
            : () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (ctx2) => RegisterScreen(
                      onRegisterAttempt: (name, email, password,
                              [referralCode]) =>
                          _attemptRegister(ctx2, name, email, password,
                              role: selectedRole,
                              referralCode: referralCode),
                      onGoLogin: () => Navigator.of(ctx2).pop(),
                      onGoogleSignInSuccess: () {
                        if (!ctx2.mounted) return;
                        Navigator.of(ctx2).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const RootChooserScreen()),
                            (route) => false);
                      }),
                )),
        onGoogleSignInSuccess: () {
          if (!ctx.mounted) return;
          Navigator.of(ctx).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RootChooserScreen()),
              (route) => false);
        },
      ),
    );
    if (replaceAll) {
      Navigator.of(context).pushAndRemoveUntil(route, (r) => false);
    } else {
      Navigator.of(context).push(route);
    }
  }

  static Future<bool> _attemptLogin(
    BuildContext context,
    String email,
    String password, {
    String? selectedRole,
  }) async {
    late ({AuthUser user, String token, String? refreshToken}) result;
    try {
      result = await AuthService.instance.loginOrThrow(email, password);
    } on ApiException catch (e) {
      if (e.statusCode != 428) AuthSession.instance.reportAuthFailure(e);
      if (e.statusCode != 428 || !context.mounted) return false;
      final confirmed =
          await Navigator.of(context).push<bool>(MaterialPageRoute(
              builder: (_) => EmailChallengeScreen(
                    confirm: (code) async {
                      result = await AuthService.instance
                          .loginOrThrow(email, password, twoFactorCode: code);
                    },
                    resend: () async {
                      try {
                        await AuthService.instance.loginOrThrow(email, password);
                      } on ApiException catch (e) {
                        if (e.statusCode != 428) rethrow;
                      }
                    },
                  )));
      if (confirmed != true) return false;
    } catch (e) {
      AuthSession.instance.reportAuthFailure(e);
      return false;
    }
    final user = result.user;

    if (selectedRole != null && user.role.key != selectedRole) {
      if (!context.mounted) return true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('نوع الحساب غير مطابق'),
          content: Text(
              'حسابك هو حساب ${user.role.label}، وليس النوع الذي اخترته.\n\nارجع واختر النوع الصحيح للمتابعة.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('ارجع'),
            ),
          ],
        ),
      );
      return true;
    }

    await AuthSession.instance
        .login(user, authToken: result.token, refreshToken: result.refreshToken);

    if (!context.mounted) return true;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootChooserScreen()),
        (route) => false);
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
    String? referralCode,
  }) async {
    final AuthUser user;
    final String token;
    String? refreshToken;
    try {
      final result = await AuthService.instance.register(
          name: name,
          email: email,
          password: password,
          role: role,
          referralCode: referralCode);
      user = result.user;
      token = result.token;
      refreshToken = result.refreshToken;
    } catch (e) {
      AuthSession.instance.reportAuthFailure(e, mayHaveCompleted: true);
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

/// Shown to returning users (onboarding already seen) who are not logged in.
/// Returning users choose their account type before opening role-aware login.
class AccountTypeEntry extends StatelessWidget {
  const AccountTypeEntry({super.key});
  @override
  Widget build(BuildContext context) => AccountTypeSelectionScreen(
      onSelected: (type) => ConnectedPrototypeEntry._goLogin(
          context, selectedRole: type));
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
