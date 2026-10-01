part of 'connected_app.dart';

String accountRoleLabel(String role) =>
    const {
      'student': 'طالب',
      'partner': 'وكيل',
      'parent': 'ولي أمر',
      'university': 'جامعة',
      'employee': 'موظف',
      'admin': 'الإدارة',
    }[role] ??
    role;

class WorkspaceHome extends StatefulWidget {
  const WorkspaceHome({super.key, required this.api, required this.config});
  final StudyBirdsApi api;
  final Json config;
  @override
  State<WorkspaceHome> createState() => _WorkspaceHomeState();
}

class _WorkspaceHomeState extends State<WorkspaceHome> {
  int tab = 0;
  late Future<dynamic> overview;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    overview = widget.api.request('GET', '/mobile-workspace/overview');
  }

  void open(String title, String route) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              WorkspacePage(api: widget.api, title: title, route: route)));
  bool enabled(String route) {
    final key = ['students', 'applications', 'tasks', 'manager'].contains(route)
        ? '${widget.api.role}-$route'
        : route;
    final settings =
        (widget.config['modules'] as List? ?? []).where((m) => m['key'] == key);
    return settings.isEmpty || settings.first['enabled'] == true;
  }

  Widget tile(String label, String route, IconData icon) => !enabled(route)
      ? const SizedBox.shrink()
      : AppCard(
          onTap: () => open(label, route),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(icon, color: AppColors.navy)),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.cardTitle)),
            const Icon(Icons.chevron_left)
          ]));
  @override
  Widget build(BuildContext context) {
    final parent = widget.api.role == 'parent';
    final university = widget.api.role == 'university';
    final title = [
      'الرئيسية',
      university
          ? 'طلبات القبول'
          : parent
              ? 'أبنائي'
              : 'طلابي',
      'المحادثات',
      'حسابي'
    ][tab];
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            appBar: AppBar(title: Text(title), actions: [
              IconButton(
                  onPressed: () => open('الإشعارات', 'notifications'),
                  icon: const Icon(Icons.notifications_outlined))
            ]),
            body: (tab == 1 &&
                        !enabled(university ? 'applications' : 'students')) ||
                    (tab == 2 && !enabled('messages'))
                ? const Center(child: Text('هذا القسم غير متاح حالياً'))
                : tab == 1
                    ? WorkspacePage(
                        api: widget.api,
                        title: title,
                        route: university ? 'applications' : 'students',
                        embedded: true)
                    : tab == 2
                        ? WorkspacePage(
                            api: widget.api,
                            title: title,
                            route: 'messages',
                            embedded: true)
                        : tab == 3
                            ? ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                    _WorkspaceHero(
                                        name: widget.api.user?['name'] ?? '',
                                        subtitle:
                                            accountRoleLabel(widget.api.role)),
                                    const SizedBox(height: 20),
                                    tile('الملف الشخصي', 'profile',
                                        Icons.person_outline),
                                    AppCard(
                                        onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    StudentFeaturePage(
                                                        api: widget.api,
                                                        feature: 'settings',
                                                        title:
                                                            'الإعدادات والأمان',
                                                        config:
                                                            widget.config))),
                                        child: const ListTile(
                                            leading: Icon(Icons.security),
                                            title: Text('الإعدادات والأمان'))),
                                    tile('فريقي', 'contacts',
                                        Icons.groups_outlined),
                                    AppCard(
                                        onTap: () => openEditor(
                                                context,
                                                widget.api,
                                                'تغيير كلمة المرور',
                                                '/auth/change-password',
                                                'POST', const [
                                              InputSpec('currentPassword',
                                                  'كلمة المرور الحالية',
                                                  secret: true, required: true),
                                              InputSpec('newPassword',
                                                  'كلمة المرور الجديدة',
                                                  secret: true, required: true)
                                            ]),
                                        child: const ListTile(
                                            leading: Icon(Icons.lock_outline),
                                            title: Text('تغيير كلمة المرور'))),
                                    TextButton.icon(
                                        onPressed: widget.api.logout,
                                        icon: const Icon(Icons.logout),
                                        label: const Text(
                                            'تسجيل الخروج وتغيير نوع الحساب')),
                                  ])
                            : RefreshIndicator(
                                onRefresh: () async {
                                  setState(reload);
                                  await overview;
                                },
                                child: FutureBuilder<dynamic>(
                                    future: overview,
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) {
                                        return ErrorPanel(
                                            message: snapshot.error.toString(),
                                            retry: () async {
                                              setState(reload);
                                              await overview;
                                            });
                                      }
                                      if (!snapshot.hasData) {
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      }
                                      final data = snapshot.data as Map;
                                      return ListView(
                                          padding: const EdgeInsets.all(20),
                                          children: [
                                            _WorkspaceHero(
                                                name: 'مرحباً ${data['name']}',
                                                subtitle:
                                                    'لوحة ${accountRoleLabel(widget.api.role)}'),
                                            const SizedBox(height: 20),
                                            Row(children: [
                                              Expanded(
                                                  child: _workspaceStat(
                                                      university
                                                          ? 'طلبات القبول'
                                                          : 'الطلاب',
                                                      data[university
                                                          ? 'applications'
                                                          : 'students'])),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: _workspaceStat(
                                                      'رسائل جديدة',
                                                      data['unreadMessages']))
                                            ]),
                                            const SizedBox(height: 12),
                                            if (!university)
                                              tile(
                                                  parent
                                                      ? 'متابعة الأبناء'
                                                      : 'قائمة الطلاب',
                                                  'students',
                                                  Icons.groups_rounded),
                                            tile('طلبات القبول', 'applications',
                                                Icons.assignment_outlined),
                                            if (widget.api.role == 'employee')
                                              tile('مهامي', 'tasks',
                                                  Icons.task_alt_rounded),
                                            if (data['manager'] == true)
                                              tile('نظرة المدير', 'manager',
                                                  Icons.analytics_outlined),
                                            tile('صندوق الرسائل', 'messages',
                                                Icons.chat_bubble_outline),
                                            AppCard(
                                                onTap: () => Navigator.of(
                                                        context)
                                                    .push(MaterialPageRoute(
                                                        builder: (_) =>
                                                            StudentFeaturePage(
                                                                api: widget.api,
                                                                feature:
                                                                    'calendar',
                                                                title:
                                                                    'المواعيد المهمة',
                                                                config: widget
                                                                    .config))),
                                                child: const ListTile(
                                                    leading: Icon(
                                                        Icons.calendar_month),
                                                    title: Text(
                                                        'المواعيد المهمة'))),
                                            tile(
                                                parent
                                                    ? 'التواصل مع المستشار'
                                                    : 'فريقي',
                                                'contacts',
                                                Icons.support_agent_rounded),
                                          ]);
                                    })),
            bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: tab,
                selectedItemColor: AppColors.navy,
                onTap: (v) => setState(() {
                      tab = v;
                      if (v == 0) reload();
                    }),
                items: [
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                  BottomNavigationBarItem(
                      icon: const Icon(Icons.school_outlined),
                      label: university
                          ? 'الطلبات'
                          : parent
                              ? 'أبنائي'
                              : 'طلابي'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.chat_bubble_outline),
                      label: 'المحادثات'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline), label: 'حسابي'),
                ])));
  }
}

Widget _workspaceStat(String label, dynamic value) => AppCard(
    margin: EdgeInsets.zero,
    child: Column(children: [
      Text('${value ?? 0}', style: AppTextStyles.screenTitle),
      Text(label, style: AppTextStyles.caption)
    ]));

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.name, required this.subtitle});
  final String name, subtitle;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.navy, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(name,
            style: AppTextStyles.screenTitle.copyWith(color: Colors.white)),
        const SizedBox(height: 10),
        Text(subtitle,
            style: AppTextStyles.body.copyWith(color: Colors.white70))
      ]));
}

/// Shared live pages with explicit actions and server-enforced record scope.
class WorkspacePage extends StatefulWidget {
  const WorkspacePage(
      {super.key,
      required this.api,
      required this.title,
      required this.route,
      this.embedded = false});
  final StudyBirdsApi api;
  final String title, route;
  final bool embedded;
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  dynamic data;
  String? error;
  bool loading = true;
  String query = '';
  String get path => '/mobile-workspace/${widget.route}';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant WorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      query = '';
      load();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.request('GET', path);
      if (widget.route == 'messages' && result is List) {
        final unread = result
            .where((m) =>
                m['recipient'] is Map &&
                m['recipient']['_id'] == widget.api.user?['_id'] &&
                m['readAt'] == null)
            .map((m) => m['_id'])
            .toList();
        if (unread.isNotEmpty) {
          await widget.api.request('POST', '/mobile-workspace/messages/read',
              body: {'ids': unread});
        }
      }
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit(
      String title, String endpoint, String method, List<InputSpec> fields,
      {Json extra = const {},
      Json initial = const {},
      bool upload = false}) async {
    final saved = await openEditor(
        context, widget.api, title, endpoint, method, fields,
        extra: extra, initial: initial, upload: upload);
    if (saved == true && mounted) await load();
  }

  void open(String title, String route) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              WorkspacePage(api: widget.api, title: title, route: route)));
  Future<void> compose({Json? recipient}) async {
    try {
      final raw =
          await widget.api.request('GET', '/mobile-workspace/contacts') as List;
      if (!mounted) return;
      if (raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لم يتم تعيين فريق لهذا الحساب بعد.')));
        return;
      }
      await edit('رسالة جديدة', '/mobile-workspace/messages', 'POST', [
        InputSpec('recipient', 'إلى', required: true, options: {
          for (final user in raw)
            user['_id'].toString(): user['name'].toString()
        }),
        const InputSpec('body', 'الرسالة', required: true, multiline: true),
      ], initial: {
        if (recipient != null) 'recipient': recipient['_id']
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget entry(String title, String subtitle, IconData icon,
          {VoidCallback? onTap, Widget? trailing}) =>
      AppCard(
          onTap: onTap,
          child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: AppColors.navy),
              title: Text(title, style: AppTextStyles.cardTitle),
              subtitle: Text(subtitle, style: AppTextStyles.caption),
              trailing: trailing ??
                  (onTap == null ? null : const Icon(Icons.chevron_left))));
  String label(dynamic v) => v is Map
      ? (v['name'] ?? v['title'] ?? '').toString()
      : (v ?? '').toString();
  Widget application(Json row) => entry(
      label(row['program']),
      '${label(row['student'])} · ${label(row['university'])}\n${displayValue(row['status'])}',
      Icons.description_outlined,
      onTap: () => open('مراجعة الطلب', 'applications/${row['_id']}'));
  List<Widget> items() {
    if (data is List) {
      final list = (data as List)
          .whereType<Map>()
          .map(Json.from)
          .where((row) =>
              row.toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
      return [
        TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'بحث'),
            onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const Padding(
              padding: EdgeInsets.all(32),
              child:
                  Text('لا توجد بيانات حالياً', textAlign: TextAlign.center)),
        for (final row in list)
          if (widget.route == 'students')
            entry(row['name'] ?? '', row['email'] ?? '', Icons.person_outline,
                onTap: () =>
                    open(row['name'] ?? 'الطالب', 'students/${row['_id']}'))
          else if (widget.route == 'applications')
            application(row)
          else if (widget.route == 'tasks')
            entry(
                row['title'],
                '${row['description'] ?? ''}\n${label(row['student'])} · ${displayValue(row['status'])}\n${row['dueDate']?.toString().split('T').first ?? ''}',
                Icons.task_alt,
                onTap: () => edit(
                    'تحديث المهمة',
                    '/mobile-workspace/tasks/${row['_id']}',
                    'PATCH',
                    const [
                      InputSpec('status', 'الحالة',
                          options: {
                            'pending': 'لم تبدأ',
                            'in-progress': 'قيد التنفيذ',
                            'completed': 'مكتملة'
                          },
                          required: true)
                    ],
                    initial: row))
          else if (widget.route == 'contacts')
            entry(row['name'], accountRoleLabel(row['role'] ?? ''),
                Icons.person_outline, onTap: () => compose(recipient: row))
          else if (widget.route == 'messages')
            AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text('${label(row['sender'])} ← ${label(row['recipient'])}',
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 10),
                  Text(row['body'] ?? '', style: AppTextStyles.body),
                  Text(
                      row['createdAt']
                              ?.toString()
                              .replaceAll('T', ' ')
                              .split('.')
                              .first ??
                          '',
                      style: AppTextStyles.caption),
                  if (row['sender'] is Map &&
                      row['sender']['_id'] != widget.api.user?['_id'])
                    TextButton(
                        onPressed: () =>
                            compose(recipient: Json.from(row['sender'])),
                        child: const Text('رد')),
                ]))
          else if (widget.route == 'notifications')
            entry(
                row['title'] ?? '',
                row['message'] ?? '',
                row['isRead'] == true
                    ? Icons.notifications_none
                    : Icons.notifications_active, onTap: () async {
              try {
                await widget.api.request('PATCH', '$path/${row['_id']}/read');
                await load();
              } catch (e) {
                if (mounted) setState(() => error = e.toString());
              }
            })
          else
            entry(row['title'] ?? row['name'] ?? '', row['description'] ?? '',
                Icons.info_outline),
      ];
    }
    final row = Json.from(data as Map? ?? {});
    if (widget.route.startsWith('students/')) {
      return [
        _WorkspaceHero(
            name: label(row['user']), subtitle: row['user']?['email'] ?? ''),
        const SizedBox(height: 16),
        entry(
            'الرحلة الدراسية',
            displayValue(
                row['profile']?['applicationStage'] ?? 'file-received'),
            Icons.timeline),
        const Text('طلبات القبول', style: AppTextStyles.sectionLabel),
        for (final item in row['applications'] ?? [])
          application(Json.from(item)),
        const SizedBox(height: 16),
        const Text('المستندات', style: AppTextStyles.sectionLabel),
        for (final item in row['documents'] ?? [])
          entry(item['fileName'] ?? '', displayValue(item['status']),
              Icons.attach_file,
              onTap: () => openLink(context, item['filePath'] ?? '')),
        const SizedBox(height: 16),
        const Text('المدفوعات', style: AppTextStyles.sectionLabel),
        for (final item in row['invoices'] ?? [])
          entry(
              item['description'] ?? '',
              '${item['amount']} · ${displayValue(item['status'])}',
              Icons.receipt_long,
              onTap: (item['invoiceUrl'] ?? '').toString().isEmpty
                  ? null
                  : () => openLink(context, item['invoiceUrl'])),
        OutlinedButton.icon(
            onPressed: () => open('فريقي', 'contacts'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('التواصل مع المستشار')),
      ];
    }
    if (widget.route.startsWith('applications/')) {
      return [
        _WorkspaceHero(
            name: label(row['program']),
            subtitle:
                '${label(row['university'])}\n${displayValue(row['status'])}'),
        const SizedBox(height: 16),
        entry('الطالب', label(row['student']), Icons.person_outline),
        if ((row['notes'] ?? '').toString().isNotEmpty) Text(row['notes']),
        const Text('مستندات الطلب', style: AppTextStyles.sectionLabel),
        for (final doc in row['documents'] ?? [])
          entry(doc['fileName'] ?? '', displayValue(doc['status']),
              Icons.attach_file,
              onTap: () => openLink(context, doc['filePath'] ?? '')),
        if (widget.api.role == 'university') ...[
          PrimaryButton(
              label: 'تحديث قرار القبول',
              onPressed: () =>
                  edit('قرار الجامعة', '$path/status', 'PATCH', const [
                    InputSpec('status', 'القرار', required: true, options: {
                      'under-review': 'قيد المراجعة',
                      'accepted': 'قبول',
                      'rejected': 'رفض'
                    }),
                    InputSpec('note', 'ملاحظات القرار',
                        required: true, multiline: true)
                  ])),
          OutlinedButton(
              onPressed: () => edit('طلب مستند إضافي', '$path/document-request',
                      'POST', const [
                    InputSpec('message', 'المستند المطلوب',
                        required: true, multiline: true)
                  ]),
              child: const Text('طلب مستند إضافي')),
          OutlinedButton.icon(
              onPressed: () => edit(
                  'رفع خطاب القبول', '$path/admission-letter', 'POST', const [],
                  upload: true),
              icon: const Icon(Icons.upload_file),
              label: const Text('رفع خطاب القبول')),
        ],
        const SizedBox(height: 16),
        const Text('المراسلات وخطابات القبول',
            style: AppTextStyles.sectionLabel),
        for (final note in row['decisions'] ?? [])
          entry(
              note['kind'] == 'admission-letter'
                  ? 'خطاب القبول'
                  : 'طلب مستند إضافي',
              note['message'] ?? note['fileName'] ?? '',
              Icons.mail_outline,
              onTap: note['fileUrl'] == null
                  ? null
                  : () => openLink(context, note['fileUrl'])),
        const Text('سجل الطلب', style: AppTextStyles.sectionLabel),
        for (final status in row['statusTimeline'] ?? [])
          entry(displayValue(status['status']), status['note'] ?? '',
              Icons.history),
      ];
    }
    if (widget.route == 'manager') {
      return [
        Row(children: [
          Expanded(child: _workspaceStat('الطلاب', row['students'])),
          Expanded(child: _workspaceStat('الطلبات', row['applications']))
        ]),
        const SizedBox(height: 16),
        const Text('متابعة مهام الفريق', style: AppTextStyles.sectionLabel),
        for (final task in row['tasks'] ?? [])
          entry(
              task['title'],
              '${label(task['assignedTo'])} · ${displayValue(task['status'])}',
              Icons.task_alt)
      ];
    }
    return [
      _WorkspaceHero(
          name: row['name'] ?? '',
          subtitle: accountRoleLabel(row['role'] ?? widget.api.role)),
      const SizedBox(height: 16),
      entry('البريد الإلكتروني', row['email'] ?? '', Icons.email_outlined),
      PrimaryButton(
          label: 'تعديل الملف الشخصي',
          onPressed: () => edit('الملف الشخصي', path, 'PUT',
              const [InputSpec('name', 'الاسم', required: true)],
              initial: row))
    ];
  }

  @override
  Widget build(BuildContext context) {
    final body = loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? ErrorPanel(message: error!, retry: load)
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (widget.route == 'messages')
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: PrimaryButton(
                                label: 'رسالة جديدة',
                                onPressed: compose,
                                icon: Icons.edit_outlined)),
                      ...items()
                    ]));
    return widget.embedded
        ? body
        : Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                appBar: AppBar(title: Text(widget.title), actions: [
                  IconButton(onPressed: load, icon: const Icon(Icons.refresh))
                ]),
                body: body));
  }
}
