import '../home_journey/student_banner_carousel.dart';
import '../../core/widgets/keep_alive_section.dart';
import '../universities_programs_countries/universities_screens.dart';
import '../universities_programs_countries/programs_screens.dart';
import '../applications_documents_payments/applications_screens.dart';
import 'services_consultation_screens.dart';
import '../../core/widgets/cached_resource.dart';
import '../stories/story_photo_editor.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../core/widgets/community_reactions.dart';
import '../../core/widgets/community_post_image.dart';
import '../../core/widgets/gallery_access.dart';
import '../community/student_profile_link.dart';
import '../../core/widgets/community_terms.dart';
import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/services/analytics_service.dart';
import '../../core/repositories/community_repository.dart';

bool _isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _communityText(BuildContext context, String arabic, String english) =>
    _isArabic(context) ? arabic : english;

/// Localized message for a failed community call; server messages are English.
String communityError(Object error, String fallback,
    {bool arabic = true, bool creatingPost = false}) {
  if (error is! ApiException) return fallback;
  switch (error.statusCode) {
    case 400:
      return arabic
          ? 'تحقق من البيانات المدخلة وحاول مجددًا.'
          : 'Check the entered information and try again.';
    case 403:
      return arabic
          ? 'أنت موقوف حاليًا عن النشر في المجتمع.'
          : 'You are currently restricted from posting in the community.';
    case 422:
      return arabic
          ? 'النص يحتوي كلمات غير مسموحة في المجتمع. عدّل النص وحاول مجددًا.'
          : 'Your text contains restricted words. Edit it and try again.';
    case 404:
      if (creatingPost) {
        return arabic
            ? 'خدمة نشر المنشورات غير متاحة حاليًا. احتفظنا بمنشورك، حاول لاحقًا.'
            : 'Publishing is currently unavailable. Your draft is preserved; try again later.';
      }
      return arabic
          ? 'هذا المحتوى لم يعد متاحًا.'
          : 'This content is no longer available.';
    case 409:
      return arabic
          ? 'سبق أن أبلغت عن هذا المحتوى.'
          : 'You already reported this content.';
    case 429:
      return arabic
          ? 'تجاوزت الحد المسموح مؤقتًا. حاول بعد قليل.'
          : 'You reached the temporary limit. Try again shortly.';
    default:
      return fallback;
  }
}

String _name(dynamic ref) => ref is Map ? '${ref['name'] ?? ''}' : '';
String _id(dynamic ref) => ref is Map ? '${ref['_id'] ?? ''}' : '$ref';
String _communityName(dynamic ref) {
  if (ref is Map &&
      ref['role'] == 'university' &&
      ref['linkedUniversity'] is Map) {
    final official = '${ref['linkedUniversity']['name'] ?? ''}'.trim();
    if (official.isNotEmpty) return official;
  }
  return _name(ref);
}

String _communityAvatar(dynamic ref) {
  if (ref is Map &&
      ref['role'] == 'university' &&
      ref['linkedUniversity'] is Map) {
    final logo = '${ref['linkedUniversity']['logo'] ?? ''}'.trim();
    if (logo.isNotEmpty) return logo;
  }
  return ref is Map ? '${ref['avatar'] ?? ''}' : '';
}

bool _isMine(Map<String, dynamic> item) =>
    _id(item['author']) == AuthSession.instance.currentUser?.id;
String _postMeta(Map<String, dynamic> post, {bool arabic = true}) => [
      CommunityRepository.topicLabels(arabic: arabic)[post['topic']] ?? '',
      _name(post['country']),
      _name(post['university']),
      _name(post['studyField']),
    ].where((part) => part.isNotEmpty).join(' · ');

class StudentCommunityScreen extends StatefulWidget {
  final Widget? header;
  final List<Widget>? actions;
  final bool embedded;
  const StudentCommunityScreen(
      {super.key, this.header, this.actions, this.embedded = false});
  @override
  State<StudentCommunityScreen> createState() => _StudentCommunityScreenState();
}

class _StudentCommunityScreenState extends State<StudentCommunityScreen>
    with CachedResource<StudentCommunityScreen> {
  @override
  Iterable<String> get cachedPaths => const ['/community'];
  @override
  Future<void> reloadCachedResource() => load();
  final repo = CommunityRepository.instance;
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> countries = [], universities = [], fields = [];
  Map<String, dynamic> suspension = const {'suspended': false};
  bool loading = true, mine = false, adminOnly = false;
  int _loadVersion = 0;
  int _bannerVersion = 0;
  String? error, topic, country, university, studyField;

  void _openAdDestination(String destination) {
    final Widget page = switch (destination) {
      'universities' => const UniversitiesExplorerScreen(),
      'programs' => const ProgramsExplorerScreen(),
      'services' => const ServicesCenterScreen(),
      _ => const ApplicationsListScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

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
    } catch (swallowedError, swallowedStack) {
      ErrorReporter.swallowed(swallowedError, swallowedStack,
          'screens/services_support/community_screen.dart:71'); /* Reading still works; the server enforces on write. */
    }
  }

  Future<void> loadLookups() async {
    Future<List<Map<String, dynamic>>> safe(
            Future<List<Map<String, dynamic>>> Function() call) =>
        call().catchError(ErrorReporter.fallback(
            'screens/services_support/community_screen.dart:78',
            <Map<String, dynamic>>[]));
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
    final version = ++_loadVersion;
    setState(() {
      loading = posts.isEmpty;
      error = null;
    });
    try {
      final rows = await repo.posts(
          mine: mine,
          adminOnly: adminOnly,
          topic: topic,
          country: country,
          university: university,
          studyField: studyField);
      if (mounted && version == _loadVersion) {
        setState(() => posts = rows);
      }
    } catch (e) {
      if (mounted && version == _loadVersion) {
        setState(() => error = communityError(
            e,
            _communityText(context, 'تعذر تحميل المجتمع. أعد المحاولة.',
                'Could not load the community. Try again.'),
            arabic: _isArabic(context)));
      }
    } finally {
      if (mounted && version == _loadVersion) setState(() => loading = false);
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
    if (picked == null || !mounted) return;
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
    if (!mounted) return;
    if (created == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
          content: Text(_communityText(
              context, 'تم نشر منشورك', 'Your post was published'))));
      load();
    } else {
      loadStatus();
    }
  }

  Widget suspensionBanner() {
    final isArabic = _isArabic(context);
    final until = DateTime.tryParse('${suspension['until']}')?.toLocal();
    final reason = '${suspension['reason'] ?? ''}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.warning)),
      child: Text(
          isArabic
              ? 'أنت موقوف عن النشر والتعليق والإبلاغ '
                  '${until == null ? 'حتى يرفعه فريق الإشراف' : 'حتى ${MaterialLocalizations.of(context).formatMediumDate(until)}'}.'
                  '${reason.isEmpty ? '' : ' السبب: $reason.'} ما زال بإمكانك القراءة.'
              : 'You cannot post, comment, or report '
                  '${until == null ? 'until moderation lifts the restriction' : 'until ${MaterialLocalizations.of(context).formatMediumDate(until)}'}.'
                  '${reason.isEmpty ? '' : ' Reason: $reason.'} You can still read.',
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
        title: _communityText(context, 'مجتمع الطلاب', 'Community'),
        showBackButton: !widget.embedded,
        actions: widget.actions,
        floatingActionButton: canWrite
            ? Padding(
                padding:
                    EdgeInsetsDirectional.only(end: widget.embedded ? 72 : 0),
                child: FloatingActionButton.extended(
                    heroTag: 'community-new-post',
                    key: const ValueKey('home-community-new-post'),
                    onPressed: compose,
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.navy,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                        _communityText(context, 'منشور جديد', 'New post'))))
            : null,
        body: RefreshIndicator(
            onRefresh: () async {
              setState(() => _bannerVersion++);
              await load();
            },
            child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverList.list(children: [
                    if (widget.header != null)
                      KeepAliveSection(child: widget.header!),
                    KeepAliveSection(
                        child: StudentBannerCarousel(
                            placement: 'community',
                            refreshVersion: _bannerVersion,
                            onExplore: _openAdDestination)),
                  ]),
                  SliverToBoxAdapter(child: _controls()),
                  if (loading || error != null || posts.isEmpty)
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: MediaQuery.sizeOf(context).height * .6,
                            child: _list()))
                  else
                    SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        sliver: SliverList.builder(
                            itemCount: posts.length,
                            itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _post(index)))),
                ])),
      );

  Widget _controls() => Column(
        mainAxisSize: MainAxisSize.min,
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
                  chip(_communityText(context, 'كل المنشورات', 'All posts'),
                      !mine && !adminOnly, () {
                    setState(() {
                      mine = false;
                      adminOnly = false;
                    });
                    load();
                  }),
                  chip(_communityText(context, 'منشوراتي', 'My posts'), mine,
                      () {
                    setState(() {
                      mine = true;
                      adminOnly = false;
                    });
                    load();
                  }),
                  chip(
                      _communityText(
                          context, 'منشورات الإدارة', 'Administration posts'),
                      adminOnly, () {
                    setState(() {
                      mine = false;
                      adminOnly = true;
                    });
                    load();
                  }),
                  if (!mine)
                    TextButton.icon(
                        onPressed: openFilters,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(activeFilters == 0
                            ? _communityText(context, 'تصفية', 'Filter')
                            : _communityText(context, 'تصفية ($activeFilters)',
                                'Filter ($activeFilters)'))),
                ]),
          ),
          if (!mine)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  chip(_communityText(context, 'الكل', 'All'), topic == null,
                      () {
                    setState(() => topic = null);
                    load();
                  }),
                  for (final entry in CommunityRepository.topicLabels(
                          arabic: _isArabic(context))
                      .entries)
                    chip(entry.value, topic == entry.key, () {
                      setState(() => topic = entry.key);
                      load();
                    }),
                ],
              ),
            ),
        ],
      );

  Widget _list() {
    if (loading) {
      return LoadingState(
          message: _communityText(
              context, 'جاري تحميل المجتمع...', 'Loading community...'));
    }
    if (error != null) return ErrorState(message: error!, onRetry: load);
    if (posts.isEmpty) {
      return EmptyState(
          icon: Icons.forum_outlined,
          title: mine
              ? _communityText(
                  context, 'لم تنشر أي منشور بعد', 'You have not posted yet')
              : _communityText(
                  context, 'لا توجد منشورات مطابقة', 'No matching posts'),
          message: mine
              ? _communityText(context, 'شارك تجربتك أو اسأل زملاءك الطلاب.',
                  'Share an experience or ask fellow students.')
              : _communityText(context, 'كن أول من يشارك في هذا القسم.',
                  'Be the first to share here.'),
          ctaLabel: canWrite
              ? _communityText(context, 'منشور جديد', 'New post')
              : null,
          onCta: canWrite ? compose : null);
    }
    return RefreshIndicator(
      onRefresh: load,
      color: AppColors.navy,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _post(index),
      ),
    );
  }

  Widget _post(int index) {
    final post = posts[index];
    return _PostCard(
        key: ValueKey('feed-post-${post['_id']}'),
        post: post,
        canReact: canWrite && post['status'] != 'hidden',
        onReaction: (result) {
          if (mounted) {
            final current =
                posts.indexWhere((item) => item['_id'] == post['_id']);
            if (current >= 0) {
              setState(() => posts[current] = {...posts[current], ...result});
            }
          }
        },
        onTap: post['status'] == 'hidden'
            ? null
            : () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CommunityThreadScreen(
                        postId: '${post['_id']}', canWrite: canWrite)));
                if (!mounted) return;
                load();
                loadStatus();
              });
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onTap;
  final bool canReact;
  final ValueChanged<Map<String, dynamic>>? onReaction;
  const _PostCard(
      {super.key,
      required this.post,
      this.onTap,
      this.canReact = false,
      this.onReaction});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool commentsOpen = false;
  Map<String, dynamic> get post => widget.post;

  @override
  Widget build(BuildContext context) {
    final hidden = post['status'] == 'hidden';
    final author = post['author'];
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: hidden ? AppColors.warning : AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudentIdentity(
                  id: _id(post['author']),
                  name: _communityName(author),
                  role: author is Map
                      ? '${author['role'] ?? 'student'}'
                      : 'student',
                  avatar: _communityAvatar(author),
                  organizationName:
                      author is Map && author['linkedUniversity'] is Map
                          ? '${author['linkedUniversity']['name'] ?? ''}'
                          : '',
                  organizationLogo:
                      author is Map && author['linkedUniversity'] is Map
                          ? '${author['linkedUniversity']['logo'] ?? ''}'
                          : '',
                  showRoleBadge: true),
              if (post['isAdminPost'] == true ||
                  author is Map && author['role'] == 'admin')
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                        backgroundColor: AppColors.greenSoft,
                        avatar: const Icon(Icons.verified_rounded,
                            color: AppColors.greenInk, size: 18),
                        label: Text(_communityText(
                            context, 'منشور الإدارة', 'Administration post')))),
              if (DateTime.tryParse('${post['createdAt']}') != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        MaterialLocalizations.of(context).formatMediumDate(
                            DateTime.parse('${post['createdAt']}').toLocal()),
                        style: AppTextStyles.caption)),
              if ('${post['title'] ?? ''}'.isNotEmpty)
                Text('${post['title']}', style: AppTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text('${post['body'] ?? ''}', style: AppTextStyles.body),
              const SizedBox(height: 8),
              Text(
                  [
                    '${post['commentCount'] ?? 0} ${isArabic ? 'تعليق' : 'comments'}',
                    _postMeta(post, arabic: isArabic),
                  ].where((p) => p.isNotEmpty).join(' · '),
                  style: AppTextStyles.caption),
              if (post['imagePath'] != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CommunityPostImage(
                            key: ValueKey('post-image-${post['_id']}'),
                            path: '${post['imagePath']}'))),
              const SizedBox(height: 8),
              CommunityReactions(
                  key: ValueKey('reactions-${post['_id']}'),
                  post: post,
                  enabled: widget.canReact,
                  buttonKey: ValueKey('community-like-${post['_id']}'),
                  onChanged: widget.onReaction ?? (_) {}),
              if (!hidden) ...[
                Row(children: [
                  TextButton.icon(
                    key: ValueKey('feed-comments-${post['_id']}'),
                    onPressed: () =>
                        setState(() => commentsOpen = !commentsOpen),
                    icon: Icon(commentsOpen
                        ? Icons.expand_less
                        : Icons.chat_bubble_outline),
                    label:
                        Text(_communityText(context, 'التعليقات', 'Comments')),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip:
                        _communityText(context, 'فتح المنشور', 'Open post'),
                    onPressed: widget.onTap,
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                ]),
                if (commentsOpen)
                  CommunityThreadScreen(
                    key: ValueKey('feed-thread-${post['_id']}'),
                    postId: '${post['_id']}',
                    canWrite: widget.canReact,
                    inline: true,
                    onPostChanged: widget.onReaction,
                  ),
              ],
              if (hidden) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      '${isArabic ? 'أخفاه فريق الإشراف' : 'Hidden by moderators'}${'${post['moderationNote'] ?? ''}'.isEmpty ? '' : ' — ${post['moderationNote']}'}',
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

/// Public, published posts belonging to this profile, never comment activity.
class CommunityAuthorPosts extends StatefulWidget {
  final String authorId;
  const CommunityAuthorPosts({super.key, required this.authorId});
  @override
  State<CommunityAuthorPosts> createState() => _CommunityAuthorPostsState();
}

class _CommunityAuthorPostsState extends State<CommunityAuthorPosts> {
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result =
          await CommunityRepository.instance.posts(author: widget.authorId);
      if (mounted) {
        setState(() {
          posts = result;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = communityError(e, 'تعذر تحميل المنشورات');
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_communityText(context, 'المنشورات', 'Posts'),
              style: AppTextStyles.sectionLabel),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            TextButton(onPressed: load, child: Text(error!))
          else if (posts.isEmpty)
            Text(_communityText(context, 'لا توجد منشورات بعد', 'No posts yet'))
          else
            GridView.builder(
              key: const ValueKey('profile-post-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return CommunityProfilePostTile(
                    post: post,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              CommunityThreadScreen(postId: '${post['_id']}')));
                      if (mounted) load();
                    });
              },
            ),
        ],
      );
}

/// Square preview; the full post opens on tap.
class CommunityProfilePostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  const CommunityProfilePostTile(
      {super.key, required this.post, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final title = '${post['title'] ?? ''}'.trim();
    final body = '${post['body'] ?? ''}'.trim();
    final image = '${post['imagePath'] ?? ''}'.trim();
    return Semantics(
      button: true,
      label: title.isEmpty ? body : title,
      child: Material(
        color: AppColors.greenSoft,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('profile-post-${post['_id']}'),
          onTap: onTap,
          child: image.isNotEmpty
              ? CommunityPostImage(path: image, thumbnail: true)
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: Center(
                      child: Text(title.isEmpty ? body : title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy)))),
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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_communityText(context, 'تصفية المنشورات', 'Filter posts'),
                  style: AppTextStyles.cardTitle),
              const SizedBox(height: 12),
              LookupDropdown(
                  label: _communityText(context, 'الدولة', 'Country'),
                  anyLabel:
                      _communityText(context, 'كل الدول', 'All countries'),
                  items: widget.countries,
                  value: country,
                  onChanged: (v) => setState(() {
                        country = v;
                        university = null;
                      })),
              LookupDropdown(
                  label: _communityText(context, 'الجامعة', 'University'),
                  anyLabel: _communityText(
                      context, 'كل الجامعات', 'All universities'),
                  items: universitiesIn(widget.universities, country),
                  value: university,
                  onChanged: (v) => setState(() => university = v)),
              LookupDropdown(
                  label: _communityText(context, 'التخصص', 'Study field'),
                  anyLabel: _communityText(
                      context, 'كل التخصصات', 'All study fields'),
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
                        child: Text(_communityText(context, 'مسح', 'Clear')))),
                const SizedBox(width: 12),
                Expanded(
                    child: FilledButton(
                        onPressed: () => Navigator.pop(context, {
                              'country': country,
                              'university': university,
                              'studyField': studyField
                            }),
                        child:
                            Text(_communityText(context, 'تطبيق', 'Apply')))),
              ]),
            ],
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
  bool busy = false, picking = false;
  bool _bodyTouched = false;
  Uint8List? _image;
  String? _imageName;
  String _operation = ApiClient.newOperationId();

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  bool get ready => body.text.trim().isNotEmpty;

  Future<void> _pickImage() async {
    if (busy || picking) return;
    final owner = AuthSession.instance.currentUser?.id;
    setState(() => picking = true);
    try {
      if (!await confirmGalleryAccess(context) || !mounted) return;
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85);
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw StateError('Image exceeds 5 MB');
      }
      final bytes = await file.readAsBytes();
      if (!mounted || owner != AuthSession.instance.currentUser?.id) return;
      final edited = await Navigator.of(context).push<EditedStoryPhoto>(
          MaterialPageRoute(
              builder: (_) => StoryPhotoEditor(bytes: bytes, forPost: true)));
      if (!mounted ||
          edited == null ||
          owner != AuthSession.instance.currentUser?.id) {
        return;
      }
      setState(() {
        _image = edited.image;
        _imageName = edited.imageName;
        _operation = ApiClient.newOperationId();
        error = null;
      });
    } catch (failure) {
      if (mounted) setState(() => error = mediaPickerError(failure));
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _editImage() async {
    if (busy || picking || _image == null) return;
    final owner = AuthSession.instance.currentUser?.id;
    setState(() => picking = true);
    try {
      final edited = await Navigator.of(context).push<EditedStoryPhoto>(
          MaterialPageRoute(
              builder: (_) => StoryPhotoEditor(bytes: _image!, forPost: true)));
      if (!mounted ||
          edited == null ||
          owner != AuthSession.instance.currentUser?.id) {
        return;
      }
      setState(() {
        _image = edited.image;
        _imageName = edited.imageName;
        _operation = ApiClient.newOperationId();
        error = null;
      });
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void _changed(VoidCallback update) {
    setState(() {
      update();
      _operation = ApiClient.newOperationId();
    });
  }

  Future<void> submit() async {
    if (busy || picking) return;
    if (!ready) {
      setState(() => _bodyTouched = true);
      return;
    }
    if (busy || !await requireCommunityTerms(context) || !mounted) return;
    if (busy || !ready) return;
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
          studyField: studyField,
          image: _image,
          imageName: _imageName,
          operationId: _operation);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Inputs are kept so the student can retry without retyping.
      if (mounted) {
        setState(() => error = communityError(
            e,
            _communityText(context, 'تعذر نشر المنشور. أعد المحاولة.',
                'Could not publish the post. Try again.'),
            creatingPost: true,
            arabic: _isArabic(context)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: _communityText(context, 'منشور جديد', 'New post'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
                _communityText(
                    context,
                    'شارك تجربتك أو سؤالك باحترام. المحتوى خاضع لمراجعة الفريق.',
                    'Share your experience or question respectfully. Posts are reviewed by the team.'),
                style: AppTextStyles.caption),
            const SizedBox(height: 12),
            TextField(
                controller: title,
                enabled: !busy,
                maxLength: 150,
                onChanged: (_) => _changed(() {}),
                decoration: InputDecoration(
                    labelText: _communityText(
                        context, 'العنوان (اختياري)', 'Title (optional)'))),
            TextField(
                key: const ValueKey('community-post-body'),
                controller: body,
                enabled: !busy,
                maxLength: 5000,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => _changed(() => _bodyTouched = true),
                decoration: InputDecoration(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_communityText(context, 'النص', 'Text')),
                      const SizedBox(width: 6),
                      Text(_communityText(context, '* إجباري', '* Required'),
                          key: const ValueKey('community-body-required'),
                          style: const TextStyle(color: AppColors.danger)),
                    ]),
                    helperText: _communityText(
                        context,
                        'اكتب نص المنشور لتفعيل زر النشر.',
                        'Write your post to enable Publish.'),
                    helperMaxLines: 2,
                    errorText: _bodyTouched && !ready
                        ? _communityText(
                            context,
                            'نص المنشور إجباري ولا يمكن أن يكون مسافات فقط.',
                            'Post text is required and cannot contain only spaces.')
                        : null,
                    errorMaxLines: 2)),
            if (_image != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_image!,
                          height: 200, fit: BoxFit.cover))),
            Wrap(spacing: 8, children: [
              if (_image != null)
                OutlinedButton.icon(
                    key: const ValueKey('community-edit-photo'),
                    onPressed: busy || picking ? null : _editImage,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                        _communityText(context, 'تعديل الصورة', 'Edit photo'))),
              OutlinedButton.icon(
                  onPressed: busy || picking ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_communityText(context, 'إضافة صورة (اختياري)',
                      'Add photo (optional)'))),
              if (_image != null)
                TextButton(
                    onPressed: busy || picking
                        ? null
                        : () => setState(() {
                              _image = null;
                              _imageName = null;
                              _operation = ApiClient.newOperationId();
                            }),
                    child: Text(_communityText(
                        context, 'إزالة الصورة', 'Remove photo'))),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: topic,
              decoration: InputDecoration(
                  labelText: _communityText(context, 'التصنيف', 'Topic'),
                  helperText: _communityText(
                      context,
                      'محدد مسبقًا، ويمكنك تغييره.',
                      'Preselected; you can change it.')),
              items: [
                for (final entry in CommunityRepository.topicLabels(
                        arabic: _isArabic(context))
                    .entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) => _changed(() => topic = v ?? topic),
            ),
            const SizedBox(height: 12),
            LookupDropdown(
                label: _communityText(
                    context, 'التخصص (اختياري)', 'Study field (optional)'),
                anyLabel:
                    _communityText(context, 'بدون تخصص', 'No study field'),
                items: widget.fields,
                value: studyField,
                onChanged: (v) => _changed(() => studyField = v)),
            LookupDropdown(
                label: _communityText(
                    context, 'الدولة (اختياري)', 'Country (optional)'),
                anyLabel: _communityText(context, 'بدون دولة', 'No country'),
                items: widget.countries,
                value: country,
                onChanged: (v) => _changed(() {
                      country = v;
                      university = null;
                    })),
            LookupDropdown(
                label: _communityText(
                    context, 'الجامعة (اختياري)', 'University (optional)'),
                anyLabel:
                    _communityText(context, 'بدون جامعة', 'No university'),
                items: universitiesIn(widget.universities, country),
                value: university,
                onChanged: (v) => _changed(() => university = v)),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InlineNotice(error!, error: true)),
            FilledButton(
                onPressed: busy || picking || !ready ? null : submit,
                child: Text(busy
                    ? _communityText(context, 'جارٍ النشر...', 'Publishing...')
                    : _communityText(context, 'نشر', 'Publish'))),
          ],
        ),
      );
}

class CommunityThreadScreen extends StatefulWidget {
  final String postId;

  /// False for a suspended student: reading only, no comment/report controls.
  final bool canWrite;
  final bool inline;
  final ValueChanged<Map<String, dynamic>>? onPostChanged;
  const CommunityThreadScreen(
      {super.key,
      required this.postId,
      this.canWrite = true,
      this.inline = false,
      this.onPostChanged});
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
        post = Json.map(data['post']);
        comments = data['comments'] as List<Map<String, dynamic>>;
      });
      widget.onPostChanged?.call({...post!, 'commentCount': comments.length});
    } catch (e) {
      if (mounted) {
        setState(() => error = communityError(e, 'تعذر فتح المنشور.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void toast(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(AppSnackBar(content: Text(text)));

  Future<void> run(Future<void> Function() action, String done, String failed,
      {bool reload = true}) async {
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      toast(done);
      if (reload) await load();
    } catch (e) {
      if (mounted) toast(communityError(e, failed, arabic: _isArabic(context)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendComment() async {
    if (busy || !await requireCommunityTerms(context) || !mounted) return;
    if (busy || commentText.text.trim().isEmpty) return;
    await run(() async {
      await repo.comment(widget.postId, commentText.text);
      commentText.clear();
    }, 'تمت إضافة تعليقك', 'تعذر إضافة التعليق.');
  }

  Future<void> editPost() async {
    if (!widget.canWrite) return;
    final current = post;
    if (current == null) return;
    final values = await _askCommunityEdit(context,
        title: '${current['title'] ?? ''}', body: '${current['body'] ?? ''}');
    if (values == null || !mounted) return;
    await run(
        () => repo.editPost(widget.postId,
            title: values['title']!, body: values['body']!),
        'تم تحديث منشورك',
        'تعذر تعديل المنشور.');
  }

  Future<void> editComment(Map<String, dynamic> comment) async {
    if (!widget.canWrite) return;
    final values = await _askCommunityEdit(context,
        body: '${comment['body'] ?? ''}', commentOnly: true);
    if (values == null || !mounted) return;
    await run(() => repo.editComment('${comment['_id']}', values['body']!),
        'تم تحديث تعليقك', 'تعذر تعديل التعليق.');
  }

  Future<void> deletePost() async {
    final ok = await showAppConfirmDialog(context,
        title: _communityText(context, 'حذف المنشور', 'Delete post'),
        message: _communityText(context, 'سيُحذف المنشور وكل تعليقاته نهائيًا.',
            'This post and all its comments will be deleted permanently.'),
        confirmLabel: _communityText(context, 'حذف', 'Delete'),
        danger: true);
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await repo.deletePost(widget.postId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        toast(
            communityError(e, 'تعذر حذف المنشور.', arabic: _isArabic(context)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteComment(Map<String, dynamic> comment) async {
    final ok = await showAppConfirmDialog(context,
        title: _communityText(context, 'حذف التعليق', 'Delete comment'),
        message: _communityText(context, 'سيُحذف تعليقك نهائيًا.',
            'Your comment will be deleted permanently.'),
        confirmLabel: _communityText(context, 'حذف', 'Delete'),
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
        _communityText(context, 'شكرًا، وصل بلاغك لفريق الإشراف',
            'Thanks, your report was sent to the moderation team.'),
        _communityText(
            context, 'تعذر إرسال البلاغ.', 'Could not send the report.'),
        reload: false);
  }

  Widget ownerAction(Map<String, dynamic> item, String type) => !_isMine(
              item) &&
          !widget.canWrite
      ? const SizedBox(height: 8)
      : _isMine(item)
          ? Wrap(spacing: 4, children: [
              TextButton.icon(
                onPressed: busy || !widget.canWrite
                    ? null
                    : () => type == 'post' ? editPost() : editComment(item),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(type == 'post'
                    ? _communityText(context, 'تعديل منشوري', 'Edit my post')
                    : _communityText(
                        context, 'تعديل تعليقي', 'Edit my comment')),
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => type == 'post' ? deletePost() : deleteComment(item),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(type == 'post'
                    ? _communityText(context, 'حذف منشوري', 'Delete my post')
                    : _communityText(
                        context, 'حذف تعليقي', 'Delete my comment')),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ])
          : TextButton.icon(
              onPressed: busy ? null : () => report(type, '${item['_id']}'),
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text(_communityText(context, 'إبلاغ', 'Report')),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary));

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? const LoadingState()
        : error != null
            ? ErrorState(message: error!, onRetry: load)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                _expandThread(
                  child: RefreshIndicator(
                    onRefresh: load,
                    color: AppColors.navy,
                    child: ListView(
                      shrinkWrap: widget.inline,
                      physics: widget.inline
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (!widget.inline) ...[
                          Text('${post!['title'] ?? ''}',
                              style: AppTextStyles.screenTitle),
                          const SizedBox(height: 4),
                          StudentIdentity(
                              id: _id(post!['author']),
                              name: _communityName(post!['author']),
                              role: post!['author'] is Map
                                  ? '${post!['author']['role'] ?? 'student'}'
                                  : 'student',
                              avatar: post!['author'] is Map
                                  ? '${post!['author']['avatar'] ?? ''}'
                                  : '',
                              organizationName: post!['author'] is Map &&
                                      post!['author']['linkedUniversity'] is Map
                                  ? '${post!['author']['linkedUniversity']['name'] ?? ''}'
                                  : '',
                              organizationLogo: post!['author'] is Map &&
                                      post!['author']['linkedUniversity'] is Map
                                  ? '${post!['author']['linkedUniversity']['logo'] ?? ''}'
                                  : '',
                              showRoleBadge: true),
                          Text(
                              [_postMeta(post!, arabic: _isArabic(context))]
                                  .where((p) => p.isNotEmpty)
                                  .join(' · '),
                              style: AppTextStyles.caption),
                          const SizedBox(height: 12),
                          Text('${post!['body'] ?? ''}',
                              style: AppTextStyles.body),
                          if (post!['imagePath'] != null)
                            CommunityPostImage(
                                key: ValueKey('thread-image-${post!['_id']}'),
                                path: '${post!['imagePath']}'),
                          CommunityReactions(
                              key: ValueKey('thread-reactions-${post!['_id']}'),
                              post: post!,
                              enabled: widget.canWrite && !busy,
                              buttonKey:
                                  const ValueKey('community-thread-like'),
                              onChanged: (result) {
                                if (mounted) {
                                  setState(() => post = {...post!, ...result});
                                }
                              }),
                          Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ownerAction(post!, 'post')),
                          const Divider(height: 24),
                        ],
                        Text(
                            _communityText(
                                context,
                                'التعليقات (${comments.length})',
                                'Comments (${comments.length})'),
                            style: AppTextStyles.sectionLabel),
                        const SizedBox(height: 8),
                        if (comments.isEmpty)
                          Text(
                              _communityText(
                                  context,
                                  'لا توجد تعليقات بعد. شارك برأيك.',
                                  'No comments yet. Share your thoughts.'),
                              style: AppTextStyles.caption),
                        for (final comment in comments)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StudentIdentity(
                                    id: _id(comment['author']),
                                    name: _communityName(comment['author']),
                                    role: comment['author'] is Map
                                        ? '${comment['author']['role'] ?? 'student'}'
                                        : 'student',
                                    avatar: comment['author'] is Map
                                        ? '${comment['author']['avatar'] ?? ''}'
                                        : '',
                                    organizationName: comment['author']
                                                is Map &&
                                            comment['author']
                                                ['linkedUniversity'] is Map
                                        ? '${comment['author']['linkedUniversity']['name'] ?? ''}'
                                        : '',
                                    organizationLogo: comment['author']
                                                is Map &&
                                            comment['author']
                                                ['linkedUniversity'] is Map
                                        ? '${comment['author']['linkedUniversity']['logo'] ?? ''}'
                                        : '',
                                    showRoleBadge: true),
                                const SizedBox(height: 2),
                                Text('${comment['body'] ?? ''}',
                                    style: AppTextStyles.body),
                                Align(
                                    alignment: AlignmentDirectional.centerEnd,
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
                                decoration: InputDecoration(
                                    hintText: _communityText(context,
                                        'أضف تعليقًا', 'Add a comment'),
                                    counterText: ''))),
                        const SizedBox(width: 8),
                        IconButton.filled(
                            tooltip: _communityText(context, 'إرسال', 'Send'),
                            onPressed: busy || commentText.text.trim().isEmpty
                                ? null
                                : sendComment,
                            icon: const Icon(Icons.send_rounded)),
                      ]),
                    ),
                  ),
              ]);
    if (widget.inline) return content;
    return AppScaffold(
        title: _communityText(context, 'المنشور', 'Post'), body: content);
  }

  Widget _expandThread({required Widget child}) =>
      widget.inline ? child : Expanded(child: child);
}

/// Returns {'reason', 'details'} or null when cancelled.
Future<Map<String, String>?> _askCommunityEdit(BuildContext context,
    {required String body, String title = '', bool commentOnly = false}) async {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (_) => _CommunityEditDialog(
      title: title,
      body: body,
      commentOnly: commentOnly,
    ),
  );
}

class _CommunityEditDialog extends StatefulWidget {
  final String title;
  final String body;
  final bool commentOnly;

  const _CommunityEditDialog({
    required this.title,
    required this.body,
    required this.commentOnly,
  });

  @override
  State<_CommunityEditDialog> createState() => _CommunityEditDialogState();
}

class _CommunityEditDialogState extends State<_CommunityEditDialog> {
  late final TextEditingController titleController;
  late final TextEditingController bodyController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.title);
    bodyController = TextEditingController(text: widget.body);
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic(context);
    return AlertDialog(
      title: Text(widget.commentOnly
          ? (isArabic ? 'تعديل التعليق' : 'Edit comment')
          : (isArabic ? 'تعديل المنشور' : 'Edit post')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!widget.commentOnly) ...[
            TextField(
              controller: titleController,
              maxLength: 150,
              decoration:
                  InputDecoration(labelText: isArabic ? 'العنوان' : 'Title'),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: bodyController,
            maxLength: widget.commentOnly ? 2000 : 5000,
            minLines: widget.commentOnly ? 2 : 4,
            maxLines: 7,
            decoration: InputDecoration(labelText: isArabic ? 'النص' : 'Text'),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel')),
        FilledButton(
          onPressed: () {
            final nextBody = bodyController.text.trim();
            final nextTitle = titleController.text.trim();
            if (nextBody.isEmpty) {
              return;
            }
            Navigator.pop(context, {
              'body': nextBody,
              if (!widget.commentOnly) 'title': nextTitle,
            });
          },
          child: Text(isArabic ? 'حفظ' : 'Save'),
        ),
      ],
    );
  }
}

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
        textDirection:
            _isArabic(context) ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          scrollable: true,
          title: Text(
              _communityText(context, 'الإبلاغ عن محتوى', 'Report content')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  _communityText(
                      context,
                      'سيراجع فريق الإشراف البلاغ. لن يظهر اسمك لكاتب المحتوى.',
                      'The moderation team will review this report. Your name will not be shown to the author.'),
                  style: AppTextStyles.caption),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => setState(() => reason = v),
                child: Column(children: [
                  for (final entry in CommunityRepository.reportReasonLabels(
                          arabic: _isArabic(context))
                      .entries)
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
                  decoration: InputDecoration(
                      labelText: _communityText(
                          context, 'تفاصيل (اختياري)', 'Details (optional)'))),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_communityText(context, 'إلغاء', 'Cancel'))),
            FilledButton(
                onPressed: reason == null
                    ? null
                    : () => Navigator.pop(
                        context, {'reason': reason!, 'details': details.text}),
                child: Text(
                    _communityText(context, 'إرسال البلاغ', 'Send report'))),
          ],
        ),
      );
}
