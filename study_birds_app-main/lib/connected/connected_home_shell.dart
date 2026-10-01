part of 'connected_app.dart';

/// The original five-tab layout, backed by the website's data and CMS modules.
class _ConnectedHomeShell extends StatefulWidget {
  const _ConnectedHomeShell(
      {required this.api,
      required this.config,
      required this.modules,
      required this.refreshConfig});
  final StudyBirdsApi api;
  final Json config;
  final List<Json> modules;
  final Future<void> Function() refreshConfig;
  @override
  State<_ConnectedHomeShell> createState() => _ConnectedHomeShellState();
}

class _ConnectedHomeShellState extends State<_ConnectedHomeShell> {
  int tab = 0;
  String search = '';
  Json? overview;
  String? overviewError;
  bool loadingOverview = false;
  bool get partner => widget.api.role == 'partner';
  Color get primary => Theme.of(context).colorScheme.primary;
  static const exploreKeys = {
    'universities',
    'programs',
    'countries',
    'scholarships',
    'favorites',
    'orientation-test',
    'search',
    'program-finder'
  };
  static const journeyKeys = {
    'overview',
    'applications',
    'documents',
    'financials',
    'arrival-services',
    'calendar'
  };
  static const accountKeys = {
    'profile',
    'notifications',
    'verification',
    'activity',
    'referral',
    'settings',
    'student-wallet'
  };
  static const extraIcons = {
    'countries': Icons.public_rounded,
    'scholarships': Icons.card_giftcard_rounded,
    'visa': Icons.badge_outlined,
    'services': Icons.miscellaneous_services_outlined,
    'consultations': Icons.support_agent_rounded,
    'team': Icons.groups_outlined,
    'insurance': Icons.health_and_safety_outlined,
    'equivalency': Icons.verified_outlined,
    'registration': Icons.how_to_reg_rounded,
    'knowledge-base': Icons.menu_book_outlined,
    'orientation-test': Icons.explore_outlined,
    'arrival-services': Icons.flight_land_rounded,
    'agent-students': Icons.groups_rounded,
    'wallet': Icons.account_balance_wallet_outlined,
    'referral': Icons.share_outlined,
    'verification': Icons.verified_user_outlined,
    'activity': Icons.history_rounded,
    'marketing': Icons.campaign_outlined,
  };

  @override
  void initState() {
    super.initState();
    loadOverview();
  }

  Json? module(String key) {
    for (final item in widget.modules) {
      if (item['key'] == key) return item;
    }
    return null;
  }

  IconData icon(String key) =>
      ConnectedHome.icons[key] ?? extraIcons[key] ?? Icons.widgets_outlined;
  Future<void> loadOverview() async {
    if (module('overview') == null) return;
    setState(() {
      loadingOverview = true;
      overviewError = null;
    });
    try {
      final result = await widget.api.request(
          'GET', partner ? '/partners/overview' : '/students/overview');
      if (mounted) setState(() => overview = Json.from(result));
    } catch (e) {
      if (mounted) setState(() => overviewError = e.toString());
    } finally {
      if (mounted) setState(() => loadingOverview = false);
    }
  }

  Future<void> refresh() async {
    await widget.refreshConfig();
    if (mounted) await loadOverview();
  }

  Future<void> open(Json item) async {
    final key = item['key'].toString();
    if ([
          'search',
          'program-finder',
          'calendar',
          'activity',
          'settings',
          'referral',
          'student-wallet',
          'emergency',
          'bird-ai'
        ].contains(key) &&
        !(partner && ['activity', 'referral'].contains(key))) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StudentFeaturePage(
              api: widget.api,
              feature: key,
              title: item['title'],
              config: widget.config)));
      return;
    }
    if (key == 'messages' || key == 'team') {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WorkspacePage(
              api: widget.api,
              title: item['title'],
              route: key == 'team' ? 'contacts' : 'messages')));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResourceScreen(
              api: widget.api,
              title: item['title'],
              kind: item['key'],
              path: item['path'] ??
                  ConnectedHome.paths[item['key']] ??
                  '/mobile/content?section=${item['key']}',
            )));
    if (mounted && item['key'] != 'overview') await loadOverview();
  }

  void openKey(String key) {
    final item = module(key);
    if (item != null) open(item);
  }

  List<Json> get currentModules {
    final result = widget.modules
        .where((item) {
          final key = item['key'];
          if (partner) {
            if (tab == 1) return key == 'agent-students';
            if (tab == 2) return key == 'wallet';
            if (tab == 4) return accountKeys.contains(key);
            return !accountKeys.contains(key) &&
                !{'overview', 'agent-students', 'wallet'}.contains(key);
          }
          if (tab == 1) return journeyKeys.contains(key) && key != 'overview';
          if (tab == 2) return exploreKeys.contains(key);
          if (tab == 4) return accountKeys.contains(key);
          return !journeyKeys.contains(key) &&
              !exploreKeys.contains(key) &&
              !accountKeys.contains(key);
        })
        .where((item) =>
            search.isEmpty || item['title'].toString().contains(search))
        .toList();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final titles = partner
        ? ['الرئيسية', 'طلابي', 'المحفظة', 'الخدمات', 'حسابي']
        : ['الرئيسية', 'الرحلة', 'استكشاف', 'الخدمات', 'حسابي'];
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: tab == 0
              ? null
              : AppBar(
                  title: Text(titles[tab],
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 20)),
                  centerTitle: true,
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  automaticallyImplyLeading: false,
                  elevation: 0,
                ),
          body: SafeArea(
              child: RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    key: ValueKey('home-tab-$tab'),
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.zero,
                    children: tab == 0
                        ? home()
                        : [
                            if (tab == 4) profileHeader(),
                            if (tab == 1 &&
                                !partner &&
                                module('overview') != null)
                              Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: journeyCard()),
                            if (tab == 2 && !partner)
                              Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: TextField(
                                    decoration: InputDecoration(
                                        hintText: 'ماذا تريد أن تستكشف؟',
                                        prefixIcon:
                                            Icon(Icons.search, color: primary),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppColors.border))),
                                    onChanged: (value) =>
                                        setState(() => search = value),
                                  )),
                            if (currentModules.isEmpty && tab != 4)
                              const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('لا توجد أقسام متاحة حالياً',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.body)),
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: tab == 4
                                    ? Column(children: [
                                        for (final item in currentModules)
                                          accountRow(item)
                                      ])
                                    : moduleGrid(currentModules)),
                            if (tab == 3 && !partner)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: AppCard(
                                      onTap: () => open({
                                            'key': 'requests',
                                            'title': 'طلبات الخدمات',
                                            'path': '/mobile/requests'
                                          }),
                                      child: Row(children: [
                                        Icon(Icons.room_service_outlined,
                                            color: primary),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                            child: Text('متابعة طلبات الخدمات',
                                                style:
                                                    AppTextStyles.cardTitle)),
                                        const Icon(Icons.chevron_left)
                                      ]))),
                            if (tab == 4) ...accountActions(),
                            const SizedBox(height: 24),
                          ],
                  ))),
          bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border))),
              child: BottomNavigationBar(
                currentIndex: tab,
                onTap: (index) => setState(() {
                  tab = index;
                  search = '';
                }),
                backgroundColor: Colors.white,
                selectedItemColor: primary,
                unselectedItemColor: AppColors.textSecondary,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 12,
                unselectedFontSize: 11,
                selectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w700),
                elevation: 0,
                items: [
                  BottomNavigationBarItem(
                      icon: const Icon(Icons.home_rounded), label: titles[0]),
                  BottomNavigationBarItem(
                      icon: Icon(partner
                          ? Icons.groups_outlined
                          : Icons.timeline_rounded),
                      label: titles[1]),
                  BottomNavigationBarItem(
                      icon: Icon(partner
                          ? Icons.account_balance_wallet_outlined
                          : Icons.explore_outlined),
                      label: titles[2]),
                  BottomNavigationBarItem(
                      icon: const Icon(Icons.miscellaneous_services_outlined),
                      label: titles[3]),
                  BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline_rounded),
                      label: titles[4]),
                ],
              )),
        ));
  }

  List<Widget> home() {
    final quickKeys = partner
        ? {'agent-students', 'wallet', 'support-tickets', 'marketing'}
        : {
            'applications',
            'universities',
            'documents',
            'programs',
            'consultations'
          };
    final quick =
        widget.modules.where((m) => quickKeys.contains(m['key'])).toList();
    final discover = widget.modules
        .where((m) => (partner
                ? {'referral', 'verification', 'knowledge-base'}
                : {
                    'universities',
                    'countries',
                    'scholarships',
                    'orientation-test'
                  })
            .contains(m['key']))
        .toList();
    final notifications = module('notifications');
    final recent = overview?[partner ? 'notifications' : 'recentApplications'];
    return [
      Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 38),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primary, primary.withValues(alpha: .92)]),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(children: [
            Row(children: [
              heroButton(
                  Icons.menu_rounded, 'حسابي', () => setState(() => tab = 4)),
              Expanded(
                  child: Column(children: [
                Text('مرحباً ${widget.api.user?['name'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(widget.config['welcome'] ?? 'رحلتك الدراسية تبدأ هنا',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12))
              ])),
              if (notifications != null)
                heroButton(Icons.notifications_none_rounded,
                    notifications['title'], () => open(notifications))
              else
                Image.asset('assets/images/logo_mark.png',
                    width: 38, color: Colors.white),
            ]),
            const SizedBox(height: 20),
            InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (!partner && module('search') != null) {
                    openKey('search');
                  } else {
                    setState(() => tab = partner ? 1 : 2);
                  }
                },
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.search_rounded, color: primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              partner
                                  ? 'طلابك وطلبات التقديم'
                                  : 'ابحث عن جامعة، برنامج، دولة...',
                              style: AppTextStyles.body)),
                      const Icon(Icons.tune_rounded, color: AppColors.orange)
                    ]))),
          ])),
      if (module('overview') != null)
        Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: journeyCard())),
      if ((widget.config['banners'] as List? ?? []).isNotEmpty)
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
                height: 150,
                child: PageView(children: [
                  for (final banner in widget.config['banners'])
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Material(
                                color: Colors.white,
                                child: InkWell(
                                    onTap: () => openLink(
                                        context, banner['linkUrl'] ?? ''),
                                    child:
                                        Stack(fit: StackFit.expand, children: [
                                      if ((banner['imageUrl'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        AppNetworkImage(banner['imageUrl'],
                                            fit: BoxFit.cover,
                                            errorWidget: Center(
                                                child: Icon(
                                                    Icons.image_outlined,
                                                    color: primary))),
                                      if ((banner['title'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                                width: double.infinity,
                                                color: primary.withValues(
                                                    alpha: .9),
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Text(banner['title'],
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600)))),
                                    ])))))
                ]))),
      if (quick.isNotEmpty) ...[
        sectionTitle('الوصول السريع'),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
            child: LayoutBuilder(
                builder: (context, constraints) =>
                    Wrap(spacing: 8, runSpacing: 12, children: [
                      for (final item in quick)
                        SizedBox(
                            width: (constraints.maxWidth - 32) / 5 < 60
                                ? (constraints.maxWidth - 16) / 3
                                : (constraints.maxWidth - 32) / 5,
                            child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => open(item),
                                child: Column(children: [
                                  Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: AppColors.border)),
                                      child: Icon(icon(item['key']),
                                          color: primary)),
                                  const SizedBox(height: 7),
                                  Text(item['title'],
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.caption)
                                ])))
                    ]))),
      ],
      if (discover.isNotEmpty) ...[
        sectionTitle(partner ? 'إدارة أعمالك' : 'استكشف فرصك الدراسية'),
        Padding(padding: const EdgeInsets.all(16), child: moduleGrid(discover))
      ],
      if (recent is List && recent.isNotEmpty) ...[
        sectionTitle(partner ? 'آخر الإشعارات' : 'آخر طلباتك'),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final raw in recent.take(3))
                if (raw is Map)
                  AppCard(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ResourceDetail(
                                api: widget.api,
                                item: Json.from(raw),
                                kind:
                                    partner ? 'notifications' : 'applications',
                                detailPath: partner
                                    ? null
                                    : '/applications/${raw['_id']}')));
                        if (mounted) await loadOverview();
                      },
                      child: Row(children: [
                        Icon(
                            partner
                                ? Icons.notifications_outlined
                                : Icons.description_outlined,
                            color: primary),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(itemTitle(Json.from(raw)),
                                  style: AppTextStyles.cardTitle),
                              const SizedBox(height: 5),
                              Text(
                                  displayValue(
                                      raw['status'] ?? raw['message'] ?? ''),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption)
                            ])),
                        const Icon(Icons.chevron_left,
                            color: AppColors.textSecondary)
                      ]))
            ])),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget heroButton(
          IconData icon, String tooltip, VoidCallback onTap) =>
      Container(
          decoration:
              BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12)),
          child: IconButton(
              tooltip: tooltip,
              onPressed: onTap,
              icon: Icon(icon, color: Colors.white, size: 23)));
  Widget sectionTitle(String title) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(title,
          style: AppTextStyles.sectionLabel
              .copyWith(fontSize: 15, color: primary)));
  Widget moduleGrid(List<Json> items) =>
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= 650 ? 3 : 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final item in items)
            SizedBox(
                width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
                child: AppCard(
                    margin: EdgeInsets.zero,
                    onTap: () => open(item),
                    child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: scale > 1.3 ? 132 : 100),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                      color: primary.withValues(alpha: .07),
                                      shape: BoxShape.circle),
                                  child:
                                      Icon(icon(item['key']), color: primary)),
                              const SizedBox(height: 12),
                              Text(item['title'],
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.cardTitle
                                      .copyWith(fontSize: 14))
                            ]))))
        ]);
      });

  Widget journeyCard() {
    if (loadingOverview && overview == null) {
      return const AppCard(
          child: Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator())));
    }
    if (overviewError != null) {
      return AppCard(
          child: Column(children: [
        Text(overviewError!, style: AppTextStyles.body),
        TextButton(
            onPressed: loadOverview,
            child: const Text('إعادة تحميل ملخص الرحلة'))
      ]));
    }
    final stats = overview?['stats'] is Map
        ? Json.from(overview!['stats'])
        : <String, dynamic>{};
    final progress = overview?['progress'] is Map
        ? Json.from(overview!['progress'])
        : <String, dynamic>{};
    final stages = progress['stages'] as List? ?? [];
    final completed = stages.where((s) => s['status'] == 'completed').length;
    final fraction = stages.isEmpty ? 0.0 : completed / stages.length;
    final stage = progress['currentStage'];
    final target = partner
        ? module('agent-students')
        : module(stage == 'file-received'
            ? 'profile'
            : stage == 'final-accepted' || stage == 'travel-and-settlement'
                ? 'arrival-services'
                : 'applications');
    return AppCard(
        margin: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(partner ? 'ملخص أعمالك' : 'رحلتك الحالية',
                      style:
                          AppTextStyles.sectionLabel.copyWith(color: primary)),
                  const SizedBox(height: 7),
                  Text(
                      partner
                          ? 'تابع طلابك وخطوات القبول'
                          : stage == null
                              ? 'ابدأ رحلتك الدراسية معنا'
                              : displayValue(stage),
                      style: AppTextStyles.cardTitle)
                ])),
            if (!partner)
              SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 4,
                        backgroundColor: AppColors.border,
                        color: AppColors.orange),
                    Text('${(fraction * 100).round()}%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primary))
                  ]))
          ]),
          if (target != null) ...[
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.arrow_circle_left_outlined,
                      color: AppColors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(target['title'], style: AppTextStyles.body)),
                  TextButton(
                      onPressed: () => open(target),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.orange),
                      child: const Text('متابعة'))
                ]))
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: stat(
                      partner ? 'إجمالي الطلاب' : 'طلباتك الحالية',
                      stats[partner ? 'totalStudents' : 'currentApplications'],
                      Icons.description_outlined)),
              Container(width: 1, height: 34, color: AppColors.border),
              Expanded(
                  child: stat(
                      partner ? 'الطلاب المقبولون' : 'مستندات مقبولة',
                      stats[partner ? 'acceptedStudents' : 'acceptedDocuments'],
                      Icons.task_alt_rounded))
            ])
          ],
          if (tab == 1) ...[
            const SizedBox(height: 18),
            for (final stage in stages)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(children: [
                    Icon(
                        stage['status'] == 'completed'
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_checked,
                        color: stage['status'] == 'upcoming'
                            ? AppColors.border
                            : AppColors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            stage['titleAr'] ?? displayValue(stage['key']),
                            style: AppTextStyles.body))
                  ]))
          ],
        ]));
  }

  Widget stat(String title, dynamic value, IconData iconData) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(iconData, size: 22, color: primary),
        const SizedBox(width: 9),
        Flexible(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value?.toString() ?? '—', style: AppTextStyles.cardTitle),
          Text(title, style: AppTextStyles.caption)
        ]))
      ]);
  Widget profileHeader() => Container(
      color: primary,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(children: [
        CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child:
                Icon(Icons.person_outline_rounded, color: primary, size: 36)),
        const SizedBox(height: 12),
        Text(widget.api.user?['name'] ?? '',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 19)),
        const SizedBox(height: 5),
        Text(widget.api.user?['email'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 13))
      ]));
  Widget accountRow(Json item) => AppCard(
      onTap: () => open(item),
      child: Row(children: [
        Icon(icon(item['key']), color: primary),
        const SizedBox(width: 12),
        Expanded(child: Text(item['title'], style: AppTextStyles.cardTitle)),
        const Icon(Icons.chevron_left, color: AppColors.textSecondary)
      ]));
  List<Widget> accountActions() => [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
                onTap: () => openEditor(
                        context,
                        widget.api,
                        'تغيير كلمة المرور',
                        '/auth/change-password',
                        'POST', const [
                      InputSpec('currentPassword', 'كلمة المرور الحالية',
                          secret: true, required: true),
                      InputSpec('newPassword', 'كلمة المرور الجديدة',
                          secret: true, required: true)
                    ]),
                child: Row(children: [
                  Icon(Icons.lock_outline, color: primary),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('تغيير كلمة المرور',
                          style: AppTextStyles.cardTitle)),
                  const Icon(Icons.chevron_left)
                ]))),
        if ((widget.config['supportEmail'] ?? '').toString().isNotEmpty)
          ListTile(
              leading: Icon(Icons.mail_outline, color: primary),
              title: Text(widget.config['supportEmail']),
              onTap: () =>
                  openLink(context, 'mailto:${widget.config['supportEmail']}')),
        if ((widget.config['supportPhone'] ?? '').toString().isNotEmpty)
          ListTile(
              leading: Icon(Icons.phone_outlined, color: primary),
              title: Text(widget.config['supportPhone']),
              onTap: () =>
                  openLink(context, 'tel:${widget.config['supportPhone']}')),
        Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.border)),
                onPressed: () async {
                  try {
                    await widget.api.logout();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'))),
      ];
}
