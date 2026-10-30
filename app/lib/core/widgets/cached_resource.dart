import 'dart:async';
import 'package:flutter/material.dart';
import '../network/api_client.dart';

/// Repaint a visible resource after its local-first background fetch completes.
/// Uses prefix subscriptions so mutations invalidate dependent screens as well.
class _CacheLifecycle with WidgetsBindingObserver {
  final VoidCallback resume;
  _CacheLifecycle(this.resume);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resume();
  }
}

mixin CachedResource<T extends StatefulWidget> on State<T> {
  StreamSubscription<String>? _cacheSubscription;
  Timer? _cacheDebounce;
  late final _CacheLifecycle _cacheLifecycle;
  bool _cacheRefreshing = false, _cacheDirty = false;
  ApiClient get resourceCacheClient => ApiClient.instance;
  Iterable<String> get cachedPaths;
  Future<void> reloadCachedResource();
  bool get isRefreshingCachedResource => _cacheRefreshing;
  @override
  void initState() {
    super.initState();
    _cacheLifecycle = _CacheLifecycle(() {
      if (_cacheDirty) _scheduleCacheRefresh();
    });
    WidgetsBinding.instance.addObserver(_cacheLifecycle);
    _cacheSubscription = resourceCacheClient.cacheChanges.listen((path) {
      if (!mounted ||
          !cachedPaths.any((p) => path.startsWith(p) || p.startsWith(path))) {
        return;
      }
      _cacheDirty = true;
      _scheduleCacheRefresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cacheDirty) _scheduleCacheRefresh();
  }

  void _scheduleCacheRefresh() {
    _cacheDebounce?.cancel();
    _cacheDebounce = Timer(const Duration(milliseconds: 100), () async {
      if (!mounted ||
          _cacheRefreshing ||
          !(ModalRoute.isCurrentOf(context) ?? true) ||
          !TickerMode.valuesOf(context).enabled ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.inactive ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.hidden) {
        return;
      }
      _cacheRefreshing = true;
      _cacheDirty = false;
      try {
        await reloadCachedResource();
      } catch (_) {/* The screen owns its error UI. */} finally {
        _cacheRefreshing = false;
        if (mounted && _cacheDirty) _scheduleCacheRefresh();
      }
    });
  }

  @override
  void dispose() {
    _cacheDebounce?.cancel();
    _cacheSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(_cacheLifecycle);
    super.dispose();
  }
}

/// Identifies local data, especially when offline, without blocking reading.
class CachedDataNotice extends StatelessWidget {
  final Iterable<String> paths;
  const CachedDataNotice({super.key, required this.paths});
  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
        stream: ApiClient.instance.cacheStatusChanges,
        builder: (context, _) {
          final saved = ApiClient.instance.cachedReadFor(paths);
          if (saved == null) return const SizedBox.shrink();
          final ar = Localizations.localeOf(context).languageCode == 'ar';
          final time = MaterialLocalizations.of(context)
              .formatTimeOfDay(TimeOfDay.fromDateTime(saved));
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Icon(Icons.history, size: 15),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(
                      ar
                          ? 'بيانات محفوظة · آخر تحديث ${saved.day}/${saved.month} $time'
                          : 'Saved data · updated ${saved.day}/${saved.month} $time',
                      style: Theme.of(context).textTheme.bodySmall)),
            ]),
          );
        },
      );
}
