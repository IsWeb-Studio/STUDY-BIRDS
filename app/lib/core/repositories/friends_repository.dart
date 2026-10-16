import 'dart:async';
import '../network/api_client.dart';
import '../services/auth_session.dart';

class StudentFriend {
  final String id, name, avatar, relation;
  final int points;
  StudentFriend.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String? ?? '',
        avatar = j['avatar'] as String? ?? '',
        relation = j['relation'] as String? ?? 'none',
        points = (j['total_points'] as num?)?.toInt() ?? 0;
}

class FriendsPage {
  final List<StudentFriend> people;
  final String? nextCursor;
  final Map<String, dynamic> counts;
  FriendsPage.fromJson(Map<String, dynamic> j)
      : people = (j['people'] as List)
            .map((p) => StudentFriend.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
        nextCursor = j['nextCursor'] as String?,
        counts = Map<String, dynamic>.from(j['counts'] as Map? ?? {});
}

class FriendsRepository {
  FriendsRepository._();
  static final instance = FriendsRepository._();
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  String? get _token => AuthSession.instance.token;
  Future<FriendsPage> list(String kind, {String? query, String? before}) async {
    final params = <String, String>{
      if (query != null) 'q': query,
      if (query == null) 'kind': kind,
      if (before != null) 'before': before
    };
    final uri = Uri(
        path: query == null ? '/friends' : '/friends/search',
        queryParameters: params);
    return FriendsPage.fromJson(Map<String, dynamic>.from(await ApiClient
        .instance
        .get(uri.toString(), token: _token, cached: false)));
  }

  Future<void> change(String userId, String action) async {
    if (action == 'remove') {
      await ApiClient.instance.delete('/friends/$userId', token: _token);
    } else {
      await ApiClient.instance.post('/friends/$userId/$action', token: _token);
    }
    _changes.add(null);
  }
}
