import '../../core/utils/json_safe.dart';
import '../../core/services/error_reporter.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/widgets/app_notice.dart';
import 'dart:math' as math;
import '../../core/services/auth_session.dart';
import '../applications_documents_payments/program_application_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_theme.dart';
import '../../core/repositories/catalog_repository.dart';
import '../../core/repositories/student_repository.dart';
import 'catalog_browser.dart';
import 'catalog_language.dart';
import 'compare_list_screen.dart';

String? catalogAssetUrl(dynamic value) {
  final raw = catalogText(value);
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  final resolved = Uri.parse(ApiClient.baseUrl)
      .replace(path: '/', query: null, fragment: null)
      .resolveUri(uri);
  return ['http', 'https'].contains(resolved.scheme)
      ? resolved.toString()
      : null;
}

List<String> catalogImages(Map<String, dynamic> data, bool university) {
  final uni = university ? data : catalogMap(data['university']);
  final campus = uni['campusImages'];
  final photos = <String>{
    if (!university)
      if (catalogAssetUrl(data['coverImage']) case final url?) url,
    if (campus is List)
      for (final value in campus)
        if (catalogAssetUrl(value) case final url?) url,
  }.toList();
  return photos;
}

class CatalogDetailPage extends StatefulWidget {
  final String id;
  final bool university;
  final Map<String, dynamic>? initialData;
  const CatalogDetailPage(
      {super.key, required this.id, this.university = false, this.initialData});
  @override
  State<CatalogDetailPage> createState() => _CatalogDetailPageState();
}

class _CatalogDetailPageState extends State<CatalogDetailPage> {
  Map<String, dynamic>? data;
  bool loading = true, favorite = false, savingFavorite = false;
  String? error;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    data = widget.initialData;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = widget.university
          ? await CatalogRepository.instance.getUniversityById(widget.id)
          : await CatalogRepository.instance.getProgramById(widget.id);
      if (mounted) setState(() => data = result);
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/universities_programs_countries/catalog_detail.dart:74');
      if (mounted) {
        setState(() => error =
            cl('تعذر تحميل التفاصيل الكاملة. اسحب للتحديث أو أعد المحاولة.', 'Could not load the full details. Pull to refresh or retry.'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleFavorite() async {
    setState(() => savingFavorite = true);
    try {
      await StudentRepository.instance.toggleFavorite(
          itemType: widget.university ? 'university' : 'program',
          universityId: widget.university ? widget.id : null,
          programId: widget.university ? null : widget.id);
      if (mounted) setState(() => favorite = !favorite);
    } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/universities_programs_countries/catalog_detail.dart:92');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            AppSnackBar(content: Text(cl('تعذر تحديث المفضلة. حاول مجددًا.', 'Could not update favorites. Try again.'))));
      }
    } finally {
      if (mounted) setState(() => savingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = data;
    return CatalogLanguageBuilder(builder: (_) => _buildPage(row));
  }

  Widget _buildPage(Map<String, dynamic>? row) {
    return AppScaffold(
        textDirection: CatalogLanguage.instance.direction,
        title: widget.university
            ? cl('تفاصيل الجامعة', 'University details')
            : cl('تفاصيل البرنامج', 'Program details'),
        actions: [
          IconButton(
              tooltip: cl('المفضلة', 'Favorites'),
              onPressed: savingFavorite ? null : toggleFavorite,
              icon: Icon(favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded)),
          const CatalogLanguageToggle(),
        ],
        body: row == null
            ? loading
                ? const LoadingState()
                : ErrorState(
                    message: error ?? cl('تعذر تحميل التفاصيل', 'Could not load the details'), onRetry: load)
            : Column(children: [
                if (loading) const LinearProgressIndicator(minHeight: 2),
                if (widget.university)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(children: [
                        for (final entry
                            in {0: cl('عن الجامعة', 'About'), 1: cl('البرامج', 'Programs')}.entries)
                          Expanded(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: ChoiceChip(
                                      label: Center(child: Text(entry.value)),
                                      selected: tab == entry.key,
                                      showCheckmark: false,
                                      selectedColor: AppColors.navy,
                                      labelStyle: TextStyle(
                                          color: tab == entry.key
                                              ? Colors.white
                                              : AppColors.navy),
                                      onSelected: (_) =>
                                          setState(() => tab = entry.key)))),
                      ])),
                Expanded(
                    child: IndexedStack(index: tab, children: [
                  RefreshIndicator(
                      onRefresh: load,
                      color: AppColors.navy,
                      child: ListView(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (error != null)
                              AppCard(
                                  child: Column(children: [
                                InlineNotice(error!, error: true),
                                TextButton(
                                    onPressed: load,
                                    child: Text(cl('إعادة المحاولة', 'Retry')))
                              ])),
                            _DetailGallery(
                                key: ValueKey(
                                    '${widget.id}:${catalogImages(row, widget.university).join()}'),
                                urls: catalogImages(row, widget.university)),
                            const SizedBox(height: 16),
                            _heading(row),
                            const SizedBox(height: 8),
                            _facts(row),
                            if (catalogLocalizedText(row,
                                    widget.university ? 'overview' : 'summary')
                                .isNotEmpty)
                              _section(
                                  widget.university
                                      ? cl('نبذة عن الجامعة', 'About the university')
                                      : cl('عن البرنامج', 'About the program'),
                                  _ArticleText(catalogLocalizedText(
                                      row,
                                      widget.university
                                          ? 'overview'
                                          : 'summary'))),
                            if (!widget.university &&
                                catalogFields(row).isNotEmpty)
                              _section(
                                  cl('المجالات الدراسية', 'Fields of study'),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    for (final field in catalogFields(row))
                                      StatusBadge(
                                          label: catalogValue(field), color: AppColors.navy)
                                  ])),
                            if (!widget.university &&
                                row['requirements'] is List &&
                                (Json.list(row['requirements'])).isNotEmpty)
                              _section(
                                  cl('شروط القبول', 'Admission requirements'),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final item
                                            in Json.list(row['requirements']))
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        size: 18,
                                                        color:
                                                            AppColors.orange),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                        child: _ArticleText(
                                                            CatalogLanguage.instance.tr('$item'))),
                                                  ])),
                                      ])),
                            // PRD 21: careers, same program elsewhere, related programs.
                            if (!widget.university) ..._programExtras(row),
                            ...catalogArticleSections(row),
                            if (!widget.university &&
                                AuthSession.instance.currentUser?.role ==
                                    UserRole.student)
                              PrimaryButton(
                                  label: cl('التقديم على البرنامج', 'Apply to this program'),
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              ProgramApplicationScreen(
                                                  programId: widget.id)))),
                            if (widget.university)
                              OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const CompareListScreen())),
                                  icon: const Icon(Icons.compare_arrows),
                                  label: Text(cl('مقارنة الجامعات', 'Compare universities'))),
                            const SizedBox(height: 16),
                          ])),
                  if (widget.university)
                    CatalogBrowser(
                        universityId: widget.id,
                        onOpen: (p) => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => CatalogDetailPage(
                                    id: p['_id'] as String, initialData: p)))),
                ])),
              ]));
  }

  Widget _heading(Map<String, dynamic> row) {
    final uni = widget.university ? row : catalogMap(row['university']);
    final country = catalogCountryName(catalogMap(uni['country']));
    final location = [catalogValue(catalogText(uni['city'])), country]
        .where((s) => s.isNotEmpty)
        .join(cl('، ', ', '));
    final logo = catalogAssetUrl(uni['logo']);
    final name = catalogName(row, widget.university ? 'name' : 'title');
    final uniName = catalogName(uni, 'name');
    return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.university && logo != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
                width: 64,
                height: 64,
                child: _RemotePhoto(url: logo, fit: BoxFit.contain))),
      Text(name, style: AppTextStyles.screenTitle.copyWith(height: 1.5)),
      const SizedBox(height: 10),
      if (!widget.university && uniName.isNotEmpty)
        InkWell(
            onTap: uni['_id'] is String
                ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CatalogDetailPage(
                        id: uni['_id'], university: true, initialData: uni)))
                : null,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  if (logo != null)
                    SizedBox(
                        width: 40,
                        height: 40,
                        child: _RemotePhoto(url: logo, fit: BoxFit.contain)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(uniName, style: AppTextStyles.cardTitle)),
                  Icon(
                      CatalogLanguage.instance.english
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      textDirection: TextDirection.ltr),
                ]))),
      if (location.isNotEmpty)
        Row(children: [
          const Icon(Icons.location_on_outlined,
              size: 18, color: AppColors.orange),
          const SizedBox(width: 6),
          Expanded(child: Text(location, style: AppTextStyles.body))
        ]),
      if (widget.university && row['isPartnerInstitution'] == true)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: StatusBadge(
                label: cl('جامعة شريكة', 'Partner university'),
                color: AppColors.success)),
    ]));
  }

  Widget _facts(Map<String, dynamic> row) {
    final range = catalogMap(row['tuitionRange']);
    final date = DateTime.tryParse('${row['applicationDeadline']}');
    final notPublished = cl('غير معلنة', 'Not published');
    final facts = <String, String>{
      if (!widget.university)
        cl('الدرجة العلمية', 'Degree level'):
            catalogValue(catalogText(row['degreeLevel'])),
      cl('لغة الدراسة', 'Study language'):
          catalogValue(catalogText(row['language'])),
      if (!widget.university)
        cl('مدة الدراسة', 'Duration'):
            catalogValue(catalogText(row['duration'])),
      cl('الرسوم الدراسية', 'Tuition fees'): widget.university
          ? range['min'] == null && range['max'] == null
              ? notPublished
              : range['max'] == null
                  ? '${cl('تبدأ من', 'From')} ${range['min']} USD'
                  : range['min'] == null
                      ? '${cl('حتى', 'Up to')} ${range['max']} USD'
                      : '${range['min']} – ${range['max']} USD'
          : row['tuition'] == null
              ? notPublished
              : '${row['tuition']} USD',
      if (!widget.university)
        cl('موعد الالتحاق', 'Intake'): catalogValue(catalogText(row['intake'])),
      if (date != null)
        cl('آخر موعد للتقديم', 'Application deadline'):
            '${date.day}/${date.month}/${date.year}',
      if (widget.university && row['ranking'] is num && row['ranking'] > 0)
        cl('التصنيف', 'Ranking'): '${row['ranking']}',
      if (widget.university &&
          row['studentCount'] is num &&
          row['studentCount'] > 0)
        cl('عدد الطلاب', 'Students'): '${row['studentCount']}',
      if (widget.university &&
          row['specialtyCount'] is num &&
          row['specialtyCount'] > 0)
        cl('عدد التخصصات', 'Specialties'): '${row['specialtyCount']}',
    }..removeWhere((_, v) => v.isEmpty);
    return LayoutBuilder(
        builder: (_, constraints) =>
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final f in facts.entries)
                SizedBox(
                    width: constraints.maxWidth < 340
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2,
                    child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(14)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.key, style: AppTextStyles.caption),
                              const SizedBox(height: 6),
                              Text(f.value, style: AppTextStyles.cardTitle)
                            ]))),
            ]));
  }

  List<Widget> _programExtras(Map<String, dynamic> row) {
    List<Map<String, dynamic>> rows(dynamic value) => value is List
        ? value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const [];
    final careers = (row['careerOpportunities'] is List)
        ? (Json.list(row['careerOpportunities']))
            .map((e) => '$e')
            .where((e) => e.trim().isNotEmpty)
            .toList()
        : const <String>[];
    final offeredAt = rows(row['offeredAt']);
    final related = rows(row['relatedPrograms']);
    // InkWell rather than ListTile: sections have a painted background that
    // would hide a ListTile's ink.
    Widget link(Map<String, dynamic> item, String title, String subtitle) =>
        InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CatalogDetailPage(id: '${item['_id']}'))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: AppTextStyles.caption),
                    ])),
                const Icon(Icons.chevron_left, color: AppColors.textSecondary),
              ]),
            ));
    return [
      if (careers.isNotEmpty)
        _section(
            cl('مجالات العمل بعد التخرج', 'Career opportunities'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final career in careers)
                StatusBadge(label: CatalogLanguage.instance.tr(career), color: AppColors.navy)
            ])),
      if (offeredAt.isNotEmpty)
        _section(
            cl('جامعات أخرى تقدّم البرنامج', 'Other universities offering this program'),
            Column(children: [
              for (final item in offeredAt)
                link(
                    item,
                    catalogName(catalogMap(item['university']), 'name'),
                    [
                      catalogMap(item['university'])['city'],
                      catalogCountryName(catalogMap(
                          catalogMap(item['university'])['country'])),

                    ].where((e) => e != null && '$e'.isNotEmpty).join(cl('، ', ', ')))
            ])),
      if (related.isNotEmpty)
        _section(
            cl('برامج ذات صلة', 'Related programs'),
            Column(children: [
              for (final item in related)
                link(item, catalogName(item, 'title'),
                    catalogName(catalogMap(item['university']), 'name'))
            ])),
    ];
  }

  Widget _section(String title, Widget body) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: AppTextStyles.cardTitle.copyWith(color: AppColors.navy)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: AppCard(child: body)),
      ]));
}

List<Widget> catalogArticleSections(Map<String, dynamic> row) {
  final headings = catalogLocalizedList(row, 'articleHeadings');
  final bodies = catalogLocalizedList(row, 'articleBodies');
  final title = catalogLocalizedText(row, 'articleTitle');
  if (title.isEmpty &&
      headings.every((v) => catalogText(v).isEmpty) &&
      bodies.every((v) => catalogText(v).isEmpty)) {
    return [];
  }
  return [
    Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(title.isEmpty ? cl('دليل الدراسة', 'Study guide') : title,
            style: AppTextStyles.screenTitle)),
    for (var i = 0; i < math.max(headings.length, bodies.length); i++)
      if ((i < headings.length && catalogText(headings[i]).isNotEmpty) ||
          (i < bodies.length && catalogText(bodies[i]).isNotEmpty))
        AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (i < headings.length && catalogText(headings[i]).isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(catalogText(headings[i]),
                    style: AppTextStyles.cardTitle
                        .copyWith(color: AppColors.navy, height: 1.5))),
          if (i < bodies.length && catalogText(bodies[i]).isNotEmpty)
            _ArticleText(catalogText(bodies[i])),
        ])),
  ];
}

class _ArticleText extends StatelessWidget {
  final String text;
  const _ArticleText(this.text);
  @override
  Widget build(BuildContext context) {
    final matches =
        RegExp(r'\[button:(.*?)\|(https?://[^\]\s]+)\]').allMatches(text);
    final children = <Widget>[];
    var end = 0;
    for (final match in matches) {
      if (match.start > end) {
        children.add(SelectableText(text.substring(end, match.start),
            style: AppTextStyles.body.copyWith(height: 1.9)));
      }
      children.add(TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(match.group(1)!),
          onPressed: () async {
            try {
              if (!await launchUrl(Uri.parse(match.group(2)!),
                  mode: LaunchMode.externalApplication)) {
                throw Exception();
              }
            } catch (swallowedError, swallowedStack) { ErrorReporter.swallowed(swallowedError, swallowedStack, 'screens/universities_programs_countries/catalog_detail.dart:522');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    AppSnackBar(content: Text(cl('تعذر فتح الرابط.', 'Could not open the link.'))));
              }
            }
          }));
      end = match.end;
    }
    if (end < text.length) {
      children.add(SelectableText(text.substring(end),
          style: AppTextStyles.body.copyWith(height: 1.9)));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _RemotePhoto extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const _RemotePhoto({required this.url, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) => AppNetworkImage(
      url,
      fit: fit,
      width: double.infinity,
      errorWidget: LayoutBuilder(
          builder: (_, constraints) => Center(
              child: constraints.maxHeight < 80
                  ? const Icon(Icons.broken_image_outlined,
                      color: AppColors.textSecondary)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image_outlined,
                          color: AppColors.textSecondary),
                      SizedBox(height: 6),
                      Text(cl('تعذر تحميل الصورة', 'Could not load the image'), style: AppTextStyles.caption)
                    ]))));
}

class _DetailGallery extends StatefulWidget {
  final List<String> urls;
  const _DetailGallery({super.key, required this.urls});
  @override
  State<_DetailGallery> createState() => _DetailGalleryState();
}

class _DetailGalleryState extends State<_DetailGallery> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
              height: 210,
              child: Stack(fit: StackFit.expand, children: [
                PageView.builder(
                    itemCount: widget.urls.length,
                    onPageChanged: (i) => setState(() => selected = i),
                    itemBuilder: (_, i) => GestureDetector(
                        onTap: () => showDialog(
                            context: context,
                            builder: (_) => Dialog.fullscreen(
                                child: Scaffold(
                                    backgroundColor: AppColors.navy,
                                    appBar: AppBar(
                                        title: Text('${cl('الصورة', 'Image')} ${i + 1}'),
                                        backgroundColor: AppColors.navy,
                                        foregroundColor: Colors.white),
                                    body: InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: Center(
                                            child: _RemotePhoto(
                                                url: widget.urls[i],
                                                fit: BoxFit.contain)))))),
                        child: _RemotePhoto(url: widget.urls[i]))),
                Positioned(
                    bottom: 12,
                    left: 12,
                    child: IgnorePointer(
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: .85),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(
                                '${selected + 1} / ${widget.urls.length}',
                                style: const TextStyle(color: Colors.white))))),
              ]))),
      if (widget.urls.length > 1)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(cl('اسحب لاستعراض الصور • اضغط للتكبير', 'Swipe to browse • tap to zoom'),
                style: AppTextStyles.caption)),
    ]);
  }
}
