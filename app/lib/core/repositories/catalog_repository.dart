import '../utils/json_safe.dart';
import '../network/api_client.dart';

/// Public catalog data — Universities, Programs, Countries. No token
/// required (see server/src/routes/universityRoutes.js, programRoutes.js,
/// contentRoutes.js — all GET-list/detail routes here are public).
class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  Future<List<dynamic>> getUniversities(
      {String? country, bool? featured}) async {
    final query = <String, String>{};
    if (country != null) query['country'] = country;
    if (featured != null) query['featured'] = featured.toString();
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final data = await ApiClient.instance.get('/universities$qs');
    return Json.list(data);
  }

  Future<Map<String, dynamic>> getUniversityById(String id) async {
    final data = await ApiClient.instance.get('/universities/$id');
    return Json.map(data);
  }

  Future<List<dynamic>> getPrograms(
      {String? keyword,
      String? country,
      String? degreeLevel,
      String? university}) async {
    final query = <String, String>{};
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (country != null) query['country'] = country;
    if (degreeLevel != null) query['degreeLevel'] = degreeLevel;
    if (university != null) query['university'] = university;
    final qs = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    final data = await ApiClient.instance.get('/programs$qs');
    return Json.list(data);
  }

  Future<Map<String, dynamic>> getProgramById(String id) async {
    final data = await ApiClient.instance.get('/programs/$id');
    return Json.map(data);
  }

  Future<List<dynamic>> getCountries() async {
    final results = await Future.wait([
      ApiClient.instance.get('/content/countries'),
      getUniversities(),
    ]);
    final counts = <String, int>{};
    for (final university in Json.list(results[1]).whereType<Map>()) {
      final country = university['country'];
      final id = country is Map ? country['_id'] : country;
      if (id is String && id.isNotEmpty) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    // Editorial totals may describe a country's whole education sector.
    // The app must show only institutions available in this catalog.
    return Json.list(results[0]).whereType<Map>().map((country) => {
      ...Map<String, dynamic>.from(country),
      'universityCount': counts[country['_id']] ?? 0,
    }).toList();
  }

  /// Canonical country directory used by profile selectors. It intentionally
  /// avoids the university query used to calculate editorial result counts.
  Future<List<Map<String, dynamic>>> getCountryDirectory() async =>
      Json.list(await ApiClient.instance.get('/content/countries'))
          .whereType<Map>()
          .map((country) => Map<String, dynamic>.from(country))
          .toList();

  Future<List<Map<String, dynamic>>> getUniversityCountries() async =>
      Json.list(await ApiClient.instance.get('/universities/available-countries'))
          .whereType<Map>()
          .map((country) => Map<String, dynamic>.from(country))
          .toList();

  Future<List<dynamic>> getServices() async =>
      Json.list(await ApiClient.instance.get('/content/our-services'));

  Future<List<dynamic>> getFaqs() async {
    final data = await ApiClient.instance.get('/content/faqs');
    return Json.list(data);
  }

  Future<List<dynamic>> getExhibitions() async {
    final data = await ApiClient.instance.get('/content/exhibitions');
    return Json.list(data);
  }

  Future<Map<String, dynamic>> getExhibitionBySlug(String slug) async {
    final data = await ApiClient.instance.get('/content/exhibitions/$slug');
    return Json.map(data);
  }

  Future<List<dynamic>> getArticles() async {
    final data = await ApiClient.instance.get('/content/blog');
    return Json.list(data);
  }
}
