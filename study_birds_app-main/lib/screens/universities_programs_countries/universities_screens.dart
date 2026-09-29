import 'compare_list_screen.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/analytics_service.dart';
import 'catalog_browser.dart';
import 'catalog_detail.dart';

class UniversitiesExplorerScreen extends StatefulWidget {
  final String? countryId;
  const UniversitiesExplorerScreen({super.key, this.countryId});
  @override
  State<UniversitiesExplorerScreen> createState() =>
      _UniversitiesExplorerScreenState();
}

class _UniversitiesExplorerScreenState
    extends State<UniversitiesExplorerScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('universities_explorer');
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'الجامعات',
        body: CatalogBrowser(
            universities: true,
            countryId: widget.countryId,
            onOpen: (u) => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => UniversityDetailScreen(
                    universityId: u['_id'] as String, initialData: u)))),
      );
}

class UniversityDetailScreen extends StatelessWidget {
  final String universityId;
  final Map<String, dynamic>? initialData;
  const UniversityDetailScreen(
      {super.key, required this.universityId, this.initialData});
  @override
  Widget build(BuildContext context) => CatalogDetailPage(
      id: universityId, university: true, initialData: initialData);
}

class CompareUniversitiesScreen extends StatelessWidget {
  const CompareUniversitiesScreen({super.key});
  @override
  Widget build(BuildContext context) => const CompareListScreen();
}
