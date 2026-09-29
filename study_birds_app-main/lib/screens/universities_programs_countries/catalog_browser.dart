import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/catalog_repository.dart';
import '../../core/favorites_service.dart';

String catalogText(dynamic value) => value is String ? value.trim() : '';
Map<String, dynamic> catalogMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
String catalogFacet(Map<String, dynamic> row, String key, bool universities) {
  final uni = universities ? row : catalogMap(row['university']);
  if (key == 'country') return catalogText(catalogMap(uni['country'])['name']);
  if (key == 'university') return catalogText(uni['name']);
  if (key == 'city') return catalogText(uni['city']);
  return catalogText(row[key]);
}

List<String> catalogFields(Map<String, dynamic> row) => {
      catalogText(row['fieldOfStudy']),
      if (row['fieldsOfStudy'] is List)
        ...(row['fieldsOfStudy'] as List)
            .whereType<String>()
            .map((s) => s.trim()),
    }.where((s) => s.isNotEmpty).toList();
num? catalogTuition(Map<String, dynamic> row, bool universities) {
  final value =
      universities ? catalogMap(row['tuitionRange'])['min'] : row['tuition'];
  return value is num && value >= 0 ? value : null;
}

class CatalogSelection {
  final Map<String, String> facets;
  final num? maxTuition;
  final bool partnerOnly;
  final String sort;
  const CatalogSelection(
      {this.facets = const {},
      this.maxTuition,
      this.partnerOnly = false,
      this.sort = 'default'});
  int get count =>
      facets.length +
      (maxTuition == null ? 0 : 1) +
      (partnerOnly ? 1 : 0) +
      (sort == 'default' ? 0 : 1);
}

List<Map<String, dynamic>> filterCatalog(List<Map<String, dynamic>> rows,
    CatalogSelection selection, String query, bool universities) {
  final q = query.trim().toLowerCase();
  final result = rows.where((row) {
    final words = [
      row['title'],
      row['name'],
      catalogFacet(row, 'university', universities),
      catalogFacet(row, 'country', universities),
      catalogFacet(row, 'city', universities),
      row['degreeLevel'],
      row['language'],
      ...catalogFields(row)
    ].join(' ').toLowerCase();
    if (q.isNotEmpty && !words.contains(q)) return false;
    for (final entry in selection.facets.entries) {
      if (entry.key == 'fieldOfStudy') {
        if (!catalogFields(row).contains(entry.value)) return false;
      } else if (catalogFacet(row, entry.key, universities) != entry.value) {
        return false;
      }
    }
    if (selection.partnerOnly && row['isPartnerInstitution'] != true) {
      return false;
    }
    if (selection.maxTuition != null) {
      final fee = catalogTuition(row, universities);
      if (fee == null || fee > selection.maxTuition!) return false;
    }
    return true;
  }).toList();
  if (selection.sort == 'name') {
    result.sort((a, b) => catalogText(a[universities ? 'name' : 'title'])
        .compareTo(catalogText(b[universities ? 'name' : 'title'])));
  } else if (selection.sort == 'fee') {
    result.sort((a, b) => (catalogTuition(a, universities) ?? double.infinity)
        .compareTo(catalogTuition(b, universities) ?? double.infinity));
  }
  return result;
}

List<String> catalogFacetOptions(
    String key,
    List<String> order,
    Map<String, String> selected,
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> countries,
    List<Map<String, dynamic>> universities,
    bool isUniversityList) {
  if (key == 'country') {
    return ({
      for (final c in countries) catalogText(c['name']),
      for (final row in rows) catalogFacet(row, 'country', isUniversityList)
    }..remove(''))
        .toList()
      ..sort();
  }
  final parents = <String, String>{
    for (final parent in order.take(order.indexOf(key)))
      if (selected[parent] != null) parent: selected[parent]!
  };
  final source = key == 'university' ? universities : rows;
  final candidates = filterCatalog(source, CatalogSelection(facets: parents),
      '', key == 'university' || isUniversityList);
  return ({
    for (final row in candidates)
      if (key == 'fieldOfStudy')
        ...catalogFields(row)
      else
        catalogFacet(row, key, key == 'university' || isUniversityList)
  }..remove(''))
      .toList()
    ..sort();
}

class CatalogBrowser extends StatefulWidget {
  final bool universities, finder;
  final String? countryId, universityId;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback? onOrientation;
  const CatalogBrowser(
      {super.key,
      this.universities = false,
      this.finder = false,
      this.countryId,
      this.universityId,
      required this.onOpen,
      this.onOrientation});
  @override
  State<CatalogBrowser> createState() => _CatalogBrowserState();
}

class _CatalogBrowserState extends State<CatalogBrowser> {
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> countries = [], universityOptions = [];
  bool initializedCountry = false;
  CatalogSelection selection = const CatalogSelection();
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await Future.wait([
        widget.universities
            ? CatalogRepository.instance.getUniversities()
            : CatalogRepository.instance
                .getPrograms(university: widget.universityId),
        CatalogRepository.instance.getCountries(),
        if (!widget.universities) CatalogRepository.instance.getUniversities(),
      ]);
      if (!mounted) return;
      setState(() {
        rows = data[0]
            .whereType<Map>()
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
        countries = data[1]
            .whereType<Map>()
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
        universityOptions = widget.universities
            ? rows
            : data[2]
                .whereType<Map>()
                .map((v) => Map<String, dynamic>.from(v))
                .toList();
        if (!initializedCountry && widget.countryId != null) {
          final country =
              countries.where((c) => c['_id'] == widget.countryId).firstOrNull;
          if (country != null) {
            selection = CatalogSelection(
                facets: {'country': catalogText(country['name'])});
          }
        }
        initializedCountry = true;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'تعذر تحميل الكتالوج. تحقق من الاتصال وحاول مجددًا.';
        });
      }
    }
  }

  Map<String, String> get labels => {
        if (widget.universityId == null) 'country': 'الدولة',
        if (!widget.universities && widget.universityId == null)
          'university': 'الجامعة',
        if (widget.universities) 'city': 'المدينة',
        if (!widget.universities) 'fieldOfStudy': 'التخصص',
        if (!widget.universities) 'degreeLevel': 'الدرجة العلمية',
        'language': 'لغة الدراسة',
        if (!widget.universities) 'intake': 'موعد الالتحاق',
      };
  Future<void> showFilters() async {
    final result = await showModalBottomSheet<CatalogSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CatalogFilterSheet(
          rows: rows,
          countries: countries,
          universityOptions: universityOptions,
          labels: labels,
          universities: widget.universities,
          selection: selection,
          query: search.text),
    );
    if (result != null && mounted) {
      setState(() => selection = result);
    }
  }

  void clear() {
    setState(() {
      selection = const CatalogSelection();
      search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        filterCatalog(rows, selection, search.text, widget.universities);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.finder) ...[
              const Text('ابدأ بمستقبلك الدراسي',
                  style: AppTextStyles.screenTitle),
              const SizedBox(height: 4),
              const Text(
                  'اختر التخصص والدرجة والميزانية لعرض البرامج المطابقة من الكتالوج.',
                  style: AppTextStyles.caption),
              if (widget.onOrientation != null)
                TextButton.icon(
                    onPressed: widget.onOrientation,
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text('لم تحدد تخصصك؟ قيّم اهتماماتك')),
            ],
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                          hintText: widget.universities
                              ? 'ابحث عن جامعة أو مدينة'
                              : 'ابحث عن برنامج أو تخصص',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'مسح البحث',
                                  onPressed: () =>
                                      setState(() => search.clear()),
                                  icon: const Icon(Icons.close, size: 18)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14)))),
              const SizedBox(width: 10),
              Badge(
                  isLabelVisible: selection.count > 0,
                  label: Text('${selection.count}'),
                  child: IconButton.filled(
                      tooltip: 'تصفية النتائج',
                      onPressed: loading || error != null ? null : showFilters,
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(52, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      icon: const Icon(Icons.tune_rounded))),
            ]),
            if (!loading && error == null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${filtered.length} ${widget.universities ? 'جامعة' : 'برنامج'}${selection.count > 0 || search.text.isNotEmpty ? ' من ${rows.length}' : ''}',
                            style: AppTextStyles.caption)),
                    if (selection.count > 0 || search.text.isNotEmpty)
                      TextButton(
                          onPressed: clear, child: const Text('مسح الكل')),
                  ])),
            if (selection.count > 0)
              SizedBox(
                  height: 42,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final entry in selection.facets.entries)
                      Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: InputChip(
                              label: Text(entry.value),
                              onDeleted: () => setState(() => selection =
                                  CatalogSelection(
                                      facets: Map.of(selection.facets)
                                        ..remove(entry.key),
                                      maxTuition: selection.maxTuition,
                                      partnerOnly: selection.partnerOnly,
                                      sort: selection.sort)))),
                    if (selection.maxTuition != null)
                      Chip(label: Text('حتى ${selection.maxTuition} USD')),
                    if (selection.partnerOnly)
                      const Chip(label: Text('الجامعات الشريكة')),
                    if (selection.sort != 'default')
                      Chip(
                          label: Text(selection.sort == 'fee'
                              ? 'الأقل رسومًا'
                              : 'الاسم')),
                  ])),
          ])),
      Expanded(
        child: loading
            ? const LoadingState(message: 'جارٍ تحميل الكتالوج...')
            : error != null
                ? SingleChildScrollView(
                    child: ErrorState(message: error!, onRetry: load))
                : filtered.isEmpty
                    ? SingleChildScrollView(
                        child: EmptyState(
                            icon: Icons.search_off_rounded,
                            title: rows.isEmpty
                                ? 'لا توجد بيانات متاحة بعد'
                                : 'لا توجد نتائج مطابقة',
                            message: rows.isEmpty
                                ? 'يمكنك إعادة التحميل لاحقًا.'
                                : 'جرّب توسيع اختياراتك أو مسح الفلاتر.',
                            ctaLabel: rows.isEmpty
                                ? 'إعادة التحميل'
                                : 'مسح الفلاتر والبحث',
                            onCta: rows.isEmpty ? load : clear))
                    : RefreshIndicator(
                        onRefresh: load,
                        color: AppColors.navy,
                        child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _CatalogCard(
                                row: filtered[i],
                                universities: widget.universities,
                                onTap: () => widget.onOpen(filtered[i])))),
      ),
    ]);
  }
}

class _CatalogFilterSheet extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final Map<String, String> labels;
  final List<Map<String, dynamic>> countries, universityOptions;
  final CatalogSelection selection;
  final bool universities;
  final String query;
  const _CatalogFilterSheet(
      {required this.rows,
      required this.labels,
      required this.countries,
      required this.universityOptions,
      required this.selection,
      required this.universities,
      required this.query});
  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late Map<String, String> facets = Map.of(widget.selection.facets);
  late bool partner = widget.selection.partnerOnly;
  late String sort = widget.selection.sort;
  late final budget = TextEditingController(
      text: widget.selection.maxTuition?.toString() ?? '');
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    budget.dispose();
    super.dispose();
  }

  String normalizedBudget() {
    var value = budget.text
        .trim()
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('٫', '.');
    for (var i = 0; i < 10; i++) {
      value = value
          .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
          .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
    }
    return value;
  }

  CatalogSelection get draft => CatalogSelection(
      facets: Map.of(facets),
      maxTuition: num.tryParse(normalizedBudget()),
      partnerOnly: partner,
      sort: sort);
  @override
  Widget build(BuildContext context) {
    final count =
        filterCatalog(widget.rows, draft, widget.query, widget.universities)
            .length;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                .88,
            child: SafeArea(
                top: false,
                child: Column(children: [
                  const SizedBox(height: 10),
                  Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4))),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.tune_rounded, color: AppColors.navy),
                        const SizedBox(width: 10),
                        const Expanded(
                            child: Text('تصفية النتائج',
                                style: AppTextStyles.sectionLabel)),
                        IconButton(
                            tooltip: 'إغلاق الفلاتر',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ])),
                  Expanded(
                      child: Form(
                          key: form,
                          child: ListView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              children: [
                                const Text(
                                    'حدّد ما يناسبك؛ تُطبّق الاختيارات عند الضغط على عرض النتائج.',
                                    style: AppTextStyles.caption),
                                const SizedBox(height: 20),
                                for (final entry in widget.labels.entries) ...[
                                  Builder(builder: (_) {
                                    final sorted = catalogFacetOptions(
                                        entry.key,
                                        widget.labels.keys.toList(),
                                        facets,
                                        widget.rows,
                                        widget.countries,
                                        widget.universityOptions,
                                        widget.universities);
                                    return DropdownButtonFormField<String>(
                                        key: ValueKey(
                                            '${entry.key}:${facets[entry.key]}'),
                                        initialValue:
                                            sorted.contains(facets[entry.key])
                                                ? facets[entry.key]
                                                : '',
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                            labelText: entry.value,
                                            filled: true,
                                            fillColor: AppColors.background,
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                    color: AppColors.border))),
                                        items: [
                                          const DropdownMenuItem(
                                              value: '', child: Text('الكل')),
                                          for (final option in sorted)
                                            DropdownMenuItem(
                                                value: option,
                                                child: Text(option,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis))
                                        ],
                                        onChanged: (v) => setState(() {
                                              final keys =
                                                  widget.labels.keys.toList();
                                              for (final child in keys.skip(
                                                  keys.indexOf(entry.key) +
                                                      1)) {
                                                facets.remove(child);
                                              }
                                              if (v == null || v.isEmpty) {
                                                facets.remove(entry.key);
                                              } else {
                                                facets[entry.key] = v;
                                              }
                                            }));
                                  }),
                                  const SizedBox(height: 16),
                                ],
                                TextFormField(
                                    controller: budget,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    onChanged: (_) => setState(() {}),
                                    validator: (_) {
                                      final v = normalizedBudget();
                                      final n = num.tryParse(v);
                                      return v.isNotEmpty &&
                                              (n == null ||
                                                  !n.isFinite ||
                                                  n < 0)
                                          ? 'أدخل مبلغًا صحيحًا لا يقل عن صفر'
                                          : null;
                                    },
                                    decoration: InputDecoration(
                                        labelText: 'الحد الأقصى للرسوم (USD)',
                                        hintText: 'بدون حد',
                                        helperText: widget.universities
                                            ? 'حسب الحد الأدنى للرسوم المعلنة للجامعة'
                                            : 'حسب الرسوم المنشورة للبرنامج',
                                        helperMaxLines: 2,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)))),
                                const SizedBox(height: 8),
                                const Text(
                                    'عند تحديد ميزانية، تُستبعد النتائج التي لم تُعلن رسومها.',
                                    style: AppTextStyles.caption),
                                const SizedBox(height: 16),
                                if (widget.universities)
                                  SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('الجامعات الشريكة فقط'),
                                      value: partner,
                                      onChanged: (v) =>
                                          setState(() => partner = v)),
                                DropdownButtonFormField<String>(
                                    key: ValueKey('sort:$sort'),
                                    initialValue: sort,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: 'ترتيب النتائج',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14))),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'default',
                                          child: Text('الترتيب الافتراضي')),
                                      DropdownMenuItem(
                                          value: 'name', child: Text('الاسم')),
                                      DropdownMenuItem(
                                          value: 'fee',
                                          child: Text('الأقل رسومًا أولًا'))
                                    ],
                                    onChanged: (v) =>
                                        setState(() => sort = v ?? 'default')),
                                const SizedBox(height: 24),
                              ]))),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        TextButton(
                            onPressed: () => setState(() {
                                  form.currentState?.reset();
                                  facets.clear();
                                  budget.clear();
                                  partner = false;
                                  sort = 'default';
                                }),
                            child: const Text('إعادة ضبط')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: FilledButton(
                                onPressed: () {
                                  if (form.currentState!.validate()) {
                                    Navigator.pop(context, draft);
                                  }
                                },
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.navy,
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14))),
                                child: Text('عرض النتائج ($count)'))),
                      ])),
                ])),
          ),
        ));
  }
}

class _CatalogCard extends StatefulWidget {
  final Map<String, dynamic> row;
  final bool universities;
  final VoidCallback onTap;
  const _CatalogCard(
      {required this.row, required this.universities, required this.onTap});
  @override
  State<_CatalogCard> createState() => _CatalogCardState();
}

class _CatalogCardState extends State<_CatalogCard> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  Future<void> _loadFav() async {
    final id = '${widget.row['_id'] ?? ''}';
    if (id.isEmpty) return;
    final v = await FavoritesService.instance
        .isFavorite(id, university: widget.universities);
    if (mounted) setState(() => _isFav = v);
  }

  Future<void> _toggle() async {
    final id = '${widget.row['_id'] ?? ''}';
    if (id.isEmpty) return;
    final nowFav = await FavoritesService.instance
        .toggle(id, university: widget.universities);
    if (mounted) setState(() => _isFav = nowFav);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final universities = widget.universities;
    final uni = universities ? row : catalogMap(row['university']);
    final logo = catalogText(uni['logo']);
    final fee = catalogTuition(row, universities);
    final location = [
      catalogFacet(row, 'city', universities),
      catalogFacet(row, 'country', universities)
    ].where((v) => v.isNotEmpty).join('، ');
    return AppCard(
        onTap: widget.onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(12)),
                child: logo.isEmpty
                    ? Icon(
                        universities
                            ? Icons.account_balance_outlined
                            : Icons.school_outlined,
                        color: AppColors.navy)
                    : Image.network(logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_outlined,
                            color: AppColors.navy))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(catalogText(row[universities ? 'name' : 'title']),
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  if (!universities && catalogText(uni['name']).isNotEmpty)
                    Text(catalogText(uni['name']),
                        style: AppTextStyles.caption),
                  if (location.isNotEmpty)
                    Text(location, style: AppTextStyles.caption),
                ])),
            GestureDetector(
              onTap: _toggle,
              child: Icon(
                _isFav ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                size: 22,
                color: _isFav ? AppColors.navy : AppColors.textSecondary,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final label in [
              if (!universities) catalogText(row['degreeLevel']),
              catalogText(row['language']),
              if (!universities) catalogText(row['duration'])
            ].where((s) => s.isNotEmpty))
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(label, style: AppTextStyles.caption)),
            if (universities && row['isPartnerInstitution'] == true)
              const StatusBadge(label: 'جامعة شريكة', color: AppColors.success),
          ]),
          const Divider(height: 24),
          Wrap(spacing: 12, runSpacing: 6, children: [
            Text(
                fee == null
                    ? 'الرسوم غير معلنة'
                    : '${universities ? 'تبدأ من ' : ''}${fee.toString()} USD',
                style: AppTextStyles.cardTitle.copyWith(color: AppColors.navy)),
            if (!universities && catalogText(row['intake']).isNotEmpty)
              Text('الالتحاق: ${row['intake']}', style: AppTextStyles.caption),
          ]),
        ]));
  }
}
