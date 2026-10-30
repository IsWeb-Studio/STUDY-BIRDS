import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Explicit read policies. Money, permissions, messages and private media never
/// become authoritative (or persistent) merely because an endpoint is a GET.
class ResponseCachePolicy {
  final Duration freshFor, retainFor;
  final bool persistent;
  const ResponseCachePolicy(this.freshFor, this.retainFor,
      {this.persistent = true});

  static ResponseCachePolicy? forPath(String path, {required bool private}) {
    final p = Uri.parse(path).path;
    if (RegExp(r'^/(auth|identity|mobile-security|safety|payments|payment-proofs|documents|verification-documents|support-attachments|games)(/|$)')
            .hasMatch(p) ||
        RegExp(r'(financial|wallet|payout|invoice|payment|access|status|slots|config|verification)')
            .hasMatch(p)) {
      return null;
    }
    if (RegExp(r'^/(universities|programs)(/|$)').hasMatch(p) ||
        RegExp(r'^/content/(countries|study-fields|our-services|faqs|exhibitions|blog|testimonials|site-settings|our-story|recognitions|upcoming-event|past-events|banners)(/|$)')
            .hasMatch(p)) {
      return const ResponseCachePolicy(
          Duration(minutes: 30), Duration(days: 1));
    }
    if (p == '/scholarships' || p == '/accommodation/listings') {
      return const ResponseCachePolicy(
          Duration(minutes: 10), Duration(hours: 6));
    }
    if (!private) return null;
    if (p == '/stories' ||
        p == '/stories/progress' ||
        p.startsWith('/community/') ||
        p.startsWith('/friends') ||
        p.startsWith('/mobile-workspace/')) {
      return const ResponseCachePolicy(
          Duration(seconds: 15), Duration(minutes: 2),
          persistent: false);
    }
    if (RegExp(r'^/students/(overview|profile|orientation-test|applications|documents|journey|rewards|service-requests|arrival-services|favorites|support-team|knowledge-base|scholarships|insurance|equivalency|listings)(/|$)')
            .hasMatch(p) ||
        p == '/content/notifications' ||
        p == '/service-requests/mine' ||
        RegExp(r'^/applications/[a-fA-F0-9]{24}$').hasMatch(p) ||
        p == '/scholarships/mine' ||
        p == '/consultations/staff/advisors' ||
        p == '/consultations/mine' ||
        p == '/accommodation/bookings/mine' ||
        RegExp(r'^/parents/(children|link-requests)(/|$)').hasMatch(p) ||
        RegExp(r'^/university-portal/(applications|favorites-count)(/|$)')
            .hasMatch(p) ||
        RegExp(r'^/(admin|partners)/(overview|my-kpis|knowledge-base|marketing-assets|notifications)(/|$)')
            .hasMatch(p) ||
        p.startsWith('/assistant/suggested-questions') ||
        p.startsWith('/alumni/jobs')) {
      return const ResponseCachePolicy(
          Duration(seconds: 45), Duration(hours: 24));
    }
    // Small in-session cache only for the remaining non-sensitive reads.
    return const ResponseCachePolicy(
        Duration(seconds: 30), Duration(minutes: 2),
        persistent: false);
  }
}

class CachedResponse {
  final dynamic data;
  final DateTime savedAt;
  const CachedResponse(this.data, this.savedAt);
  bool valid(Duration maxAge, DateTime now) {
    final age = now.difference(savedAt);
    return !age.isNegative && age < maxAge;
  }

  Map<String, dynamic> toJson() =>
      {'at': savedAt.toUtc().toIso8601String(), 'data': data};
  static CachedResponse? decode(String? raw) {
    try {
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse('${j['at']}');
      return at == null ? null : CachedResponse(j['data'], at);
    } catch (_) {
      return null;
    }
  }
}

abstract class ResponseCacheStore {
  Future<CachedResponse?> read(String scope, String key);
  Future<void> write(String scope, String key, CachedResponse value);
  Future<void> invalidate(String scope, bool Function(String) matches);
  Future<void> clearPrivate();
}

/// Public JSON lives in a bounded app-cache directory. Private snapshots use
/// encrypted platform storage, with strict size/count limits and no credentials
/// in keys. Store operations are serialized so logout wins over earlier writes.
class DeviceResponseCache implements ResponseCacheStore {
  final Future<Directory> Function()? directoryProvider;
  DeviceResponseCache({this.directoryProvider});
  static final instance = DeviceResponseCache();
  static const _secure = FlutterSecureStorage();
  static const _privatePrefix = 'response_cache_v2:';
  Future<void> _tail = Future.value();
  Future<T> _queue<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  String _hash(String s) => sha256.convert(utf8.encode(s)).toString();
  Future<Directory> _directory() async => directoryProvider != null
      ? directoryProvider!()
      : Directory(
              '${(await getTemporaryDirectory()).path}/covey_public_responses_v2')
          .create(recursive: true);
  String _privateKey(String scope, String key) =>
      '$_privatePrefix${_hash('$scope:$key')}';

  @override
  Future<CachedResponse?> read(String scope, String key) => _queue(() async {
        try {
          final raw = scope == 'public'
              ? await File('${(await _directory()).path}/${_hash(key)}.json')
                  .readAsString()
              : await _secure.read(key: _privateKey(scope, key));
          final envelope = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
          if (envelope['scope'] != scope || envelope['key'] != key) return null;
          return CachedResponse.decode(jsonEncode(envelope['value']));
        } catch (_) {
          return null;
        }
      });

  @override
  Future<void> write(String scope, String key, CachedResponse value) =>
      _queue(() async {
        final raw =
            jsonEncode({'scope': scope, 'key': key, 'value': value.toJson()});
        final size = utf8.encode(raw).length;
        if (scope != 'public') {
          // Store only small private summaries, never a large student directory.
          if (size > 128 * 1024) return;
          final values = (await _secure.readAll())
              .entries
              .where((e) => e.key.startsWith(_privatePrefix))
              .toList();
          var bytes =
              values.fold<int>(0, (n, e) => n + utf8.encode(e.value).length);
          values.sort((a, b) {
            String at(String raw) {
              try {
                return '${(jsonDecode(raw) as Map)['value']['at']}';
              } catch (_) {
                return '';
              }
            }

            return at(a.value).compareTo(at(b.value));
          });
          while (values.isNotEmpty &&
              (values.length >= 40 || bytes + size > 2 * 1024 * 1024)) {
            final oldest = values.removeAt(0);
            bytes -= utf8.encode(oldest.value).length;
            await _secure.delete(key: oldest.key);
          }
          await _secure.write(key: _privateKey(scope, key), value: raw);
          return;
        }
        if (size > 2 * 1024 * 1024) return;
        final dir = await _directory();
        final target = File('${dir.path}/${_hash(key)}.json');
        final temporary = File('${target.path}.tmp');
        await temporary.writeAsString(raw, flush: true);
        // Avoid platform-dependent rename-over-existing behavior on Windows.
        if (await target.exists()) await target.delete();
        await temporary.rename(target.path);
        final files = await dir
            .list()
            .where((e) => e is File && e.path.endsWith('.json'))
            .cast<File>()
            .toList();
        final stats = <({File file, FileStat stat})>[];
        for (final file in files) {
          stats.add((file: file, stat: await file.stat()));
        }
        stats.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
        var bytes = stats.fold<int>(0, (n, e) => n + e.stat.size);
        while (stats.isNotEmpty &&
            (bytes > 8 * 1024 * 1024 || stats.length > 120)) {
          final old = stats.removeAt(0);
          bytes -= old.stat.size;
          await old.file.delete();
        }
      });

  @override
  Future<void> invalidate(String scope, bool Function(String) matches) =>
      _queue(() async {
        if (scope == 'public') {
          final dir = await _directory();
          await for (final entry in dir.list()) {
            if (entry is! File || !entry.path.endsWith('.json')) continue;
            try {
              final j = jsonDecode(await entry.readAsString()) as Map;
              if (j['key'] is String && matches(j['key'] as String)) {
                await entry.delete();
              }
            } catch (_) {
              await entry.delete();
            }
          }
        } else {
          for (final e in (await _secure.readAll())
              .entries
              .where((e) => e.key.startsWith(_privatePrefix))
              .toList()) {
            try {
              final j = jsonDecode(e.value) as Map;
              if (j['scope'] == scope &&
                  j['key'] is String &&
                  matches(j['key'] as String)) {
                await _secure.delete(key: e.key);
              }
            } catch (_) {
              await _secure.delete(key: e.key);
            }
          }
        }
      });

  @override
  Future<void> clearPrivate() => _queue(() async {
        for (final key in (await _secure.readAll())
            .keys
            .where((k) => k.startsWith(_privatePrefix))
            .toList()) {
          await _secure.delete(key: key);
        }
      });
}
