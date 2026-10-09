import '../core/widgets/feature_ui.dart';
import '../core/widgets/app_notice.dart';
import '../core/utils/app_error.dart';
import '../core/widgets/security_fields.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../core/network/study_birds_api.dart';
import '../core/config/app_theme.dart';
import '../screens/auth/onboarding_and_account_type_screens.dart';
import '../screens/auth/splash_screen.dart';

part 'connected_home_shell.dart';
part 'connected_workspace.dart';
part 'connected_student_features.dart';

typedef Json = Map<String, dynamic>;

class ConnectedApp extends StatefulWidget {
  const ConnectedApp({super.key});
  @override
  State<ConnectedApp> createState() => _ConnectedAppState();
}

class _ConnectedAppState extends State<ConnectedApp>
    with WidgetsBindingObserver {
  final api = StudyBirdsApi();
  Json? config;
  String? error;
  bool loading = true;
  int introStep = 0;
  String? selectedRole;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    api.addListener(_sessionChanged);
    _start();
  }

  void _sessionChanged() {
    if (mounted) {
      setState(() {
        if (!api.authenticated) selectedRole = null;
      });
    }
  }

  Future<void> _start() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await api.request('GET', '/mobile/config');
      try {
        await api.restore();
      } on ApiException catch (e) {
        if (e.status != 401) rethrow;
      }
      final seenIntro = await api.hasSeenIntroduction();
      if (seenIntro || api.authenticated) introStep = 2;
      if (mounted) setState(() => config = Json.from(value));
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> refreshConfig() async {
    final value = await api.request('GET', '/mobile/config');
    if (mounted) setState(() => config = Json.from(value));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && config != null) {
      refreshConfig().catchError((Object e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(AppSnackBar(content: Text(AppError.message(e))));
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    api.removeListener(_sessionChanged);
    api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.tryParse(
            'FF${(config?['primaryColor'] ?? '#102B4E').toString().replaceAll('#', '')}',
            radix: 16) ??
        0xFF102B4E);
    return Theme(
        data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: AppColors.background,
            appBarTheme: AppBarTheme(
                backgroundColor: color,
                foregroundColor: Colors.white,
                centerTitle: true,
                elevation: 0,
                surfaceTintColor: Colors.transparent),
            cardTheme: CardThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    side: const BorderSide(color: AppColors.border))),
            colorScheme: ColorScheme.fromSeed(
                seedColor: color,
                primary: color,
                secondary: AppColors.orange,
                surface: Colors.white)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: loading
              ? const SplashScreen()
              : error != null
                  ? Scaffold(body: ErrorPanel(message: error!, retry: _start))
                  : config?['maintenance'] == true
                      ? Scaffold(
                          body: ErrorPanel(
                              message: config?['maintenanceMessage'] ??
                                  'التطبيق تحت الصيانة',
                              retry: refreshConfig))
                      : !api.authenticated
                          ? introStep == 0
                              ? OnboardingIntroScreen(
                                  onDone: () => setState(() => introStep = 1))
                              : introStep == 1
                                  ? OnboardingServicesScreen(
                                      onContinue: () async {
                                      await api.completeIntroduction();
                                      if (mounted) {
                                        setState(() => introStep = 2);
                                      }
                                    })
                                  : selectedRole == null
                                      ? AccountTypeSelectionScreen(
                                          onSelected: (type) => setState(() =>
                                              selectedRole = type == 'agent'
                                                  ? 'partner'
                                                  : type))
                                      : PopScope(
                                          canPop: false,
                                          onPopInvokedWithResult: (didPop, _) {
                                            if (!didPop) setState(() => selectedRole = null);
                                          },
                                          child: ConnectedLogin(
                                              api: api,
                                              accountRole: selectedRole,
                                              onChangeRole: () => setState(
                                                  () => selectedRole = null),
                                              title: config?['title'] ?? 'Study Birds'))
                          : Navigator(
                              key: ValueKey(
                                  '${api.user?['_id']}-${config?['revision']}-${api.needsProfileSetup}'),
                              onGenerateRoute: (_) => MaterialPageRoute(
                                  builder: (_) => ConnectedHome(
                                      api: api,
                                      config: config!,
                                      refreshConfig: refreshConfig))),
        ));
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => ErrorState(message: message, onRetry: () async {
    try { await retry(); } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(content: Text(AppError.message(e))));
    }
  });
}

class ConnectedLogin extends StatefulWidget {
  const ConnectedLogin(
      {super.key,
      required this.api,
      required this.title,
      this.accountRole,
      this.onChangeRole});
  final StudyBirdsApi api;
  final String title;
  final String? accountRole;
  final VoidCallback? onChangeRole;
  @override
  State<ConnectedLogin> createState() => _ConnectedLoginState();
}

class _ConnectedLoginState extends State<ConnectedLogin> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  final twoFactorCode = TextEditingController();
  bool twoFactor = false;
  final form = GlobalKey<FormState>();
  bool register = false, busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    twoFactorCode.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.authenticate(email.text, password.text,
          name: register ? name.text : null,
          accountRole: widget.accountRole,
          twoFactorCode: twoFactor ? twoFactorCode.text.trim() : null);
    } catch (e) {
      if (e is ApiException && e.status == 428) twoFactor = true;
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                          key: form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Image.asset('assets/images/logo_mark.png',
                                    height: 80),
                                const SizedBox(height: 20),
                                Text(widget.title,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.screenTitle),
                                const SizedBox(height: 12),
                                if (widget.accountRole != null)
                                  TextButton.icon(
                                      onPressed:
                                          busy ? null : widget.onChangeRole,
                                      icon: const Icon(
                                          Icons.switch_account_outlined),
                                      label: Text(accountRoleLabel(
                                          widget.accountRole!))),
                                Text(
                                    register
                                        ? 'إنشاء حساب ${accountRoleLabel(widget.accountRole ?? 'student')}'
                                        : 'سجّل دخولك لمتابعة رحلتك الدراسية',
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 28),
                                if (register)
                                  TextFormField(
                                      controller: name,
                                      decoration: const InputDecoration(
                                          labelText: 'الاسم الكامل'),
                                      validator: (v) => v!.trim().isEmpty
                                          ? 'أدخل اسمك'
                                          : null),
                                TextFormField(
                                    controller: email,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                        labelText: 'البريد الإلكتروني'),
                                    validator: (v) =>
                                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                .hasMatch(v!.trim())
                                            ? 'أدخل بريداً صحيحاً'
                                            : null),
                                const SizedBox(height: 12),
                                SecureTextField(
                                    controller: password,
                                    showStrength: true,
                                    requireStrong: register,
                                    obscureText: true,
                                    autofillHints: [
                                      register
                                          ? AutofillHints.newPassword
                                          : AutofillHints.password
                                    ],
                                    decoration: const InputDecoration(
                                        labelText: 'كلمة المرور'),
                                    validator: (v) => v!.isEmpty ||
                                            (register && v.length < 8)
                                        ? 'أدخل كلمة مرور${register ? ' من 8 أحرف على الأقل' : ''}'
                                        : null,
                                    onFieldSubmitted: (_) {
                                      if (!busy) submit();
                                    }),
                                if (twoFactor && !register) ...[
                                  VerificationCodeField(controller: twoFactorCode, enabled: !busy, validator: (v) => v == null ||
                                              !RegExp(r'^\d{6}$').hasMatch(v)
                                          ? 'أدخل الرمز المكون من 6 أرقام'
                                          : null),
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => setState(() {
                                                twoFactor = false;
                                                twoFactorCode.clear();
                                                error = null;
                                              }),
                                      child: const Text('إعادة إرسال الرمز')),
                                ],
                                if (error != null)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: InlineNotice(error!, error: true)),
                                const SizedBox(height: 24),
                                FilledButton(
                                    onPressed: busy ? null : submit,
                                    child: Text(busy
                                        ? 'جارٍ الاتصال…'
                                        : register
                                            ? 'إنشاء حساب'
                                            : 'تسجيل الدخول')),
                                if (widget.accountRole == null ||
                                    ['student', 'parent']
                                        .contains(widget.accountRole))
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => setState(() {
                                                register = !register;
                                                error = null;
                                              }),
                                      child: Text(register
                                          ? 'لديك حساب؟ تسجيل الدخول'
                                          : 'إنشاء حساب جديد')),
                                if (['partner', 'university', 'employee']
                                    .contains(widget.accountRole))
                                  const Padding(
                                      padding: EdgeInsets.only(top: 16),
                                      child: Text(
                                          'يُنشأ هذا الحساب بواسطة إدارة Study Birds.',
                                          textAlign: TextAlign.center)),
                                if (!register)
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      PasswordRecovery(
                                                          api: widget.api))),
                                      child: const Text('نسيت كلمة المرور؟')),
                              ])))))));
}

class ConnectedHome extends StatelessWidget {
  const ConnectedHome(
      {super.key,
      required this.api,
      required this.config,
      required this.refreshConfig});
  final StudyBirdsApi api;
  final Json config;
  final Future<void> Function() refreshConfig;
  static const paths = {
    'overview': '/students/overview',
    'universities': '/universities',
    'programs': '/programs',
    'countries': '/content/countries',
    'applications': '/students/applications',
    'documents': '/students/documents',
    'financials': '/students/financials',
    'arrival-services': '/students/arrival-services',
    'support-tickets': '/students/support-tickets',
    'notifications': '/students/notifications',
    'favorites': '/students/favorites',
    'knowledge-base': '/students/knowledge-base',
    'orientation-test': '/students/orientation-test',
    'profile': '/students/profile',
  };
  static const icons = {
    'overview': Icons.home_rounded,
    'universities': Icons.school,
    'programs': Icons.menu_book,
    'documents': Icons.folder_open,
    'financials': Icons.account_balance_wallet_outlined,
    'notifications': Icons.notifications_outlined,
    'profile': Icons.person_outline,
    'applications': Icons.assignment_outlined,
    'calendar': Icons.calendar_month,
    'support-tickets': Icons.chat_bubble_outline,
    'travel': Icons.flight,
    'accommodation': Icons.apartment,
    'favorites': Icons.favorite_border
  };
  @override
  Widget build(BuildContext context) {
    if (api.needsProfileSetup) {
      return StudentSetupWizard(api: api, onDone: api.finishProfileSetup);
    }
    if (['parent', 'university', 'employee'].contains(api.role)) {
      return WorkspaceHome(api: api, config: config);
    }
    final modules = (config['modules'] as List)
        .map((m) => Json.from(m))
        .where((m) =>
            m['enabled'] == true &&
            !['partner-', 'parent-', 'university-', 'employee-']
                .any((prefix) => m['key'].toString().startsWith(prefix)))
        .toList()
      ..sort((a, b) => (a['order'] as num).compareTo(b['order'] as num));
    final partner = api.role == 'partner';
    final partnerModules = [
      {'key': 'overview', 'title': 'لوحة الوكيل', 'path': '/partners/overview'},
      {'key': 'agent-students', 'title': 'طلابي', 'path': '/partners/students'},
      {
        'key': 'wallet',
        'title': 'المحفظة والعمولات',
        'path': '/partners/wallet'
      },
      {'key': 'referral', 'title': 'الإحالات', 'path': '/partners/referral'},
      {
        'key': 'marketing',
        'title': 'المواد التسويقية',
        'path': '/partners/marketing-assets'
      },
      {
        'key': 'verification',
        'title': 'توثيق الحساب',
        'path': '/partners/verification'
      },
      {'key': 'support-tickets', 'title': 'الدعم', 'path': '/partners/tickets'},
      {
        'key': 'notifications',
        'title': 'الإشعارات',
        'path': '/partners/notifications'
      },
      {
        'key': 'activity',
        'title': 'سجل النشاط',
        'path': '/partners/activity-log'
      },
      {
        'key': 'knowledge-base',
        'title': 'قاعدة المعرفة',
        'path': '/partners/knowledge-base'
      },
      {'key': 'profile', 'title': 'حسابي', 'path': '/partners/profile'},
      {
        'key': 'messages',
        'title': 'المحادثات',
        'path': '/mobile-workspace/messages'
      },
      {
        'key': 'settings',
        'title': 'الإعدادات والأمان',
        'path': '/mobile-workspace/preferences'
      },
    ];
    final visiblePartnerModules = partnerModules
        .where((module) => (config['modules'] as List).any((setting) =>
            setting['key'] ==
                (['messages', 'settings'].contains(module['key'])
                    ? module['key']
                    : 'partner-${module['key']}') &&
            setting['enabled'] == true))
        .map((module) {
      final setting = (config['modules'] as List).firstWhere((setting) =>
          setting['key'] ==
          (['messages', 'settings'].contains(module['key'])
              ? module['key']
              : 'partner-${module['key']}'));
      return {...module, 'title': setting['title'], 'order': setting['order']};
    }).toList()
      ..sort((a, b) => (a['order'] as num).compareTo(b['order'] as num));
    return _ConnectedHomeShell(
      api: api,
      config: config,
      modules: List<Json>.from(partner ? visiblePartnerModules : modules),
      refreshConfig: refreshConfig,
    );
  }
}

Future<void> openLink(BuildContext context, String value) async {
  if (value.isEmpty) return;
  final uri = Uri.tryParse(value);
  try {
    if (uri == null ||
        !['https', 'http', 'mailto', 'tel'].contains(uri.scheme) ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const ApiException('تعذر فتح الرابط');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackBar(content: Text(AppError.message(e))));
    }
  }
}

class InputSpec {
  final String key, label;
  final bool required, secret, multiline, boolean;
  final Map<String, String>? options;
  const InputSpec(this.key, this.label,
      {this.required = false,
      this.secret = false,
      this.multiline = false,
      this.boolean = false,
      this.options});
}

Future<bool?> openEditor(BuildContext context, StudyBirdsApi api, String title,
        String path, String method, List<InputSpec> fields,
        {Json initial = const {},
        Json extra = const {},
        bool upload = false,
        Json Function(Json)? transform}) =>
    Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ApiEditor(
            api: api,
            title: title,
            path: path,
            method: method,
            fields: fields,
            initial: initial,
            extra: extra,
            upload: upload,
            transform: transform)));

class ApiEditor extends StatefulWidget {
  const ApiEditor(
      {super.key,
      required this.api,
      required this.title,
      required this.path,
      required this.method,
      required this.fields,
      this.initial = const {},
      this.extra = const {},
      this.upload = false,
      this.transform});
  final StudyBirdsApi api;
  final String title, path, method;
  final List<InputSpec> fields;
  final Json initial, extra;
  final bool upload;
  final Json Function(Json)? transform;
  @override
  State<ApiEditor> createState() => _ApiEditorState();
}

class _ApiEditorState extends State<ApiEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  late final Json values;
  PlatformFile? file;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    values = {...widget.initial};
    controllers = {
      for (final f in widget.fields)
        f.key:
            TextEditingController(text: widget.initial[f.key]?.toString() ?? '')
    };
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (widget.upload && file == null) {
      setState(() => error = 'اختر ملفاً أولاً');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      Json body = {
        ...widget.extra,
        for (final f in widget.fields)
          f.key: f.boolean
              ? values[f.key] == true
              : f.options != null
                  ? values[f.key] ?? f.options!.keys.first
                  : f.secret
                      ? controllers[f.key]!.text
                      : controllers[f.key]!.text.trim()
      };
      if (widget.transform != null) body = widget.transform!(body);
      if (widget.upload) {
        await widget.api.upload(
            widget.path, file!, body.map((k, v) => MapEntry(k, v.toString())));
      } else {
        await widget.api.request(widget.method, widget.path, body: body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(AppSnackBar(content: Text('تم الحفظ بنجاح')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            for (final f in widget.fields)
              Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: f.boolean
                      ? SwitchListTile(
                          title: Text(f.label),
                          value: values[f.key] == true,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => values[f.key] = v))
                      : f.options != null
                          ? DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue:
                                  f.options!.containsKey(values[f.key])
                                      ? values[f.key]
                                      : f.options!.keys.first,
                              decoration: InputDecoration(labelText: f.label),
                              items: f.options!.entries
                                  .map((e) => DropdownMenuItem(
                                      value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => values[f.key] = v))
                          : SecureTextField(
                              enabled: !busy,
                              controller: controllers[f.key],
                              obscureText: f.secret,
                              requireStrong: f.key == 'newPassword',
                              maxLines: f.multiline ? 5 : 1,
                              decoration: InputDecoration(
                                  labelText: f.label,
                                  border: const OutlineInputBorder()),
                              validator: (v) => f.required && v!.trim().isEmpty
                                  ? 'هذا الحقل مطلوب'
                                  : f.key == 'newPassword' &&
                                          (v?.length ?? 0) < 8
                                      ? '8 أحرف على الأقل'
                                      : null)),
            if (widget.upload)
              OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                                withData: true,
                                type: FileType.custom,
                                allowedExtensions: [
                                  'pdf',
                                  'jpg',
                                  'jpeg',
                                  'png',
                                  'doc',
                                  'docx'
                                ]);
                            if (result != null && mounted) {
                              setState(() => file = result.files.single);
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => error = 'تعذر اختيار الملف: $e');
                            }
                          }
                        },
                  icon: const Icon(Icons.upload_file),
                  label: Text(file?.name ?? 'اختر الملف (حتى 5 ميجابايت)')),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: InlineNotice(error!, error: true)),
            FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ وإرسال')),
          ])));
}

class ResourceScreen extends StatefulWidget {
  const ResourceScreen(
      {super.key,
      required this.api,
      required this.title,
      required this.kind,
      required this.path});
  final StudyBirdsApi api;
  final String title, kind, path;
  @override
  State<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends State<ResourceScreen> {
  dynamic data;
  bool loading = true, busy = false;
  String? error;
  String query = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.request('GET', widget.path);
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> mutate(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(AppSnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editor(
      String title, String path, String method, List<InputSpec> fields,
      {Json initial = const {},
      Json extra = const {},
      bool upload = false,
      Json Function(Json)? transform}) async {
    final saved = await openEditor(
        context, widget.api, title, path, method, fields,
        initial: initial, extra: extra, upload: upload, transform: transform);
    if (saved == true && mounted) await load();
  }

  static const studentFields = [
    InputSpec('name', 'الاسم', required: true),
    InputSpec('email', 'البريد الإلكتروني', required: true),
    InputSpec('phone', 'الهاتف', required: true),
    InputSpec('passportNumber', 'رقم الجواز'),
    InputSpec('studyPreferences', 'التفضيلات الدراسية'),
    InputSpec('desiredUniversity', 'الجامعة المطلوبة'),
    InputSpec('desiredProgram', 'التخصص المطلوب'),
    InputSpec('notes', 'ملاحظات', multiline: true)
  ];
  Future<void> addOrEdit() async {
    final current = data is Map ? Json.from(data) : <String, dynamic>{};
    switch (widget.kind) {
      case 'documents':
        await editor(
            'رفع مستند',
            widget.path,
            'POST',
            const [
              InputSpec('type', 'نوع المستند', options: {
                'passport': 'جواز السفر',
                'biometric-photo': 'صورة شخصية',
                'latest-qualification': 'آخر مؤهل دراسي',
                'transcript': 'كشف الدرجات',
                'other': 'مستند آخر'
              })
            ],
            upload: true);
        break;
      case 'support-tickets':
        await editor('تذكرة دعم جديدة', widget.path, 'POST', const [
          InputSpec('subject', 'الموضوع', required: true),
          InputSpec('message', 'الرسالة', required: true, multiline: true)
        ], extra: {
          'category': 'other'
        });
        break;
      case 'profile':
        final partner = widget.api.role == 'partner';
        await editor('تعديل الملف الشخصي', widget.path, 'PUT', [
          const InputSpec('name', 'الاسم الكامل', required: true),
          const InputSpec('email', 'البريد الإلكتروني', required: true),
          const InputSpec('phone', 'الهاتف'),
          const InputSpec('nationality', 'الجنسية'),
          const InputSpec('dateOfBirth', 'تاريخ الميلاد YYYY-MM-DD'),
          const InputSpec('bio', 'نبذة', multiline: true),
          const InputSpec('address', 'العنوان'),
          if (partner) ...[
            const InputSpec('companyName', 'اسم الشركة', required: true),
            const InputSpec('location', 'الموقع', required: true),
            const InputSpec('website', 'الموقع الإلكتروني'),
            const InputSpec('taxId', 'الرقم الضريبي')
          ] else ...[
            const InputSpec('englishFullName', 'الاسم بالإنجليزية'),
            const InputSpec('passportNumber', 'رقم الجواز'),
            const InputSpec('currentEducation', 'المؤهل الحالي'),
            const InputSpec('currentEducationLevel', 'المستوى الدراسي',
                options: {
                  '': 'غير محدد',
                  'high-school': 'الثانوية',
                  'bachelor': 'بكالوريوس',
                  'master': 'ماجستير',
                  'phd': 'دكتوراه'
                }),
            const InputSpec('currentResidenceCountry', 'دولة الإقامة'),
            const InputSpec('gpa', 'المعدل'),
            const InputSpec('intake', 'موعد الدراسة'),
            const InputSpec(
                'targetCountriesText', 'الدول المفضلة (افصل بفاصلة)'),
            const InputSpec('englishExam', 'اختبار اللغة'),
            const InputSpec('englishScore', 'درجة اختبار اللغة'),
          ],
        ], initial: {
          ...current,
          'name': current['user']?['name'] ?? widget.api.user?['name'],
          'email': current['user']?['email'] ?? widget.api.user?['email'],
          'targetCountriesText':
              (current['targetCountries'] as List? ?? []).join('، '),
          'englishExam': current['englishTest']?['exam'] ?? '',
          'englishScore': current['englishTest']?['score'] ?? '',
        }, extra: {
          if (current['englishTest'] != null)
            'englishTest': current['englishTest'],
          if (current['targetCountries'] != null)
            'targetCountries': current['targetCountries']
        }, transform: (body) {
          if (body['dateOfBirth'] == '') body['dateOfBirth'] = null;
          if (!partner) {
            body['targetCountries'] = body
                .remove('targetCountriesText')
                .toString()
                .split(RegExp('[,،]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            body['englishTest'] = {
              'exam': body.remove('englishExam'),
              'score': body.remove('englishScore')
            };
          }
          return body;
        });
        if (mounted && data is Map && data['user'] is Map) {
          widget.api.user = Json.from(data['user']);
        }
        break;
      case 'arrival-services':
        await editor('طلب خدمات الوصول', widget.path, 'PUT', const [
          InputSpec('arrivalDate', 'تاريخ الوصول YYYY-MM-DD'),
          InputSpec('arrivalTime', 'وقت الوصول'),
          InputSpec('flightNumber', 'رقم الرحلة'),
          InputSpec('airport', 'المطار'),
          InputSpec('notes', 'ملاحظات', multiline: true),
          InputSpec('airportPickup', 'الاستقبال من المطار', boolean: true),
          InputSpec('studentHousing', 'سكن الطلاب', boolean: true),
          InputSpec('residencePermitSupport', 'دعم الإقامة', boolean: true),
          InputSpec('visaSupport', 'دعم التأشيرة', boolean: true)
        ], initial: {
          ...current,
          ...Json.from(current['services'] ?? {})
        }, transform: (body) {
          body['services'] = {
            for (final key in [
              'airportPickup',
              'studentHousing',
              'residencePermitSupport',
              'visaSupport'
            ])
              key: body.remove(key)
          };
          return body;
        });
        break;
      case 'orientation-test':
        final answers = Json.from(current['answers'] ?? {});
        for (final key in [
          'favoriteSubjects',
          'interestedFields',
          'avoidFields'
        ]) {
          if (answers[key] is List) {
            answers[key] = (answers[key] as List).join('، ');
          }
        }
        await editor(
            'التوجيه الدراسي',
            widget.path,
            'POST',
            const [
              InputSpec('favoriteSubjects', 'المواد المفضلة (افصل بفاصلة)'),
              InputSpec('interestedFields', 'التخصصات المفضلة (افصل بفاصلة)'),
              InputSpec('avoidFields', 'تخصصات لا ترغب بها (افصل بفاصلة)'),
              InputSpec('studyStyle', 'أسلوب الدراسة'),
              InputSpec('preferredLanguage', 'اللغة المفضلة'),
              InputSpec('preferredCountry', 'الدولة المفضلة'),
              InputSpec('approximateBudget', 'الميزانية التقريبية'),
              InputSpec('desiredDegreeLevel', 'الدرجة المطلوبة')
            ],
            initial: answers, transform: (body) {
          for (final key in [
            'favoriteSubjects',
            'interestedFields',
            'avoidFields'
          ]) {
            body[key] = body[key]
                .toString()
                .split(RegExp('[,،]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          return body;
        });
        break;
      case 'agent-students':
        await editor('إضافة طالب', widget.path, 'POST', studentFields);
        break;
      case 'wallet':
        await editor(
            'طلب سحب', '/partners/wallet/payout-requests', 'POST', const [
          InputSpec('amount', 'المبلغ', required: true),
          InputSpec('method', 'طريقة التحويل', options: {
            'bank-account': 'تحويل بنكي',
            'usdt': 'USDT',
            'wise': 'Wise',
            'other': 'أخرى'
          }),
          InputSpec('payoutDetails', 'تفاصيل التحويل', required: true),
          InputSpec('notes', 'ملاحظات')
        ]);
        break;
      case 'verification':
        await editor('رفع مستند التوثيق', '/partners/verification/documents',
            'POST', const [InputSpec('type', 'نوع المستند', required: true)],
            upload: true);
        break;
    }
  }

  Future<void> details(Json item, {String? kind}) async {
    final type = kind ?? widget.kind;
    if (type == 'notifications' &&
        item['_id'] != null &&
        item['isRead'] != true) {
      await mutate(() async {
        await widget.api.request('PATCH', '${widget.path}/${item['_id']}/read');
      });
    }
    if (!mounted) return;
    String? detailPath;
    if (type == 'programs' || type == 'universities') {
      detailPath = '/$type/${item['_id']}';
    }
    if (type == 'applications') detailPath = '/applications/${item['_id']}';
    final selected = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ResourceDetail(
            api: widget.api, item: item, kind: type, detailPath: detailPath)));
    if (selected == true && mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = [
      'documents',
      'support-tickets',
      'profile',
      'arrival-services',
      'orientation-test',
      'agent-students',
      'wallet',
      'verification'
    ].contains(widget.kind);
    final list = data is List
        ? data as List
        : data is Map && data['items'] is List
            ? data['items'] as List
            : null;
    final filtered = list
        ?.where((item) =>
            item.toString().toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          IconButton(
              tooltip: 'تحديث',
              onPressed: loading ? null : load,
              icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: canEdit && !loading && error == null
            ? FloatingActionButton.extended(
                onPressed: addOrEdit,
                icon: Icon(['profile', 'arrival-services', 'orientation-test']
                        .contains(widget.kind)
                    ? Icons.edit
                    : Icons.add),
                label: Text(['profile', 'arrival-services', 'orientation-test']
                        .contains(widget.kind)
                    ? 'تعديل'
                    : 'إضافة'))
            : null,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ErrorPanel(message: error!, retry: load)
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          if (list != null) ...[
                            if (widget.kind == 'favorites' && list.length >= 2)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.compare_arrows),
                                label: const Text(
                                    'مقارنة الجامعات والتخصصات المحفوظة'),
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => FavoritesComparison(
                                            favorites: list))),
                              ),
                            TextField(
                                decoration: const InputDecoration(
                                    labelText: 'بحث',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder()),
                                onChanged: (value) =>
                                    setState(() => query = value)),
                            const SizedBox(height: 16),
                            if (filtered!.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('لا توجد نتائج حالياً',
                                      textAlign: TextAlign.center)),
                            for (final raw in filtered)
                              if (raw is Map)
                                if (['universities', 'programs', 'countries']
                                    .contains(widget.kind))
                                  _CatalogCard(
                                      item: Json.from(raw),
                                      kind: widget.kind,
                                      onTap: () => details(Json.from(raw)))
                                else
                                  resourceCard(context, Json.from(raw),
                                      () => details(Json.from(raw))),
                          ] else if (data == null)
                            const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('لا توجد بيانات بعد',
                                    textAlign: TextAlign.center))
                          else if (widget.kind == 'financials' &&
                              data is Map) ...[
                            DataFields(value: data['summary']),
                            const SizedBox(height: 16),
                            const Text('الفواتير',
                                style: AppTextStyles.cardTitle),
                            for (final invoice in data['invoices'] ?? [])
                              resourceCard(
                                  context,
                                  Json.from(invoice),
                                  () => details(Json.from(invoice),
                                      kind: 'invoice')),
                            const SizedBox(height: 16),
                            const Text('إثباتات الدفع',
                                style: AppTextStyles.cardTitle),
                            for (final proof in data['paymentProofs'] ?? [])
                              resourceCard(
                                  context,
                                  Json.from(proof),
                                  () =>
                                      details(Json.from(proof), kind: 'proof')),
                          ] else if (widget.kind == 'profile' && data is Map)
                            _LiveProfile(
                                item: Json.from(data),
                                api: widget.api,
                                edit: addOrEdit)
                          else
                            DataFields(value: data),
                        ])));
  }
}

String itemTitle(Json item) {
  for (final key in [
    'title',
    'name',
    'subject',
    'fileName',
    'invoiceNumber',
    'description',
    'action'
  ]) {
    if (item[key] is String && item[key].toString().isNotEmpty) {
      return item[key];
    }
  }
  for (final key in ['program', 'university']) {
    if (item[key] is Map) return itemTitle(Json.from(item[key]));
  }
  return 'التفاصيل';
}

Widget resourceCard(BuildContext context, Json item, VoidCallback open) {
  final image = item['imageUrl'] ?? item['coverImage'] ?? item['logo'];
  final subtitle = [
    item['status'],
    item['date']?.toString().split('T').first,
    item['summary'],
    item['message']
  ]
      .where((v) => v != null && v.toString().isNotEmpty)
      .map((v) => displayValue(v))
      .join(' · ');
  return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: open,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (image is String && image.startsWith('https://'))
              AppNetworkImage(image,
                  height: 130,
                  fit: BoxFit.cover,
                  errorWidget: const SizedBox.shrink()),
            ListTile(
                title: Text(itemTitle(item),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: subtitle.isEmpty
                    ? null
                    : Text(subtitle,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_left)),
          ])));
}

class ResourceDetail extends StatefulWidget {
  const ResourceDetail(
      {super.key,
      required this.api,
      required this.item,
      required this.kind,
      this.detailPath});
  final StudyBirdsApi api;
  final Json item;
  final String kind;
  final String? detailPath;
  @override
  State<ResourceDetail> createState() => _ResourceDetailState();
}

class _ResourceDetailState extends State<ResourceDetail> {
  late Json item;
  bool loading = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    item = widget.item;
    if (widget.detailPath != null) load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.request('GET', widget.detailPath!);
      if (mounted) setState(() => item = Json.from(result));
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> perform(Future<void> Function() work) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> apply() async {
    await perform(() async {
      final docs =
          await widget.api.request('GET', '/students/documents') as List;
      if (!mounted) return;
      final selected = await Navigator.of(context).push<List<String>>(
          MaterialPageRoute(
              builder: (_) => ApplicationDocuments(documents: docs)));
      if (selected == null || !mounted) return;
      final saved = await openEditor(
          context,
          widget.api,
          'تقديم طلب القبول',
          '/applications',
          'POST',
          const [InputSpec('notes', 'ملاحظات للطلب', multiline: true)],
          extra: {'programId': item['_id'], 'documentIds': selected});
      if (saved == true && mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(itemTitle(item))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : widget.detailPath != null && error != null && item == widget.item
              ? ErrorPanel(message: error!, retry: load)
              : ListView(padding: const EdgeInsets.all(20), children: [
                  _DesignedDetails(
                      item: item, kind: widget.kind, api: widget.api),
                  const SizedBox(height: 24),
                  if (error != null)
                    InlineNotice(error!, error: true),
                  if (widget.kind == 'support-tickets' &&
                      item['status'] != 'closed')
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final saved = await openEditor(
                                    context,
                                    widget.api,
                                    'الرد على التذكرة',
                                    '/mobile/tickets/${item['_id']}/reply',
                                    'POST', const [
                                  InputSpec('message', 'الرسالة',
                                      required: true, multiline: true)
                                ]);
                                if (saved == true && context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                        child: const Text('إرسال رد')),
                  if (widget.kind == 'programs' && widget.api.role == 'student')
                    FilledButton(
                        onPressed: busy ? null : apply,
                        child: const Text('التقديم لهذا التخصص')),
                  if (['programs', 'universities'].contains(widget.kind) &&
                      widget.api.role == 'student')
                    OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => perform(() async {
                                  final program = widget.kind == 'programs';
                                  await widget.api.request(
                                      'POST', '/students/favorites/toggle',
                                      body: {
                                        'itemType':
                                            program ? 'program' : 'university',
                                        program ? 'programId' : 'universityId':
                                            item['_id']
                                      });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        AppSnackBar(
                                            content: Text('تم تحديث المفضلة')));
                                  }
                                }),
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('تبديل الحفظ في المفضلة')),
                  if (widget.kind == 'favorites')
                    OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => perform(() async {
                                  await widget.api.request('DELETE',
                                      '/students/favorites/${item['_id']}');
                                  if (context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                }),
                        child: const Text('إزالة من المفضلة')),
                  if (item['requestable'] == true)
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final saved = await openEditor(
                                    context,
                                    widget.api,
                                    'طلب ${itemTitle(item)}',
                                    '/mobile/requests',
                                    'POST', const [
                                  InputSpec(
                                      'message', 'تفاصيل الطلب والموعد المناسب',
                                      required: true, multiline: true)
                                ],
                                    extra: {
                                      'contentId': item['_id']
                                    });
                                if (saved == true && context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                        child: const Text('طلب الخدمة')),
                  if (widget.kind == 'invoice' &&
                      ['unpaid', 'rejected'].contains(item['status']))
                    FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final saved = await openEditor(
                                    context,
                                    widget.api,
                                    'رفع إثبات الدفع',
                                    '/students/financials/invoices/${item['_id']}/payment-proof',
                                    'POST',
                                    const [InputSpec('note', 'ملاحظة')],
                                    upload: true);
                                if (saved == true && context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('رفع إثبات الدفع')),
                  if (widget.kind == 'agent-students') ...[
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final saved = await openEditor(
                                    context,
                                    widget.api,
                                    'تعديل الطالب',
                                    '/partners/students/${item['_id']}',
                                    'PUT',
                                    _ResourceScreenState.studentFields,
                                    initial: item);
                                if (saved == true && context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                        child: const Text('تعديل الطالب')),
                    OutlinedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final saved = await openEditor(
                                    context,
                                    widget.api,
                                    'رفع مستند للطالب',
                                    '/partners/students/${item['_id']}/documents',
                                    'POST',
                                    const [
                                      InputSpec('label', 'اسم المستند',
                                          required: true)
                                    ],
                                    upload: true);
                                if (saved == true && context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                        child: const Text('رفع مستند')),
                  ],
                ]));
}

class ApplicationDocuments extends StatefulWidget {
  const ApplicationDocuments({super.key, required this.documents});
  final List documents;
  @override
  State<ApplicationDocuments> createState() => _ApplicationDocumentsState();
}

class _ApplicationDocumentsState extends State<ApplicationDocuments> {
  final selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final types = widget.documents
        .where((d) => selected.contains(d['_id']))
        .map((d) => d['type'])
        .toSet();
    final valid = ['passport', 'biometric-photo', 'latest-qualification']
        .every(types.contains);
    return Scaffold(
        appBar: AppBar(title: const Text('مستندات طلب القبول')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
              'اختر جواز السفر والصورة الشخصية وآخر مؤهل دراسي. يمكنك رفع الملفات أولاً من قسم مستنداتي.'),
          for (final doc in widget.documents)
            CheckboxListTile(
                title: Text(doc['fileName']),
                subtitle: Text(displayValue(doc['type'])),
                value: selected.contains(doc['_id']),
                onChanged: (value) => setState(() {
                      if (value == true) {
                        selected.add(doc['_id']);
                      } else {
                        selected.remove(doc['_id']);
                      }
                    })),
          FilledButton(
              onPressed: valid
                  ? () => Navigator.of(context).pop(selected.toList())
                  : null,
              child: const Text('متابعة')),
        ]));
  }
}

const labels = <String, String>{
  'overview': 'نبذة',
  'articleTitle': 'عن الجهة',
  'articleHeadings': 'العناوين',
  'articleBodies': 'التفاصيل',
  'visaNotes': 'معلومات التأشيرة',
  'averageTuition': 'متوسط الرسوم',
  'campusImages': 'صور الحرم الجامعي',
  'studentCount': 'عدد الطلاب',
  'specialtyCount': 'عدد التخصصات',
  'universityCount': 'عدد الجامعات',
  'invoiceUrl': 'ملف الفاتورة',
  'fileUrl': 'الملف',
  'resourceType': 'نوع المحتوى',
  'pendingBalance': 'الرصيد المعلق',
  'receivedBalance': 'الرصيد المستلم',
  'acceptedStudents': 'الطلاب المقبولون',
  'totalReceivedEarnings': 'الأرباح المستلمة',
  'pendingEarnings': 'الأرباح المعلقة',
  'recentStudents': 'آخر الطلاب',
  'recentPayouts': 'آخر طلبات السحب',
  'walletEntries': 'حركة المحفظة',
  'progress': 'رحلتي الدراسية',
  'currentStage': 'المرحلة الحالية',
  'stages': 'مراحل الرحلة',
  'titleAr': 'المرحلة',
  'descriptionAr': 'التفاصيل',
  'stats': 'ملخص الحساب',
  'currentApplications': 'الطلبات الحالية',
  'acceptedDocuments': 'المستندات المقبولة',
  'rejectedDocuments': 'المستندات المرفوضة',
  'pendingPayments': 'الدفعات المعلقة',
  'latestNotification': 'آخر إشعار',
  'recentDocuments': 'آخر المستندات',
  'exam': 'الاختبار',
  'score': 'النتيجة',
  'min': 'من',
  'max': 'إلى',
  'label': 'الاسم',
  'students': 'الطلاب',
  'totalStudents': 'عدد الطلاب',
  'newStudentsThisMonth': 'طلاب هذا الشهر',
  'totalCommission': 'إجمالي العمولات',
  'pendingCommission': 'العمولات المعلقة',
  'availableCommission': 'العمولات المتاحة',
  'paidCommission': 'العمولات المدفوعة',
  'wallet': 'المحفظة',
  'entries': 'المعاملات',
  'payouts': 'طلبات السحب',
  'amountUsd': 'المبلغ بالدولار',
  'method': 'طريقة التحويل',
  'payoutDetails': 'تفاصيل التحويل',
  'reviewNote': 'ملاحظات المراجعة',
  'referrals': 'الإحالات',
  'clicks': 'الزيارات',
  'registrations': 'التسجيلات',
  'totalClicks': 'عدد الزيارات',
  'totalRegistrations': 'عدد التسجيلات',
  'title': 'العنوان',
  'name': 'الاسم',
  'email': 'البريد الإلكتروني',
  'phone': 'الهاتف',
  'body': 'المحتوى',
  'description': 'الوصف',
  'summary': 'الملخص',
  'status': 'الحالة',
  'message': 'الرسالة',
  'subject': 'الموضوع',
  'adminNote': 'رد الإدارة',
  'notes': 'ملاحظات',
  'note': 'ملاحظة',
  'createdAt': 'تاريخ الإنشاء',
  'updatedAt': 'آخر تحديث',
  'date': 'التاريخ',
  'fileName': 'اسم الملف',
  'filePath': 'الملف',
  'url': 'الرابط',
  'linkUrl': 'الرابط',
  'imageUrl': 'الصورة',
  'coverImage': 'الصورة',
  'logo': 'الشعار',
  'heroImage': 'الصورة',
  'university': 'الجامعة',
  'program': 'التخصص',
  'country': 'الدولة',
  'city': 'المدينة',
  'tuition': 'الرسوم الدراسية',
  'currency': 'العملة',
  'duration': 'المدة',
  'language': 'اللغة',
  'degreeLevel': 'الدرجة الدراسية',
  'fieldOfStudy': 'مجال الدراسة',
  'fieldsOfStudy': 'مجالات الدراسة',
  'applicationDeadline': 'آخر موعد للتقديم',
  'intake': 'موعد الدراسة',
  'requirements': 'المتطلبات',
  'ranking': 'التصنيف',
  'tuitionRange': 'الرسوم',
  'student': 'الطالب',
  'user': 'الحساب',
  'profile': 'الملف الشخصي',
  'applicationStage': 'مرحلة الرحلة',
  'applications': 'الطلبات',
  'documents': 'المستندات',
  'notifications': 'الإشعارات',
  'statusTimeline': 'مراحل الطلب',
  'changedBy': 'بواسطة',
  'replies': 'الردود',
  'fromRole': 'المرسل',
  'attachment': 'المرفق',
  'isRead': 'تمت القراءة',
  'amount': 'المبلغ',
  'outstandingAmount': 'المبلغ المستحق',
  'pendingConfirmationAmount': 'بانتظار التأكيد',
  'paidAmount': 'المدفوع',
  'invoiceCount': 'عدد الفواتير',
  'invoiceNumber': 'رقم الفاتورة',
  'dueDate': 'تاريخ الاستحقاق',
  'invoice': 'الفاتورة',
  'paymentProofs': 'إثباتات الدفع',
  'arrivalDate': 'تاريخ الوصول',
  'arrivalTime': 'وقت الوصول',
  'flightNumber': 'رقم الرحلة',
  'airport': 'المطار',
  'services': 'الخدمات',
  'airportPickup': 'الاستقبال من المطار',
  'studentHousing': 'السكن',
  'residencePermitSupport': 'دعم الإقامة',
  'visaSupport': 'دعم التأشيرة',
  'nationality': 'الجنسية',
  'dateOfBirth': 'تاريخ الميلاد',
  'englishFullName': 'الاسم بالإنجليزية',
  'passportNumber': 'رقم الجواز',
  'currentEducation': 'المؤهل',
  'currentEducationLevel': 'المستوى الدراسي',
  'currentResidenceCountry': 'دولة الإقامة',
  'gpa': 'المعدل',
  'englishTest': 'اختبار اللغة',
  'targetCountries': 'الدول المستهدفة',
  'address': 'العنوان',
  'bio': 'نبذة',
  'companyName': 'الشركة',
  'location': 'الموقع',
  'website': 'الموقع الإلكتروني',
  'taxId': 'الرقم الضريبي',
  'verificationStatus': 'حالة التوثيق',
  'verificationReason': 'ملاحظات التوثيق',
  'answers': 'الإجابات',
  'recommendationSummary': 'توصية التوجيه',
  'suggestedFields': 'التخصصات المقترحة',
  'suggestedCountries': 'الدول المقترحة',
  'favoriteSubjects': 'المواد المفضلة',
  'interestedFields': 'التخصصات المفضلة',
  'studyStyle': 'أسلوب الدراسة',
  'preferredLanguage': 'اللغة المفضلة',
  'preferredCountry': 'الدولة المفضلة',
  'approximateBudget': 'الميزانية',
  'desiredDegreeLevel': 'الدرجة المطلوبة',
  'avoidFields': 'التخصصات المستبعدة',
  'type': 'النوع',
  'category': 'القسم',
  'content': 'المحتوى',
  'videoUrl': 'الفيديو',
  'externalUrl': 'الرابط',
  'role': 'نوع الحساب',
  'applicationStatus': 'حالة الطلب',
  'desiredUniversity': 'الجامعة المطلوبة',
  'desiredProgram': 'التخصص المطلوب',
  'studyPreferences': 'تفضيلات الدراسة',
  'balance': 'الرصيد',
  'availableBalance': 'الرصيد المتاح',
  'totalEarnings': 'إجمالي الأرباح',
  'transactions': 'المعاملات',
  'payoutRequests': 'طلبات السحب',
  'referralLink': 'رابط الإحالة',
  'referralCode': 'رمز الإحالة',
  'action': 'النشاط',
  'totalApplications': 'عدد الطلبات',
  'totalDocuments': 'عدد المستندات',
  'unreadNotifications': 'الإشعارات غير المقروءة',
  'recentApplications': 'آخر الطلبات',
  'recentNotifications': 'آخر الإشعارات',
};
String displayValue(dynamic value) {
  const translations = {
    'submitted': 'تم الإرسال',
    'pending': 'قيد المراجعة',
    'verified': 'تم التوثيق',
    'rejected': 'مرفوض',
    'unpaid': 'غير مدفوع',
    'paid': 'مدفوع',
    'pending-confirmation': 'بانتظار التأكيد',
    'in-progress': 'قيد التنفيذ',
    'completed': 'مكتمل',
    'cancelled': 'ملغي',
    'open': 'مفتوح',
    'closed': 'مغلق',
    'answered': 'تم الرد',
    'student': 'طالب',
    'partner': 'وكيل',
    'admin': 'الإدارة',
    'passport': 'جواز السفر',
    'biometric-photo': 'صورة شخصية',
    'latest-qualification': 'آخر مؤهل دراسي',
    'file-received': 'استلام الملف',
    'applying': 'التقديم',
    'preliminary-accepted': 'قبول مبدئي',
    'first-payment': 'الدفعة الأولى',
    'final-accepted': 'القبول النهائي',
    'travel-and-settlement': 'السفر والاستقرار'
  };
  if (value is bool) return value ? 'نعم' : 'لا';
  return translations[value.toString()] ??
      value
          .toString()
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&');
}

class DataFields extends StatelessWidget {
  const DataFields({super.key, required this.value, this.depth = 0});
  final dynamic value;
  final int depth;
  @override
  Widget build(BuildContext context) {
    if (value == null || depth > 7) return const SizedBox.shrink();
    if (value is List) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final item in value)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DataFields(value: item, depth: depth + 1)))
      ]);
    }
    if (value is Map) {
      const hidden = {
        '_id',
        '__v',
        'password',
        'googleId',
        'authProvider',
        'updatedBy',
        'published',
        'requestable',
        'order',
        'section',
        'slug',
        'mimeType',
        'size',
        'isActive',
        'agent',
        'itemType',
        'metadata'
      };
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final entry in (value as Map).entries)
          if (!hidden.contains(entry.key) &&
              labels.containsKey(entry.key) &&
              entry.value != null &&
              entry.value.toString().isNotEmpty &&
              !(entry.value is List && (entry.value as List).isEmpty))
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labels[entry.key] ?? entry.key.toString(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 4),
                      DataFields(value: entry.value, depth: depth + 1),
                    ])),
      ]);
    }
    final text = displayValue(value);
    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(text)) {
      return const SizedBox.shrink();
    }
    if (text.startsWith('https://') || text.startsWith('/uploads/')) {
      final url = text.startsWith('/')
          ? '${StudyBirdsApi.baseUrl.replaceFirst(RegExp(r'/api/?$'), '')}$text'
          : text;
      return TextButton.icon(
          onPressed: () => openLink(context, url),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('فتح الرابط أو الملف'));
    }
    return SelectableText(text);
  }
}

class FavoritesComparison extends StatefulWidget {
  const FavoritesComparison({super.key, required this.favorites});
  final List favorites;
  @override
  State<FavoritesComparison> createState() => _FavoritesComparisonState();
}

class _FavoritesComparisonState extends State<FavoritesComparison> {
  final selected = <String>{};
  String cell(Json favorite, String field) {
    final program = favorite['program'] is Map
        ? Json.from(favorite['program'])
        : <String, dynamic>{};
    final university = program['university'] is Map
        ? Json.from(program['university'])
        : favorite['university'] is Map
            ? Json.from(favorite['university'])
            : <String, dynamic>{};
    switch (field) {
      case 'university':
        return university['name']?.toString() ?? '—';
      case 'country':
        return university['country'] is Map
            ? university['country']['name']?.toString() ?? '—'
            : '—';
      case 'city':
        return university['city']?.toString() ?? '—';
      case 'language':
        return (program['language'] ?? university['language'])?.toString() ??
            '—';
      case 'tuition':
        if (program['tuition'] != null) return program['tuition'].toString();
        final range = university['tuitionRange'];
        return range is Map
            ? '${range['min'] ?? '—'} – ${range['max'] ?? '—'}'
            : '—';
      case 'duration':
        return program['duration']?.toString() ?? '—';
      case 'degreeLevel':
        return program['degreeLevel']?.toString() ?? '—';
      case 'applicationDeadline':
        return program['applicationDeadline']?.toString().split('T').first ??
            '—';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = widget.favorites
        .whereType<Map>()
        .where((item) => item['program'] is Map || item['university'] is Map)
        .map((item) => Json.from(item))
        .toList();
    final chosen =
        favorites.where((item) => selected.contains(item['_id'])).toList();
    return Scaffold(
        appBar: AppBar(title: const Text('المقارنة')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'اختر من عنصرين إلى أربعة للمقارنة. البيانات مأخوذة من الجامعات والتخصصات المحفوظة في حسابك.'),
          for (final item in favorites)
            CheckboxListTile(
                title: Text(itemTitle(item)),
                value: selected.contains(item['_id']),
                onChanged:
                    !selected.contains(item['_id']) && selected.length >= 4
                        ? null
                        : (value) => setState(() {
                              if (value == true) {
                                selected.add(item['_id']);
                              } else {
                                selected.remove(item['_id']);
                              }
                            })),
          if (chosen.length >= 2)
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('المعيار')),
                    for (final item in chosen)
                      DataColumn(
                          label: SizedBox(
                              width: 180,
                              child: Text(itemTitle(item), maxLines: 3)))
                  ],
                  rows: [
                    for (final key in [
                      'university',
                      'country',
                      'city',
                      'language',
                      'tuition',
                      'duration',
                      'degreeLevel',
                      'applicationDeadline'
                    ])
                      DataRow(cells: [
                        DataCell(Text(labels[key]!)),
                        for (final item in chosen)
                          DataCell(SizedBox(
                              width: 180, child: Text(cell(item, key))))
                      ])
                  ],
                )),
        ]));
  }
}
