import '../../core/utils/json_safe.dart';
import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/community_repository.dart';

/// Community moderation for employees with the 'community' section (and
/// admins): open reports, hide/show posts and comments with a required reason,
/// and suspend/lift students. Blocked terms are managed on the website.
class EmployeeCommunityScreen extends StatefulWidget {
  const EmployeeCommunityScreen({super.key});
  @override
  State<EmployeeCommunityScreen> createState() =>
      _EmployeeCommunityScreenState();
}

String _moderationError(Object e, String fallback) {
  if (e is! ApiException) return fallback;
  switch (e.statusCode) {
    case 403:
      return 'لا تملك صلاحية قسم مجتمع الطلاب.';
    case 404:
      return 'المحتوى لم يعد موجودًا.';
    case 409:
      return 'عدّل مشرف آخر هذا المحتوى للتو. حدّث الصفحة وحاول مجددًا.';
    default:
      return fallback;
  }
}

String _name(dynamic ref) => ref is Map ? '${ref['name'] ?? ''}' : '';
String _reason(dynamic key) =>
    CommunityRepository.reportReasons['$key'] ?? '$key';

class _EmployeeCommunityScreenState extends State<EmployeeCommunityScreen> {
  final repo = CommunityRepository.instance;
  final _blockedTerms = TextEditingController();
  List<Map<String, dynamic>> posts = [],
      reports = [],
      suspensions = [],
      log = [];
  bool loading = true, busy = false;
  String? error, notice;
  String _reportStatus = 'open';
  String _postsFilter = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _blockedTerms.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        repo.moderationPosts(
          status: _postsFilter == 'reported' ? null : _postsFilter,
          reported: _postsFilter == 'reported',
        ),
        repo.moderationReports(status: _reportStatus),
        repo.moderationLog(),
        repo.suspensions(),
        repo.moderationSettings(),
      ]);
      if (!mounted) return;
      final settings = results[4] as Map<String, dynamic>;
      setState(() {
        posts = results[0] as List<Map<String, dynamic>>;
        reports = results[1] as List<Map<String, dynamic>>;
        log = results[2] as List<Map<String, dynamic>>;
        suspensions = results[3] as List<Map<String, dynamic>>;
        _blockedTerms.text =
            (settings['blockedTerms'] as List? ?? []).join('\n');
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = _moderationError(e, 'تعذر تحميل الإشراف.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveTerms() async {
    final terms = _blockedTerms.text
        .split('\n')
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.length > 300 || terms.any((term) => term.length > 60)) {
      setState(() =>
          error = 'القائمة تسمح حتى 300 كلمة، وبحد أقصى 60 حرفًا لكل كلمة.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final saved = await repo.saveBlockedTerms(terms);
      _blockedTerms.text = saved.join('\n');
      if (mounted) setState(() => notice = 'تم حفظ الكلمات المحظورة.');
    } catch (e) {
      if (mounted) {
        setState(() => error = _moderationError(e, 'تعذر حفظ القائمة.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> lift(Map<String, dynamic> suspension) async {
    final user = suspension['user'];
    final ok = await showAppConfirmDialog(context,
        title: 'رفع الإيقاف',
        message: 'سيتمكن ${_name(user)} من النشر والتعليق مجددًا.',
        confirmLabel: 'رفع الإيقاف');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await repo.liftSuspension('${user is Map ? user['_id'] : user}');
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
            content: Text(_moderationError(e, 'تعذر رفع الإيقاف.'))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 5,
        initialIndex: 1,
        child: AppScaffold(
          title: 'إشراف مجتمع الطلاب',
          body: loading
              ? const LoadingState()
              : error != null
                  ? ErrorState(message: error!, onRetry: load)
                  : Column(children: [
                      if (notice != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(notice!,
                              style: const TextStyle(color: AppColors.success)),
                        ),
                      TabBar(
                          isScrollable: true,
                          labelColor: AppColors.navy,
                          indicatorColor: AppColors.green,
                          tabs: [
                            Tab(text: 'المنشورات (${posts.length})'),
                            Tab(
                              text: '${switch (_reportStatus) {
                                'open' => 'البلاغات المفتوحة',
                                'resolved' => 'البلاغات المقبولة',
                                'dismissed' => 'البلاغات المرفوضة',
                                _ => 'البلاغات',
                              }} (${reports.length})',
                            ),
                            Tab(text: 'سجل الإشراف (${log.length})'),
                            Tab(text: 'الموقوفون (${suspensions.length})'),
                            const Tab(text: 'الكلمات المحظورة'),
                          ]),
                      Expanded(
                        child: TabBarView(children: [
                          _postsTab(),
                          _reportsTab(),
                          _logTab(),
                          _suspensionsTab(),
                          _termsTab(),
                        ]),
                      ),
                    ]),
        ),
      );

  Widget _postsTab() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: DropdownButtonFormField<String>(
            initialValue: _postsFilter,
            decoration: const InputDecoration(labelText: 'تصفية المنشورات'),
            items: const [
              DropdownMenuItem(value: '', child: Text('كل المنشورات')),
              DropdownMenuItem(value: 'published', child: Text('المنشورة')),
              DropdownMenuItem(value: 'hidden', child: Text('المخفية')),
              DropdownMenuItem(
                  value: 'reported', child: Text('عليها بلاغ مفتوح')),
            ],
            onChanged: busy
                ? null
                : (value) {
                    setState(() => _postsFilter = value ?? '');
                    load();
                  },
          ),
        ),
        Expanded(
          child: posts.isEmpty
              ? const EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'لا توجد منشورات',
                  message: 'لا توجد منشورات مطابقة لهذا الفلتر.',
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return Card(
                        child: ListTile(
                          title: Text('${post['title'] ?? 'موضوع محذوف'}'),
                          subtitle: Text(
                            '${_name(post['author'])} · ${post['status'] == 'hidden' ? 'مخفي' : 'منشور'} · ${post['openReports'] ?? 0} بلاغ مفتوح',
                          ),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: post['_id'] == null
                              ? null
                              : () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EmployeeCommunityPostScreen(
                                              postId: '${post['_id']}'),
                                    ),
                                  );
                                  load();
                                },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]);

  Widget _reportsTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: DropdownButtonFormField<String>(
          initialValue: _reportStatus,
          decoration: const InputDecoration(labelText: 'حالة البلاغ'),
          items: const [
            DropdownMenuItem(value: 'open', child: Text('مفتوحة')),
            DropdownMenuItem(value: 'resolved', child: Text('مقبولة')),
            DropdownMenuItem(value: 'dismissed', child: Text('مرفوضة')),
          ],
          onChanged: busy
              ? null
              : (value) {
                  setState(() => _reportStatus = value ?? 'open');
                  load();
                },
        ),
      ),
      Expanded(
        child: reports.isEmpty
            ? EmptyState(
                icon: Icons.verified_user_outlined,
                title: _reportStatus == 'open'
                    ? 'لا توجد بلاغات مفتوحة'
                    : 'لا توجد بلاغات بهذه الحالة',
                message: _reportStatus == 'open'
                    ? 'ستظهر هنا البلاغات التي يرسلها الطلاب.'
                    : '',
              )
            : RefreshIndicator(
                onRefresh: load,
                color: AppColors.navy,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final report = reports[i];
                    final post = report['post'];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(
                            post is Map ? '${post['title']}' : 'موضوع محذوف'),
                        subtitle: Text([
                          _reason(report['reason']),
                          report['targetType'] == 'post'
                              ? 'على الموضوع'
                              : 'على تعليق',
                          _name(report['reporter']),
                          if ('${report['details'] ?? ''}'.isNotEmpty)
                            '${report['details']}',
                        ].join(' · ')),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: post is! Map
                            ? null
                            : () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            EmployeeCommunityPostScreen(
                                                postId: '${post['_id']}')));
                                load();
                              },
                      ),
                    );
                  },
                ),
              ),
      ),
    ]);
  }

  Widget _logTab() => log.isEmpty
      ? const EmptyState(
          icon: Icons.history,
          title: 'لا يوجد سجل إشراف',
          message: 'ستظهر هنا قرارات الإشراف وتواريخها.',
        )
      : RefreshIndicator(
          onRefresh: load,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: log.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = log[index];
              final until =
                  DateTime.tryParse('${entry['suspendedUntil'] ?? ''}')
                      ?.toLocal();
              final targetType = '${entry['targetType'] ?? ''}';
              final subject = _name(entry['subject']);
              final post = entry['post'];
              final postTitle = post is Map ? '${post['title'] ?? ''}' : '';
              final createdAt =
                  DateTime.tryParse('${entry['createdAt'] ?? ''}')?.toLocal();
              final reportsClosed =
                  (entry['reportsClosed'] as num?)?.toInt() ?? 0;
              return Card(
                child: ListTile(
                  title: Text(targetType == 'user'
                      ? 'الطالب: $subject'
                      : postTitle.isEmpty
                          ? 'إجراء على ${targetType == 'comment' ? 'تعليق' : 'موضوع'}'
                          : postTitle),
                  subtitle: Text([
                    '${_name(entry['actor'])} · ${entry['fromStatus'] ?? ''} ← ${entry['toStatus'] ?? ''}',
                    if ('${entry['note'] ?? ''}'.isNotEmpty) '${entry['note']}',
                    if (until != null)
                      'حتى ${MaterialLocalizations.of(context).formatMediumDate(until)}',
                    if (reportsClosed > 0) 'إغلاق $reportsClosed بلاغ',
                    if (createdAt != null)
                      MaterialLocalizations.of(context)
                          .formatMediumDate(createdAt),
                  ].join(' · ')),
                ),
              );
            },
          ),
        );

  Widget _termsTab() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'اكتب كل كلمة أو عبارة في سطر منفصل. الحد الأقصى 300 كلمة و60 حرفًا لكل سطر.'),
          const SizedBox(height: 12),
          TextField(
            controller: _blockedTerms,
            enabled: !busy,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: 'الكلمات والعبارات المحظورة',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : saveTerms,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ الكلمات المحظورة'),
          ),
        ],
      );

  Widget _suspensionsTab() {
    if (suspensions.isEmpty) {
      return const EmptyState(
          icon: Icons.person_outline,
          title: 'لا يوجد طلاب موقوفون',
          message: 'يُوقف الطالب من تفاصيل موضوعه أو تعليقه.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: suspensions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = suspensions[i];
        final until = DateTime.tryParse('${s['until']}')?.toLocal();
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(_name(s['user'])),
            subtitle: Text(
                '${until == null ? 'حتى رفعه يدويًا' : 'حتى ${MaterialLocalizations.of(context).formatMediumDate(until)}'} · ${s['reason'] ?? ''}'),
            trailing: TextButton(
                onPressed: busy ? null : () => lift(s),
                child: const Text('رفع الإيقاف')),
          ),
        );
      },
    );
  }
}

class EmployeeCommunityPostScreen extends StatefulWidget {
  final String postId;
  const EmployeeCommunityPostScreen({super.key, required this.postId});
  @override
  State<EmployeeCommunityPostScreen> createState() =>
      _EmployeeCommunityPostScreenState();
}

class _EmployeeCommunityPostScreenState
    extends State<EmployeeCommunityPostScreen> {
  final repo = CommunityRepository.instance;
  Map<String, dynamic>? data;
  bool loading = true, busy = false;
  String? error;

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
      final next = await repo.moderationDetail(widget.postId);
      if (mounted) setState(() => data = next);
    } catch (e) {
      if (mounted) {
        setState(() => error = _moderationError(e, 'تعذر فتح الموضوع.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Replace, don't queue: the newest outcome is the one the moderator needs.
  void toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(AppSnackBar(content: Text(text)));

  Future<void> run(
      Future<void> Function() action, String done, String failed) async {
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      toast(done);
      await load();
    } catch (e) {
      if (mounted) toast(_moderationError(e, failed));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int openReportsFor(String type, String id) =>
      (data!['reports'] as List<Map<String, dynamic>>)
          .where((r) =>
              r['status'] == 'open' &&
              r['targetType'] == type &&
              '${r['target']}' == id)
          .length;

  Future<void> moderate(
      String type, Map<String, dynamic> item, String status) async {
    final hiding = status == 'hidden';
    final note = await showDialog<String>(
        context: context,
        builder: (_) => _ReasonDialog(
            title: hiding ? 'إخفاء المحتوى' : 'إبقاء المحتوى منشورًا',
            label: hiding ? 'سبب الإخفاء (يصل للكاتب)' : 'ملاحظة (اختياري)',
            required: hiding,
            confirmLabel: hiding ? 'إخفاء' : 'تأكيد'));
    if (note == null || !mounted) return;
    await run(
        () => repo.moderate(type, '${item['_id']}', status: status, note: note),
        hiding ? 'تم الإخفاء وإبلاغ الكاتب' : 'تم التحديث وإغلاق البلاغات',
        'تعذر تنفيذ القرار.');
  }

  Future<void> suspend(dynamic author) async {
    if (author is! Map) return;
    final result = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _SuspendDialog(name: _name(author)));
    if (result == null || !mounted) return;
    await run(
        () => repo.suspend('${author['_id']}',
            reason: result['reason'] as String, days: result['days'] as int?),
        'تم إيقاف ${_name(author)} عن النشر',
        'تعذر الإيقاف.');
  }

  Widget actions(String type, Map<String, dynamic> item) {
    final published = item['status'] == 'published';
    final reported = openReportsFor(type, '${item['_id']}');
    return Wrap(spacing: 8, children: [
      if (published)
        OutlinedButton(
            onPressed: busy ? null : () => moderate(type, item, 'hidden'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('إخفاء')),
      if (published && reported > 0)
        OutlinedButton(
            onPressed: busy ? null : () => moderate(type, item, 'published'),
            child: const Text('إبقاء ورفض البلاغات')),
      if (!published)
        OutlinedButton(
            onPressed: busy ? null : () => moderate(type, item, 'published'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('إظهار')),
      TextButton(
          onPressed: busy ? null : () => suspend(item['author']),
          child: const Text('إيقاف الكاتب')),
    ]);
  }

  String statusText(Map<String, dynamic> item, String type) {
    final reported = openReportsFor(type, '${item['_id']}');
    return [
      item['status'] == 'hidden' ? 'مخفي' : 'منشور',
      if (reported > 0) '$reported بلاغ مفتوح',
      if ('${item['moderationNote'] ?? ''}'.isNotEmpty)
        '${item['moderationNote']}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppScaffold(title: 'مراجعة موضوع', body: LoadingState());
    }
    if (error != null) {
      return AppScaffold(
          title: 'مراجعة موضوع',
          body: ErrorState(message: error!, onRetry: load));
    }
    final post = Json.map(data!['post']);
    final comments = data!['comments'] as List<Map<String, dynamic>>;
    final reports = data!['reports'] as List<Map<String, dynamic>>;
    return AppScaffold(
      title: 'مراجعة موضوع',
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.navy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${post['title'] ?? ''}', style: AppTextStyles.screenTitle),
            const SizedBox(height: 4),
            Text('${_name(post['author'])} · ${statusText(post, 'post')}',
                style: AppTextStyles.caption),
            const SizedBox(height: 10),
            Text('${post['body'] ?? ''}', style: AppTextStyles.body),
            const SizedBox(height: 8),
            actions('post', post),
            const Divider(height: 28),
            Text('التعليقات (${comments.length})',
                style: AppTextStyles.sectionLabel),
            for (final comment in comments)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: comment['status'] == 'hidden'
                        ? AppColors.greenSoft
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name(comment['author']),
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text('${comment['body'] ?? ''}', style: AppTextStyles.body),
                    Text(statusText(comment, 'comment'),
                        style: AppTextStyles.caption),
                    actions('comment', comment),
                  ],
                ),
              ),
            const Divider(height: 28),
            Text('البلاغات (${reports.length})',
                style: AppTextStyles.sectionLabel),
            for (final report in reports)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    '${_reason(report['reason'])} · ${_name(report['reporter'])} · '
                    '${report['status'] == 'open' ? 'مفتوح' : report['status'] == 'resolved' ? 'مُعتمد' : 'مرفوض'}',
                    style: AppTextStyles.caption),
              ),
          ],
        ),
      ),
    );
  }
}

/// Returns the entered text (possibly empty when not [required]) or null.
class _ReasonDialog extends StatefulWidget {
  final String title, label, confirmLabel;
  final bool required;
  const _ReasonDialog(
      {required this.title,
      required this.label,
      required this.required,
      required this.confirmLabel});
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          scrollable: true,
          title: Text(widget.title),
          content: TextField(
              controller: text,
              maxLength: 500,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: widget.label)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: widget.required && text.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, text.text.trim()),
                child: Text(widget.confirmLabel)),
          ],
        ),
      );
}

/// Returns {'reason': String, 'days': int?} or null.
class _SuspendDialog extends StatefulWidget {
  final String name;
  const _SuspendDialog({required this.name});
  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  static const durations = <int?, String>{
    1: 'يوم واحد',
    7: 'أسبوع',
    30: 'شهر',
    90: '3 أشهر',
    null: 'حتى رفعه يدويًا',
  };
  final reason = TextEditingController();
  int? days = 7;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          scrollable: true,
          title: Text('إيقاف ${widget.name} عن النشر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('يبقى بإمكان الطالب القراءة، ويصله إشعار بالسبب.',
                  style: AppTextStyles.caption),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: days,
                // The null ("until lifted") choice renders through the hint.
                hint: const Text('حتى رفعه يدويًا'),
                decoration: const InputDecoration(labelText: 'المدة'),
                items: [
                  for (final entry in durations.entries)
                    DropdownMenuItem<int?>(
                        value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => days = v),
              ),
              TextField(
                  controller: reason,
                  maxLength: 500,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'السبب')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: reason.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                        context, {'reason': reason.text.trim(), 'days': days}),
                child: const Text('إيقاف')),
          ],
        ),
      );
}
