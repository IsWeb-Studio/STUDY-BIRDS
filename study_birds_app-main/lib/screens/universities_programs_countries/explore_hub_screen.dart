import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/favorites_service.dart';
import '../../core/repositories/catalog_repository.dart';
import 'catalog_browser.dart' show catalogText, catalogMap, catalogTuition, catalogFacet;
import 'catalog_detail.dart' show CatalogDetailPage;
import 'universities_screens.dart';
import 'programs_screens.dart';
import 'countries_scholarships_screens.dart';
import 'compare_list_screen.dart';
import '../services_support/knowledge_base_screen.dart' show ExhibitionsScreen;

class ExploreHubScreen extends StatelessWidget {
  const ExploreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'استكشاف',
      showBackButton: Navigator.canPop(context),
      body: GridView(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05 /
                (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1, 1.6)),
        children: [
          _ExploreCard(
              label: 'الجامعات',
              image: 'assets/images/explore/universities.jpg',
              icon: Icons.account_balance_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const UniversitiesExplorerScreen()))),
          _ExploreCard(
              label: 'البرامج',
              image: 'assets/images/dashboard/library.jpg',
              icon: Icons.menu_book_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProgramsExplorerScreen()))),
          _ExploreCard(
              label: 'الدول',
              image: 'assets/images/explore/countries.jpg',
              icon: Icons.public_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CountriesExplorerScreen()))),
          _ExploreCard(
              label: 'المنح الدراسية',
              image: 'assets/images/dashboard/campus.jpg',
              icon: Icons.card_giftcard_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ScholarshipsScreen()))),
          _ExploreCard(
              label: 'مكتشف البرنامج',
              image: 'assets/images/explore/finder.jpg',
              icon: Icons.quiz_outlined,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProgramFinderScreen()))),
          _ExploreCard(
              label: 'قائمة المقارنة',
              image: 'assets/images/explore/comparison.jpg',
              icon: Icons.compare_arrows_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CompareListScreen()))),
          _ExploreCard(
              label: 'محطة المعارض',
              image: 'assets/images/explore/exhibitions.jpg',
              icon: Icons.article_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ExhibitionsScreen()))),
          _ExploreCard(
              label: 'المفضلة',
              image: 'assets/images/dashboard/students.jpg',
              icon: Icons.bookmark_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FavoritesScreen()))),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final String label;
  final String image;
  final IconData icon;
  final VoidCallback onTap;
  const _ExploreCard(
      {required this.label, required this.image, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .12),
              blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(image, fit: BoxFit.cover, excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.navy)),
            const DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x300C223A), Color(0xED0C223A)]),
            )),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: .3)),
                        ),
                        child: Icon(icon, color: Colors.white, size: 21),
                      ),
                      const Spacer(),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(child: Text(label, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle.copyWith(
                              color: Colors.white, fontSize: 16, height: 1.3),
                        )),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white70, size: 17),
                      ]),
                      const SizedBox(height: 8),
                      Container(width: 26, height: 3,
                        decoration: BoxDecoration(color: AppColors.orange,
                            borderRadius: BorderRadius.circular(3))),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _programs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FavoritesService.instance.getAllUniversityIds(),
        FavoritesService.instance.getAllProgramIds(),
        CatalogRepository.instance.getUniversities(),
        CatalogRepository.instance.getPrograms(),
      ]);
      final favUniIds = results[0] as Set<String>;
      final favProgIds = results[1] as Set<String>;
      final allUnis = (results[2] as List)
          .whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      final allProgs = (results[3] as List)
          .whereType<Map>()
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      if (mounted) {
        setState(() {
          _universities =
              allUnis.where((u) => favUniIds.contains('${u['_id']}')).toList();
          _programs =
              allProgs.where((p) => favProgIds.contains('${p['_id']}')).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFav(String id, bool isUniversity) async {
    await FavoritesService.instance.toggle(id, university: isUniversity);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('المفضلة',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
          bottom: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'الجامعات (${_universities.length})'),
              Tab(text: 'البرامج (${_programs.length})'),
            ],
          ),
        ),
        body: SafeArea(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _FavList(
                      items: _universities,
                      universities: true,
                      onRemove: (id) => _removeFav(id, true),
                      onTap: (u) => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => CatalogDetailPage(
                                  id: '${u['_id'] ?? ''}',
                                  university: true,
                                  initialData: u))),
                    ),
                    _FavList(
                      items: _programs,
                      universities: false,
                      onRemove: (id) => _removeFav(id, false),
                      onTap: (p) => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => CatalogDetailPage(
                                  id: '${p['_id'] ?? ''}',
                                  university: false,
                                  initialData: p))),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FavList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool universities;
  final void Function(String id) onRemove;
  final void Function(Map<String, dynamic> item) onTap;
  const _FavList(
      {required this.items,
      required this.universities,
      required this.onRemove,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'لا توجد ${universities ? 'جامعات' : 'برامج'} محفوظة',
        message:
            'اضغط على أيقونة الإشارة المرجعية في أي ${universities ? 'جامعة' : 'برنامج'} لحفظها هنا.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final uni = universities ? item : catalogMap(item['university']);
        final fee = catalogTuition(item, universities);
        final location = [
          catalogFacet(item, 'city', universities),
          catalogFacet(item, 'country', universities),
        ].where((v) => v.isNotEmpty).join('، ');
        return AppCard(
          onTap: () => onTap(item),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        catalogText(item[universities ? 'name' : 'title']),
                        style: AppTextStyles.cardTitle),
                    if (!universities && catalogText(uni['name']).isNotEmpty)
                      Text(catalogText(uni['name']),
                          style: AppTextStyles.caption),
                    if (location.isNotEmpty)
                      Text(location, style: AppTextStyles.caption),
                    if (fee != null)
                      Text('${fee.toString()} USD',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.navy)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'إزالة من المفضلة',
                icon: const Icon(Icons.bookmark_remove_rounded,
                    color: AppColors.navy),
                onPressed: () => onRemove('${item['_id'] ?? ''}'),
              ),
            ],
          ),
        );
      },
    );
  }
}
