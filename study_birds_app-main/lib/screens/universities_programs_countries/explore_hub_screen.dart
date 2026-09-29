import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/favorites_service.dart';
import '../../core/catalog_repository.dart';
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
      showBackButton: false,
      body: GridView(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15),
        children: [
          _ExploreCard(
              label: 'الجامعات',
              icon: Icons.account_balance_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const UniversitiesExplorerScreen()))),
          _ExploreCard(
              label: 'البرامج',
              icon: Icons.menu_book_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProgramsExplorerScreen()))),
          _ExploreCard(
              label: 'الدول',
              icon: Icons.public_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CountriesExplorerScreen()))),
          _ExploreCard(
              label: 'المنح الدراسية',
              icon: Icons.card_giftcard_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ScholarshipsScreen()))),
          _ExploreCard(
              label: 'مكتشف البرنامج',
              icon: Icons.quiz_outlined,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProgramFinderScreen()))),
          _ExploreCard(
              label: 'قائمة المقارنة',
              icon: Icons.compare_arrows_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CompareListScreen()))),
          _ExploreCard(
              label: 'محطة المعارض',
              icon: Icons.article_rounded,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ExhibitionsScreen()))),
          _ExploreCard(
              label: 'المفضلة',
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
  final IconData icon;
  final VoidCallback onTap;
  const _ExploreCard(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconTile(icon),
            const SizedBox(height: 10),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardTitle)),
          ],
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
