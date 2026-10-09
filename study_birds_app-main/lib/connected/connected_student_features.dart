part of 'connected_app.dart';

class StudentSetupWizard extends StatefulWidget {
  const StudentSetupWizard(
      {super.key, required this.api, required this.onDone});
  final StudyBirdsApi api;
  final VoidCallback onDone;
  @override
  State<StudentSetupWizard> createState() => _StudentSetupWizardState();
}

class _StudentSetupWizardState extends State<StudentSetupWizard> {
  int step = 0;
  bool loading = true, busy = false;
  String? error;
  Json profile = {};
  final fields = <String, TextEditingController>{};
  static const steps = [
    {
      'phone': 'رقم الهاتف',
      'nationality': 'الجنسية',
      'dateOfBirth': 'تاريخ الميلاد YYYY-MM-DD',
      'englishFullName': 'الاسم بالإنجليزية',
      'passportNumber': 'رقم جواز السفر'
    },
    {
      'currentEducation': 'المؤهل الحالي',
      'gpa': 'المعدل الدراسي',
      'englishExam': 'اختبار اللغة',
      'englishScore': 'درجة اختبار اللغة'
    },
    {
      'targetCountriesText': 'الدول المفضلة (افصل بفاصلة)',
      'intake': 'موعد بدء الدراسة',
      'currentResidenceCountry': 'دولة الإقامة'
    },
  ];
  static const titles = [
    'البيانات الأساسية',
    'المعلومات الأكاديمية',
    'تفضيلات الدراسة'
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      profile =
          Json.from(await widget.api.request('GET', '/students/profile') ?? {});
      final initial = {
        ...profile,
        'englishExam': profile['englishTest']?['exam'],
        'englishScore': profile['englishTest']?['score'],
        'targetCountriesText':
            (profile['targetCountries'] as List? ?? []).join('، ')
      };
      for (final key in steps.expand((s) => s.keys)) {
        fields[key] = TextEditingController(
            text: key == 'dateOfBirth'
                ? initial[key]?.toString().split('T').first ?? ''
                : initial[key]?.toString() ?? '');
      }
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> next() async {
    if (step < 2) {
      setState(() => step++);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final values = {
        for (final entry in fields.entries) entry.key: entry.value.text.trim()
      };
      final birthday = values['dateOfBirth'];
      if (birthday != null &&
          birthday.isNotEmpty &&
          DateTime.tryParse(birthday) == null) {
        throw const ApiException('أدخل تاريخ ميلاد صحيحًا مثل 2005-01-20');
      }
      await widget.api.request('PUT', '/students/profile', body: {
        ...profile,
        ...values,
        'dateOfBirth': birthday == '' ? null : birthday,
        'targetCountries': values['targetCountriesText']!
            .split(RegExp('[,،]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'englishTest': {
          'exam': values['englishExam'],
          'score': values['englishScore']
        },
      });
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: Text(titles[step]), actions: [
            TextButton(
                onPressed: busy ? null : widget.onDone,
                child: const Text('إكمال لاحقًا',
                    style: TextStyle(color: Colors.white)))
          ]),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : fields.isEmpty
                  ? ErrorPanel(
                      message: error ?? 'تعذر تحميل الملف', retry: load)
                  : ListView(padding: const EdgeInsets.all(24), children: [
                      Text('الخطوة ${step + 1} من 3',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                          value: (step + 1) / 3,
                          color: AppColors.orange,
                          backgroundColor: AppColors.border),
                      const SizedBox(height: 24),
                      for (final field in steps[step].entries)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: TextField(
                                controller: fields[field.key],
                                decoration: InputDecoration(
                                    labelText: field.value,
                                    border: const OutlineInputBorder()))),
                      if (error != null)
                        InlineNotice(error!, error: true),
                      PrimaryButton(
                          label: busy
                              ? 'جارٍ الحفظ…'
                              : step == 2
                                  ? 'حفظ وبدء الرحلة'
                                  : 'التالي',
                          onPressed: busy ? null : next),
                      if (step > 0)
                        TextButton(
                            onPressed:
                                busy ? null : () => setState(() => step--),
                            child: const Text('السابق')),
                    ])));
}

class PasswordRecovery extends StatefulWidget {
  const PasswordRecovery({super.key, required this.api});
  final StudyBirdsApi api;
  @override
  State<PasswordRecovery> createState() => _PasswordRecoveryState();
}

class _PasswordRecoveryState extends State<PasswordRecovery> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController();
  bool sent = false, busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.request(
          'POST', '/mobile-security/reset/${sent ? 'confirm' : 'request'}',
          body: {
            'email': email.text.trim(),
            if (sent) 'code': code.text.trim(),
            if (sent) 'password': password.text,
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(AppSnackBar(content: Text(result['message'])));
      if (sent) {
        Navigator.of(context).pop();
      } else {
        setState(() => sent = true);
      }
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: const Text('استعادة كلمة المرور')),
          body: ListView(padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.lock_reset_rounded,
                size: 72, color: AppColors.navy),
            const SizedBox(height: 24),
            Text(
                sent
                    ? 'أدخل رمز البريد وكلمة المرور الجديدة'
                    : 'سنرسل رمز الاستعادة إلى بريدك المسجل',
                style: AppTextStyles.cardTitle),
            TextField(
                controller: email,
                enabled: !busy && !sent,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'البريد الإلكتروني')),
            if (sent) ...[
              VerificationCodeField(controller: code, enabled: !busy),
              SecureTextField(
                  controller: password,
                  requireStrong: true,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'كلمة المرور الجديدة (8 أحرف على الأقل)')),
            ],
            if (error != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: InlineNotice(error!, error: true)),
            const SizedBox(height: 24),
            PrimaryButton(
                label: busy
                    ? 'جارٍ التنفيذ…'
                    : sent
                        ? 'حفظ كلمة المرور'
                        : 'إرسال الرمز',
                onPressed: busy ? null : submit),
            if (sent)
              TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            sent = false;
                            code.clear();
                          }),
                  child: const Text('تغيير البريد أو إعادة إرسال الرمز')),
          ])));
}

class StudentFeaturePage extends StatefulWidget {
  const StudentFeaturePage(
      {super.key,
      required this.api,
      required this.feature,
      required this.title,
      this.config = const {}});
  final StudyBirdsApi api;
  final String feature, title;
  final Json config;
  @override
  State<StudentFeaturePage> createState() => _StudentFeaturePageState();
}

class _StudentFeaturePageState extends State<StudentFeaturePage> {
  dynamic data;
  bool loading = true, busy = false;
  String? error;
  String query = '', degree = '', language = '', budget = '';
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? day;
  static const routes = {
    'activity': 'activity',
    'calendar': 'calendar',
    'referral': 'referral',
    'student-wallet': 'wallet',
    'settings': 'preferences'
  };
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
      dynamic result;
      if (widget.feature == 'search') {
        final values = await Future.wait([
          widget.api.request('GET', '/universities'),
          widget.api.request('GET', '/programs'),
          widget.api.request('GET', '/content/countries')
        ]);
        result = [
          for (int i = 0; i < values.length; i++)
            for (final item
                in (values[i] is List ? values[i] : values[i]['items'] ?? []))
              {
                ...Json.from(item),
                '_kind': ['universities', 'programs', 'countries'][i]
              }
        ];
      } else if (widget.feature == 'program-finder') {
        result = await widget.api.request(
            'GET',
            '/mobile-workspace/program-finder?${Uri(queryParameters: {
                  'degree': degree,
                  'language': language,
                  'budget': budget
                }).query}');
      } else if (widget.feature == 'settings') {
        final values = await Future.wait([
          widget.api.request('GET', '/mobile-workspace/preferences'),
          widget.api.request('GET', '/mobile-security/sessions'),
          widget.api.request('GET', '/mobile-workspace/profile'),
          widget.api.request('GET', '/mobile-security/two-factor')
        ]);
        result = {
          'preferences': values[0],
          'sessions': values[1],
          'profile': values[2],
          'twoFactor': values[3],
        };
      } else if (routes.containsKey(widget.feature)) {
        result = await widget.api
            .request('GET', '/mobile-workspace/${routes[widget.feature]}');
      } else {
        result = <String, dynamic>{};
      }
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
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
      {Json initial = const {}}) async {
    final saved = await openEditor(
        context, widget.api, title, path, method, fields,
        initial: initial);
    if (saved == true && mounted) await load();
  }

  void resource(Json row, String kind) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ResourceDetail(
              api: widget.api,
              item: row,
              kind: kind,
              detailPath: ['universities', 'programs'].contains(kind)
                  ? '/$kind/${row['_id']}'
                  : null)));
  Widget row(String title, String subtitle, IconData icon,
          {VoidCallback? onTap}) =>
      AppCard(
          onTap: onTap,
          child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: AppColors.navy),
              title: Text(title, style: AppTextStyles.cardTitle),
              subtitle: Text(subtitle, style: AppTextStyles.caption),
              trailing: onTap == null ? null : const Icon(Icons.chevron_left)));
  List<Widget> content() {
    if (['search', 'program-finder'].contains(widget.feature)) {
      final list = (data as List).where(
          (e) => e.toString().toLowerCase().contains(query.toLowerCase()));
      return [
        if (widget.feature == 'program-finder')
          AppCard(
              child: Column(children: [
            DropdownButtonFormField<String>(
                initialValue: degree,
                decoration: const InputDecoration(labelText: 'الدرجة الدراسية'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('كل الدرجات')),
                  DropdownMenuItem(value: 'bachelor', child: Text('بكالوريوس')),
                  DropdownMenuItem(value: 'master', child: Text('ماجستير')),
                  DropdownMenuItem(value: 'phd', child: Text('دكتوراه'))
                ],
                onChanged: (v) => degree = v ?? ''),
            TextFormField(
                initialValue: budget,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'الحد الأقصى للرسوم'),
                onChanged: (v) => budget = v),
            TextFormField(
                initialValue: language,
                decoration: const InputDecoration(labelText: 'لغة الدراسة'),
                onChanged: (v) => language = v),
            const SizedBox(height: 16),
            PrimaryButton(label: 'عرض البرامج المناسبة', onPressed: load),
          ])),
        TextField(
            decoration: const InputDecoration(
                labelText: 'ابحث عن جامعة أو برنامج أو دولة',
                prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 16),
        Text('${list.length} نتيجة', style: AppTextStyles.caption),
        for (final item in list)
          _CatalogCard(
              item: Json.from(item),
              kind: item['_kind'] ?? 'programs',
              onTap: () =>
                  resource(Json.from(item), item['_kind'] ?? 'programs')),
        if (list.isEmpty)
          const Padding(
              padding: EdgeInsets.all(32), child: Text('لا توجد نتائج مطابقة')),
      ];
    }
    if (widget.feature == 'calendar') {
      final list = (data as List).where((e) {
        final date = DateTime.tryParse(e['date']?.toString() ?? '')?.toLocal();
        return date != null &&
            date.year == month.year &&
            date.month == month.month &&
            (day == null || date.day == day!.day);
      });
      final first = DateTime(month.year, month.month).weekday % 7;
      final count = DateTime(month.year, month.month + 1, 0).day;
      final dated = (data as List)
          .map((e) => DateTime.tryParse(e['date']?.toString() ?? '')?.toLocal())
          .whereType<DateTime>()
          .where((d) => d.year == month.year && d.month == month.month)
          .map((d) => d.day)
          .toSet();
      return [
        AppCard(
            child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
                onPressed: () => setState(() {
                      month = DateTime(month.year, month.month - 1);
                      day = null;
                    }),
                icon: const Icon(Icons.chevron_right)),
            Text('${month.year} / ${month.month}',
                style: AppTextStyles.cardTitle),
            IconButton(
                onPressed: () => setState(() {
                      month = DateTime(month.year, month.month + 1);
                      day = null;
                    }),
                icon: const Icon(Icons.chevron_left))
          ]),
          Row(children: [
            for (final name in ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'])
              Expanded(child: Center(child: Text(name)))
          ]),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: first + count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7),
              itemBuilder: (_, i) {
                if (i < first) return const SizedBox.shrink();
                final n = i - first + 1;
                return InkWell(
                    onTap: () => setState(() => day = day?.day == n
                        ? null
                        : DateTime(month.year, month.month, n)),
                    child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: day?.day == n ? AppColors.orange : null,
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$n'),
                              if (dated.contains(n))
                                const Icon(Icons.circle,
                                    size: 5, color: AppColors.navy)
                            ])));
              }),
        ])),
        const Text('المواعيد المهمة', style: AppTextStyles.sectionLabel),
        for (final item in list)
          row(
              item['title'] ?? '',
              '${item['date'].toString().split('T').first}\n${item['description'] ?? ''}',
              Icons.event_available),
        if (list.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا توجد مواعيد في الفترة المحددة')),
      ];
    }
    if (widget.feature == 'activity') {
      return [
        for (final item in data as List)
          row(
              displayValue(item['title']),
              '${item['description'] ?? ''}\n${item['date'] ?? ''}',
              Icons.history),
        if ((data as List).isEmpty) const Text('لا توجد أنشطة مسجلة بعد'),
      ];
    }
    if (widget.feature == 'student-wallet') {
      return [
        _WorkspaceHero(
            name: '${data['balance']} ${data['currency']}',
            subtitle: 'رصيد محفظتك'),
        const SizedBox(height: 16),
        const Text('حركات الرصيد', style: AppTextStyles.sectionLabel),
        for (final item in data['entries'])
          row(
              item['description'],
              '${item['amount']} ${data['currency']}\n${item['createdAt'].toString().split('T').first}',
              Icons.account_balance_wallet_outlined),
        if ((data['entries'] as List).isEmpty)
          const Text('لا توجد حركات رصيد مسجلة'),
      ];
    }
    if (widget.feature == 'referral') {
      return [
        _WorkspaceHero(
            name: data['code'] ?? '', subtitle: 'رمز الإحالة الخاص بك'),
        const SizedBox(height: 16),
        _workspaceStat('الحسابات المسجلة برمزك', data['referrals']),
        const SizedBox(height: 16),
        PrimaryButton(
            label: 'نسخ رمز الإحالة',
            icon: Icons.copy,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data['code']));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    AppSnackBar(content: Text('تم نسخ الرمز')));
              }
            }),
        if (data['linked'] != true)
          TextButton(
              onPressed: () => editor(
                  'إضافة رمز إحالة',
                  '/mobile-workspace/referral',
                  'POST',
                  const [InputSpec('code', 'رمز صاحب الدعوة', required: true)]),
              child: const Text('لديك رمز دعوة؟')),
      ];
    }
    if (widget.feature == 'settings') {
      final pref = Json.from(data['preferences']);
      final profile = Json.from(data['profile']);
      return [
        row('الملف الشخصي', profile['name'] ?? '', Icons.person_outline),
        row(
            'تأكيد البريد الإلكتروني',
            '${profile['email']}\n${profile['emailVerified'] == true ? 'البريد مؤكد' : 'لم يتم التأكيد'}',
            Icons.mark_email_read_outlined,
            onTap: profile['emailVerified'] == true || busy
                ? null
                : () => action(() async {
                      await widget.api
                          .request('POST', '/mobile-security/email/request');
                      if (!mounted) return;
                      await editor('تأكيد البريد الإلكتروني',
                          '/mobile-security/email/confirm', 'POST', const [
                        InputSpec('code', 'رمز البريد المكون من 6 أرقام',
                            required: true)
                      ]);
                    })),
        row('تغيير كلمة المرور', 'حدّث كلمة المرور لحماية حسابك',
            Icons.lock_reset,
            onTap: () => editor('تغيير كلمة المرور', '/auth/change-password',
                    'POST', const [
                  InputSpec('currentPassword', 'كلمة المرور الحالية',
                      secret: true, required: true),
                  InputSpec('newPassword', 'كلمة المرور الجديدة',
                      secret: true, required: true)
                ])),
        if (widget.api.role == 'student') ...[
          row(
              'ولي الأمر وجهة اتصال الطوارئ',
              pref['guardianName'] ?? 'أكمل معلومات التواصل',
              Icons.family_restroom,
              onTap: () => editor(
                  'معلومات التواصل',
                  '/mobile-workspace/preferences',
                  'PUT',
                  const [
                    InputSpec('guardianName', 'اسم ولي الأمر'),
                    InputSpec('guardianPhone', 'هاتف ولي الأمر'),
                    InputSpec('emergencyName', 'اسم جهة اتصال الطوارئ'),
                    InputSpec('emergencyPhone', 'هاتف الطوارئ')
                  ],
                  initial: pref)),
          row(
              'التفضيلات المالية ولغة الدراسة',
              '${pref['budget'] ?? ''} ${pref['preferredLanguage'] ?? ''}',
              Icons.tune,
              onTap: () => editor(
                  'تفضيلات الدراسة',
                  '/mobile-workspace/preferences',
                  'PUT',
                  const [
                    InputSpec('budget', 'الميزانية'),
                    InputSpec('preferredLanguage', 'لغة الدراسة المفضلة')
                  ],
                  initial: pref)),
        ],
        row(
            'التحقق بخطوتين',
            data['twoFactor']?['enabled'] == true
                ? 'مفعّل — رمز بريد عند الدخول'
                : 'أضف رمز البريد إلى تسجيل الدخول',
            Icons.shield_outlined,
            onTap: busy
                ? null
                : () => action(() async {
                      await widget.api.request(
                          'POST', '/mobile-security/two-factor/request');
                      if (!mounted) return;
                      final enable = data['twoFactor']?['enabled'] != true;
                      await openEditor(
                          context,
                          widget.api,
                          enable
                              ? 'تفعيل التحقق بخطوتين'
                              : 'إيقاف التحقق بخطوتين',
                          '/mobile-security/two-factor/confirm',
                          'POST',
                          const [
                            InputSpec('code', 'رمز تأكيد البريد',
                                required: true)
                          ],
                          extra: {
                            'enabled': enable
                          });
                    })),
        const Text('الجلسات النشطة', style: AppTextStyles.sectionLabel),
        for (final session in data['sessions'])
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text(
                    session['current'] == true
                        ? 'هذا الجهاز'
                        : session['device'] ?? 'جهاز آخر',
                    style: AppTextStyles.cardTitle),
                Text(
                    session['lastSeen']
                            ?.toString()
                            .replaceAll('T', ' ')
                            .split('.')
                            .first ??
                        '',
                    style: AppTextStyles.caption),
                TextButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                              await widget.api.request('DELETE',
                                  '/mobile-security/sessions/${session['_id']}');
                              if (session['current'] == true) {
                                await widget.api.logout();
                              }
                            }),
                    child: Text(session['current'] == true
                        ? 'تسجيل الخروج من هذا الجهاز'
                        : 'إنهاء الجلسة')),
              ])),
      ];
    }
    if (widget.feature == 'bird-ai') {
      return [
        const Icon(Icons.auto_awesome, size: 64, color: AppColors.orange),
        const SizedBox(height: 24),
        const Text('Bird AI',
            style: AppTextStyles.screenTitle, textAlign: TextAlign.center),
        const Text(
            'سيتم تفعيل المساعد بعد إعداد خدمة الذكاء الاصطناعي. يمكنك الآن التواصل مع مستشارك.',
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'تواصل مع الفريق',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WorkspacePage(
                    api: widget.api, title: 'فريقي', route: 'contacts')))),
      ];
    }
    return [
      const Icon(Icons.support_agent_rounded,
          size: 72, color: AppColors.orange),
      const SizedBox(height: 24),
      const Text('فريق Study Birds معك', style: AppTextStyles.screenTitle),
      if ((widget.config['supportPhone'] ?? '').toString().isNotEmpty)
        row('الاتصال بالدعم', widget.config['supportPhone'], Icons.phone,
            onTap: () =>
                openLink(context, 'tel:${widget.config['supportPhone']}')),
      if ((widget.config['supportEmail'] ?? '').toString().isNotEmpty)
        row('بريد الدعم', widget.config['supportEmail'], Icons.email_outlined,
            onTap: () =>
                openLink(context, 'mailto:${widget.config['supportEmail']}')),
      row('مراسلة المستشار', 'أرسل تفاصيل طلب المساعدة',
          Icons.chat_bubble_outline,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => WorkspacePage(
                  api: widget.api, title: 'فريقي', route: 'contacts')))),
    ];
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: Text(widget.title), actions: [
            IconButton(
                onPressed: loading ? null : load,
                icon: const Icon(Icons.refresh))
          ]),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? ErrorPanel(message: error!, retry: load)
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.all(20),
                          children: content()))));
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard(
      {required this.item, required this.kind, required this.onTap});
  final Json item;
  final String kind;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final picture = item['coverImage'] ?? item['heroImage'] ?? item['logo'];
    final university = item['university'];
    final country =
        item['country'] ?? (university is Map ? university['country'] : null);
    return AppCard(
        onTap: onTap,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (picture is String && picture.startsWith('https://')) ...[
            ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppNetworkImage(picture,
                    height: 130,
                    fit: BoxFit.cover,
                    errorWidget: const SizedBox.shrink())),
            const SizedBox(height: 12)
          ],
          Row(children: [
            Icon(kind == 'countries' ? Icons.public : Icons.school_outlined,
                color: AppColors.navy),
            const SizedBox(width: 10),
            Expanded(
                child: Text(itemTitle(item), style: AppTextStyles.cardTitle)),
            const Icon(Icons.chevron_left)
          ]),
          if (university is Map)
            Text(university['name'] ?? '', style: AppTextStyles.caption),
          if (country is Map)
            Text(country['name'] ?? '', style: AppTextStyles.caption),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 6, children: [
            for (final key in ['degreeLevel', 'language', 'duration'])
              if (item[key] != null)
                Chip(
                    label: Text(displayValue(item[key]),
                        style: AppTextStyles.caption),
                    side: BorderSide.none,
                    backgroundColor: AppColors.background),
            if (item['tuition'] != null)
              Chip(
                  label: Text('الرسوم: ${item['tuition']}',
                      style: AppTextStyles.caption),
                  side: BorderSide.none,
                  backgroundColor: AppColors.orange.withValues(alpha: .08)),
          ]),
        ]));
  }
}

class _LiveProfile extends StatelessWidget {
  const _LiveProfile(
      {required this.item, required this.api, required this.edit});
  final Json item;
  final StudyBirdsApi api;
  final VoidCallback edit;
  @override
  Widget build(BuildContext context) {
    const groups = {
      'المعلومات الشخصية': ['phone', 'nationality', 'dateOfBirth', 'address'],
      'المعلومات الأكاديمية': [
        'currentEducation',
        'currentEducationLevel',
        'gpa',
        'englishTest'
      ],
      'جواز السفر ومعلومات السفر': [
        'englishFullName',
        'passportNumber',
        'currentResidenceCountry'
      ],
      'تفضيلات الدراسة': ['targetCountries', 'intake'],
    };
    final fields = groups.values.expand((v) => v).toList();
    bool filled(String key) =>
        item[key] != null &&
        item[key].toString().isNotEmpty &&
        item[key].toString() != '[]' &&
        item[key].toString() != '{}';
    final completed = fields.where(filled).length / fields.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _WorkspaceHero(
          name: item['user']?['name'] ?? api.user?['name'] ?? '',
          subtitle: item['user']?['email'] ?? api.user?['email'] ?? ''),
      const SizedBox(height: 16),
      AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('اكتمال الملف الشخصي ${(completed * 100).round()}%',
            style: AppTextStyles.cardTitle),
        const SizedBox(height: 12),
        LinearProgressIndicator(
            value: completed,
            color: AppColors.orange,
            backgroundColor: AppColors.border),
      ])),
      for (final group in groups.entries)
        AppCard(
            onTap: edit,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(group.key, style: AppTextStyles.cardTitle)),
                    const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.navy)
                  ]),
                  const SizedBox(height: 12),
                  if (!group.value.any(filled))
                    const Text('أكمل هذه المعلومات',
                        style: AppTextStyles.caption)
                  else
                    DataFields(
                        value: {for (final key in group.value) key: item[key]}),
                ])),
      AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => StudentFeaturePage(
                  api: api, feature: 'settings', title: 'الإعدادات والأمان'))),
          child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.family_restroom),
              title: Text('ولي الأمر والطوارئ وتفضيلات الحساب'),
              trailing: Icon(Icons.chevron_left))),
    ]);
  }
}

class _DesignedDetails extends StatelessWidget {
  const _DesignedDetails(
      {required this.item, required this.kind, required this.api});
  final Json item;
  final String kind;
  final StudyBirdsApi api;
  @override
  Widget build(BuildContext context) {
    final catalog = ['universities', 'programs', 'countries'].contains(kind);
    final image = item['imageUrl'] ?? item['coverImage'] ?? item['heroImage'];
    final isContent = item['section'] != null && item['body'] != null;
    final contentKeys = {
      'title',
      'name',
      'body',
      'description',
      'summary',
      'imageUrl',
      'coverImage',
      'heroImage',
      'statusTimeline',
      'documents'
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (image is String && image.startsWith('https://')) ...[
        ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AppNetworkImage(image,
                height: 200,
                fit: BoxFit.cover,
                errorWidget: const SizedBox.shrink())),
        const SizedBox(height: 16)
      ],
      _WorkspaceHero(
          name: itemTitle(item),
          subtitle: item['status'] != null
              ? displayValue(item['status'])
              : catalog
                  ? 'اكتشف فرصتك الدراسية'
                  : ''),
      const SizedBox(height: 16),
      for (final key in ['summary', 'body', 'description'])
        if (item[key] is String && item[key].toString().isNotEmpty)
          AppCard(
              child: Text(displayValue(item[key]), style: AppTextStyles.body)),
      if (!isContent)
        AppCard(
            child: DataFields(value: {
          for (final entry in item.entries)
            if (!contentKeys.contains(entry.key)) entry.key: entry.value
        })),
      if (isContent)
        DataFields(value: {'date': item['date'], 'linkUrl': item['linkUrl']}),
      if (item['statusTimeline'] is List) ...[
        const Text('مراحل الطلب', style: AppTextStyles.sectionLabel),
        for (final stage in item['statusTimeline'])
          AppCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline,
                      color: AppColors.orange),
                  title: Text(displayValue(stage['status'])),
                  subtitle: Text(
                      '${stage['note'] ?? ''}\n${stage['changedAt']?.toString().split('T').first ?? ''}'))),
      ],
      if (item['documents'] is List) ...[
        const Text('المستندات', style: AppTextStyles.sectionLabel),
        for (final doc in item['documents'])
          if (doc is Map) AppCard(child: DataFields(value: doc)),
      ],
      if (kind == 'applications')
        OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WorkspacePage(
                    api: api,
                    title: 'المراسلات وخطابات القبول',
                    route: 'applications/${item['_id']}'))),
            icon: const Icon(Icons.mail_outline),
            label: const Text('طلبات الجامعة وخطابات القبول')),
      if (kind == 'universities')
        OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ResourceScreen(
                    api: api,
                    title: 'برامج الجامعة',
                    kind: 'programs',
                    path: '/programs?university=${item['_id']}'))),
            icon: const Icon(Icons.school_outlined),
            label: const Text('برامج الجامعة')),
      if (kind == 'countries')
        OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ResourceScreen(
                    api: api,
                    title: 'جامعات الدولة',
                    kind: 'universities',
                    path: '/universities?country=${item['_id']}'))),
            icon: const Icon(Icons.public),
            label: const Text('جامعات الدولة')),
    ]);
  }
}
