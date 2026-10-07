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
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getUniversityById(String id) async {
    final data = await ApiClient.instance.get('/universities/$id');
    return data as Map<String, dynamic>;
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
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getProgramById(String id) async {
    final data = await ApiClient.instance.get('/programs/$id');
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCountries() async {
    final data = await ApiClient.instance.get('/content/countries');
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getServices() async =>
      await ApiClient.instance.get('/content/our-services') as List<dynamic>;

  Future<List<dynamic>> getFaqs() async {
    final data = await ApiClient.instance.get('/content/faqs');
    return data as List<dynamic>;
  }

  Future<List<dynamic>> getExhibitions() async {
    final data = await ApiClient.instance.get('/content/exhibitions');
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getExhibitionBySlug(String slug) async {
    final data = await ApiClient.instance.get('/content/exhibitions/$slug');
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getArticles() async {
    final data = await ApiClient.instance.get('/content/blog');
    return data as List<dynamic>;
  }
}
