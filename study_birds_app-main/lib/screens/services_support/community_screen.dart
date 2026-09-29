import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/auth_session.dart';
import '../../core/analytics_service.dart';
import '../../core/community_repository.dart';

/// Arabic message for a failed community call; server messages are English.
String communityError(Object error, String fallback) {
  if (error is! ApiException) return fallback;
  switch (error.statusCode) {
    case 400:
      return 'تحقق من البيانات المدخلة وحاول مجددًا.';
    case 403:
      return 'أنت موقوف حاليًا عن النشر في المجتمع.';
    case 422:
      return 'النص يحتوي كلمات غير مسموحة في المجتمع. عدّل النص وحاول مجددًا.';
    case 404:
      return 'هذا المحتوى لم يعد متاحًا.';
    case 409:
      return 'سبق أن أبلغت عن هذا المحتوى.';
    case 429:
      return 'تجاوزت الحد المسموح مؤقتًا. حاول بعد قليل.';
    default:
      return fallback;
  }
}

String _name(dynamic ref) => ref is Map ? '${ref['name'] ?? ''}' : '';
String _id(dynamic ref) => ref is Map ? '${ref['_id'] ?? ''}' : '$ref';
bool _isMine(Map<String, dynamic> item) =>
    _id(item['author']) == AuthSession.instance.currentUser?.id;
String _postMeta(Map<String, dynamic> post) => [
      CommunityRepository.topics[post['topic']] ?? '',
      _name(post['country']),
      _name(post['university']),
      _name(post['studyField']),
    ].where((part) => part.isNotEmpty).join(' · ');

class StudentCommunityScreen extends StatefulWidget {
  const StudentCommunityScreen({super.key});
  @override
  State<StudentCommunityScreen> createState() => _StudentCommunityScreenState();
}

class _StudentCommunityScreenState extends State<StudentCommunityScreen> {
  final repo = CommunityRepository.instance;
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> countries = [], universities = [], fields = [];
  Map<String, dynamic> suspension = const {'suspended': false};
  bool loading = true, mine = false;
  String? error, topic, country, university, studyField;

  bool get canWrite => suspension['suspended'] != true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('community');
    load();
    loadLookups();
    loadStatus();
  }

  Future<void> loadStatus() async {
    try {
      final status = await repo.status();
      if (mounted) setState(() => suspension = status);
    } catch (_) {/* Reading still works; the server enforces on write. */}
  }

  Future<void> loadLookups() async {
    Future<List<Map<String, dynamic>>> safe(
            Future<List<Map<String, dynamic>>> Function() call) =>
        call().catchError((_) => <Map<String, dynamic>>[]);
    final results = await Future.wait([
      safe(repo.countries),
      safe(repo.universities),
      safe(repo.studyFields)
    ]);
    if (!mounted) return;
    setState(() {
      countries = results[0];
      universities = results[1];
      fields = results[2];
    });
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await repo.posts(
          mine: mine,
          topic: topic,
          country: country,
          university: university,
          studyField: studyField);
      if (mounted) setState(() => posts = rows);
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = communityError(e, 'تعذر تحميل المجتمع. أعد المحاولة.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int get activeFilters =>
      [country, university, studyField].where((v) => v != null).length;

  Future<void> openFilters() async {
    final picked = await showModalBottomSheet<Map<String, String?>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _FilterSheet(
            countries: countries,
            universities: universities,
            fields: fields,
            country: country,
            university: university,
            studyField: studyField));
    if (picked == null) return;
    setState(() {
      country = picked['country'];
      university = picked['university'];
      studyField = picked['studyField'];
    });
    load();
  }

  Future<void> compose() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => CommunityComposeScreen(
            countries: countries, universities: universities, fields: fields)));
    if (created == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نشر موضوعك')));
      load();
    } else {
      loadStatus();
    }
  }

  Widget suspensionBanner() {
    final until = DateTime.tryParse('${suspension['until']}')?.toLocal();
    final reason = '${suspension['reason'] ?? ''}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.orangeSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning)),
      child: Text(
          'أنت موقوف عن النشر والتعليق والإبلاغ '
          '${until == null ? 'حتى يرفعه فريق الإشراف' : 'حتى ${MaterialLocalizations.of(context).formatMediumDate(until)}'}.'
          '${reason.isEmpty ? '' : ' السبب: $reason.'} ما زال بإمكانك القراءة.',
          style: AppTextStyles.body.copyWith(fontSize: 13)),
    );
  }

  Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
            label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'مجتمع الطلاب',
        floatingActionButton: canWrite
            ? FloatingActionButton.extended(
                onPressed: compose,
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('موضوع جديد'))
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canWrite) suspensionBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              // Wrap, not Row: on narrow phones or large text the filter
              // button moves to its own line instead of overflowing.
              child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    chip('كل المواضيع', !mine, () {
                      setState(() => mine = false);
                      load();
                    }),
                    chip('مواضيعي', mine, () {
                      setState(() => mine = true);
                      load();
                    }),
                    if (!mine)
                      TextButton.icon(
                          onPressed: openFilters,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: Text(activeFilters == 0
                              ? 'تصفية'
                              : 'تصفية ($activeFilters)')),
                  ]),
            ),
            if (!mine)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    chip('الكل', topic == null, () {
                      setState(() => topic = null);
                      load();
                    }),
                    for (final entry in CommunityRepository.topics.entries)
                      chip(entry.value, topic == entry.key, () {
                        setState(() => topic = entry.key);
                        load();
                      }),
                  ],
                ),
              ),
            Expanded(child: _list()),
          ],
        ),
      );

  Widget _list() {
    if (loading) return const LoadingState(message: 'جاري تحميل المجتمع...');
    if (error != null) return ErrorState(message: error!, onRetry: load);
    if (posts.isEmpty) {
      return EmptyState(
          icon: Icons.forum_outlined,
          title: mine ? 'لم تنشر أي موضوع بعد' : 'لا توجد مواضيع مطابقة',
          message: mine
              ? 'شارك تجربتك أو اسأل زملاءك الطلاب.'
              : 'كن أول من يشارك في هذا القسم.',
          ctaLabel: canWrite ? 'موضوع جديد' : null,
          onCta: canWrite ? compose : null);
    }
    return RefreshIndicator(
      onRefresh: load,
      color: AppColors.navy,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _PostCard(
            post: posts[index],
            onTap: posts[index]['status'] == 'hidden'
                ? null
                : () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CommunityThreadScreen(
                            postId: '${posts[index]['_id']}',
                            canWrite: canWrite)));
                    load();
                    loadStatus();
                  }),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onTap;
  const _PostCard({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hidden = post['status'] == 'hidden';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: hidden ? AppColors.warning : AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${post['title'] ?? ''}', style: AppTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text('${post['body'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body),
              const SizedBox(height: 8),
              Text(
                  [
                    _name(post['author']),
                    '${post['commentCount'] ?? 0} تعليق',
                    _postMeta(post),
                  ].where((p) => p.isNotEmpty).join(' · '),
                  style: AppTextStyles.caption),
              if (hidden) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.orangeSoft,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      'أخفاه فريق الإشراف${'${post['moderationNote'] ?? ''}'.isEmpty ? '' : ' — ${post['moderationNote']}'}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textPrimary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final List<Map<String, dynamic>> countries, universities, fields;
  final String? country, university, studyField;
  const _FilterSheet(
      {required this.countries,
      required this.universities,
      required this.fields,
      this.country,
      this.university,
      this.studyField});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? country = widget.country,
      university = widget.university,
      studyField = widget.studyField;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('تصفية المواضيع', style: AppTextStyles.cardTitle),
                const SizedBox(height: 12),
                LookupDropdown(
                    label: 'الدولة',
                    anyLabel: 'كل الدول',
                    items: widget.countries,
                    value: country,
                    onChanged: (v) => setState(() {
                          country = v;
                          university = null;
                        })),
                LookupDropdown(
                    label: 'الجامعة',
                    anyLabel: 'كل الجامعات',
                    items: universitiesIn(widget.universities, country),
                    value: university,
                    onChanged: (v) => setState(() => university = v)),
                LookupDropdown(
                    label: 'التخصص',
                    anyLabel: 'كل التخصصات',
                    items: widget.fields,
                    value: studyField,
                    onChanged: (v) => setState(() => studyField = v)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(
                                  context, <String, String?>{
                                'country': null,
                                'university': null,
                                'studyField': null
                              }),
                          child: const Text('مسح'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FilledButton(
                          onPressed: () => Navigator.pop(context, {
                                'country': country,
                                'university': university,
                                'studyField': studyField
                              }),
                          child: const Text('تطبيق'))),
                ]),
              ],
            ),
          ),
        ),
      );
}

List<Map<String, dynamic>> universitiesIn(
        List<Map<String, dynamic>> universities, String? country) =>
    country == null
        ? universities
        : universities.where((u) => _id(u['country']) == country).toList();

/// Optional lookup picker. Renders nothing when the lookup list failed to load.
class LookupDropdown extends StatelessWidget {
  final String label, anyLabel;
  final List<Map<String, dynamic>> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  const LookupDropdown(
      {super.key,
      required this.label,
      required this.anyLabel,
      required this.items,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final ids = items.map((item) => '${item['_id']}').toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        // Keyed on the value so a parent reset (e.g. country change clearing
        // the university) re-initialises the field.
        key: ValueKey('$label:$value:${ids.length}'),
        isExpanded: true,
        initialValue: ids.contains(value) ? value : null,
        // A null value renders the hint, not the null item, so repeat it here.
        hint: Text(anyLabel),
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(anyLabel)),
          for (final item in items)
            DropdownMenuItem<String?>(
                value: '${item['_id']}',
                child: Text('${item['name'] ?? ''}',
                    overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class CommunityComposeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> countries, universities, fields;
  const CommunityComposeScreen(
      {super.key,
      this.countries = const [],
      this.universities = const [],
      this.fields = const []});
  @override
  State<CommunityComposeScreen> createState() => _CommunityComposeScreenState();
}

class _CommunityComposeScreenState extends State<CommunityComposeScreen> {
  final title = TextEditingController(), body = TextEditingController();
  String topic = 'experience';
  String? country, university, studyField, error;
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  bool get ready => title.text.trim().isNotEmpty && body.text.trim().isNotEmpty;

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await CommunityRepository.instance.createPost(
          title: title.text,
          body: body.text,
          topic: topic,
          country: country,
          university: university,
          studyField: studyField);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Inputs are kept so the student can retry without retyping.
      if (mounted) {
        setState(
            () => error = communityError(e, 'تعذر نشر الموضوع. أعد المحاولة.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'موضوع جديد',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
                'شارك تجربتك أو سؤالك باحترام. المحتوى خاضع لمراجعة الفريق.',
                style: AppTextStyles.caption),
            const SizedBox(height: 12),
            TextField(
                controller: title,
                maxLength: 150,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'العنوان')),
            TextField(
                controller: body,
                maxLength: 5000,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'النص')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: topic,
              decoration: const InputDecoration(labelText: 'الموضوع'),
              items: [
                for (final entry in CommunityRepository.topics.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) => setState(() => topic = v ?? topic),
            ),
            const SizedBox(height: 12),
            LookupDropdown(
                label: 'التخصص (اختياري)',
                anyLabel: 'بدون تخصص',
                items: widget.fields,
                value: studyField,
                onChanged: (v) => setState(() => studyField = v)),
            LookupDropdown(
                label: 'الدولة (اختياري)',
                anyLabel: 'بدون دولة',
                items: widget.countries,
                value: country,
                onChanged: (v) => setState(() {
                      country = v;
                      university = null;
                    })),
            LookupDropdown(
                label: 'الجامعة (اختياري)',
                anyLabel: 'بدون جامعة',
                items: universitiesIn(widget.universities, country),
                value: university,
                onChanged: (v) => setState(() => university = v)),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!,
                      style: const TextStyle(color: AppColors.danger))),
            FilledButton(
                onPressed: busy || !ready ? null : submit,
                child: Text(busy ? 'جارٍ النشر...' : 'نشر')),
          ],
        ),
      );
}

class CommunityThreadScreen extends StatefulWidget {
  final String postId;

  /// False for a suspended student: reading only, no comment/report controls.
  final bool canWrite;
  const CommunityThreadScreen(
      {super.key, required this.postId, this.canWrite = true});
  @override
  State<CommunityThreadScreen> createState() => _CommunityThreadScreenState();
}

class _CommunityThreadScreenState extends State<CommunityThreadScreen> {
  final repo = CommunityRepository.instance;
  final commentText = TextEditingController();
  Map<String, dynamic>? post;
  List<Map<String, dynamic>> comments = [];
  bool loading = true, busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    commentText.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await repo.thread(widget.postId);
      if (!mounted) return;
      setState(() {
        post = data['post'] as Map<String, dynamic>;
        comments = data['comments'] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = communityError(e, 'تعذر فتح الموضوع.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> run(Future<void> Function() action, String done, String failed,
      {bool reload = true}) async {
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      toast(done);
      if (reload) await load();
    } catch (e) {
      if (mounted) toast(communityError(e, failed));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendComment() => run(() async {
        await repo.comment(widget.postId, commentText.text);
        commentText.clear();
      }, 'تمت إضافة تعليقك', 'تعذر إضافة التعليق.');

  Future<void> deletePost() async {
    final ok = await showAppConfirmDialog(context,
        title: 'حذف الموضوع',
        message: 'سيُحذف الموضوع وكل تعليقاته نهائيًا.',
        confirmLabel: 'حذف',
        danger: true);
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await repo.deletePost(widget.postId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(communityError(e, 'تعذر حذف الموضوع.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteComment(Map<String, dynamic> comment) async {
    final ok = await showAppConfirmDialog(context,
        title: 'حذف التعليق',
        message: 'سيُحذف تعليقك نهائيًا.',
        confirmLabel: 'حذف',
        danger: true);
    if (!ok || !mounted) return;
    await run(() => repo.deleteComment('${comment['_id']}'), 'تم حذف التعليق',
        'تعذر حذف التعليق.');
  }

  Future<void> report(String type, String id) async {
    final picked = await showDialog<Map<String, String>>(
        context: context, builder: (_) => const CommunityReportDialog());
    if (picked == null || !mounted) return;
    await run(
        () => repo.report(type, id,
            reason: picked['reason']!, details: picked['details'] ?? ''),
        'شكرًا، وصل بلاغك لفريق الإشراف',
        'تعذر إرسال البلاغ.',
        reload: false);
  }

  Widget ownerAction(Map<String, dynamic> item, String type) =>
      !_isMine(item) && !widget.canWrite
          ? const SizedBox(height: 8)
          : _isMine(item)
              ? TextButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                          type == 'post' ? deletePost() : deleteComment(item),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(type == 'post' ? 'حذف موضوعي' : 'حذف تعليقي'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.danger))
              : TextButton.icon(
                  onPressed: busy ? null : () => report(type, '${item['_id']}'),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('إبلاغ'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary));

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'الموضوع',
        body: loading
            ? const LoadingState()
            : error != null
                ? ErrorState(message: error!, onRetry: load)
                : Column(children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: load,
                        color: AppColors.navy,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text('${post!['title'] ?? ''}',
                                style: AppTextStyles.screenTitle),
                            const SizedBox(height: 4),
                            Text(
                                [_name(post!['author']), _postMeta(post!)]
                                    .where((p) => p.isNotEmpty)
                                    .join(' · '),
                                style: AppTextStyles.caption),
                            const SizedBox(height: 12),
                            Text('${post!['body'] ?? ''}',
                                style: AppTextStyles.body),
                            Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: ownerAction(post!, 'post')),
                            const Divider(height: 24),
                            Text('التعليقات (${comments.length})',
                                style: AppTextStyles.sectionLabel),
                            const SizedBox(height: 8),
                            if (comments.isEmpty)
                              const Text('لا توجد تعليقات بعد. شارك برأيك.',
                                  style: AppTextStyles.caption),
                            for (final comment in comments)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 0),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: AppColors.border)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_name(comment['author']),
                                        style: AppTextStyles.body.copyWith(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('${comment['body'] ?? ''}',
                                        style: AppTextStyles.body),
                                    Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: ownerAction(comment, 'comment')),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.canWrite)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Row(children: [
                            Expanded(
                                child: TextField(
                                    controller: commentText,
                                    maxLength: 2000,
                                    minLines: 1,
                                    maxLines: 4,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                        hintText: 'أضف تعليقًا',
                                        counterText: ''))),
                            const SizedBox(width: 8),
                            IconButton.filled(
                                tooltip: 'إرسال',
                                onPressed:
                                    busy || commentText.text.trim().isEmpty
                                        ? null
                                        : sendComment,
                                icon: const Icon(Icons.send_rounded)),
                          ]),
                        ),
                      ),
                  ]),
      );
}

/// Returns {'reason', 'details'} or null when cancelled.
class CommunityReportDialog extends StatefulWidget {
  const CommunityReportDialog({super.key});
  @override
  State<CommunityReportDialog> createState() => _CommunityReportDialogState();
}

class _CommunityReportDialogState extends State<CommunityReportDialog> {
  String? reason;
  final details = TextEditingController();

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          scrollable: true,
          title: const Text('الإبلاغ عن محتوى'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  'سيراجع فريق الإشراف البلاغ. لن يظهر اسمك لكاتب المحتوى.',
                  style: AppTextStyles.caption),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => setState(() => reason = v),
                child: Column(children: [
                  for (final entry in CommunityRepository.reportReasons.entries)
                    RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: entry.key,
                        title: Text(entry.value)),
                ]),
              ),
              TextField(
                  controller: details,
                  maxLength: 500,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'تفاصيل (اختياري)')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: reason == null
                    ? null
                    : () => Navigator.pop(
                        context, {'reason': reason!, 'details': details.text}),
                child: const Text('إرسال البلاغ')),
          ],
        ),
      );
}
