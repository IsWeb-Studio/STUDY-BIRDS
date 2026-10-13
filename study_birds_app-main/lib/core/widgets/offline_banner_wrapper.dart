import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/connectivity_service.dart';

/// Wraps the app and shows ONE animated connectivity banner above it.
///
/// Driven by [ConnectivityService] (verified reachability, debounced), so it
/// does not flash during Wi-Fi/mobile hand-overs. When the connection returns
/// it briefly shows "back online" and then slides away — no snackbars, no
/// dialogs, nothing that can stack. Install once (MaterialApp.builder).
class OfflineBannerWrapper extends StatefulWidget {
  final Widget child;
  const OfflineBannerWrapper({super.key, required this.child});

  @override
  State<OfflineBannerWrapper> createState() => _OfflineBannerWrapperState();
}

class _OfflineBannerWrapperState extends State<OfflineBannerWrapper> {
  final _service = ConnectivityService.instance;
  bool _showRestored = false;
  Timer? _restoredTimer;
  StreamSubscription<void>? _reconnectSub;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _reconnectSub = _service.onReconnected.listen((_) {
      _restoredTimer?.cancel();
      if (!mounted) return;
      setState(() => _showRestored = true);
      _restoredTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showRestored = false);
      });
    });
    _service.start();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    _reconnectSub?.cancel();
    _restoredTimer?.cancel();
    super.dispose();
  }

  ({String text, Color color, IconData icon})? get _banner {
    switch (_service.status) {
      case NetworkStatus.offline:
        return (
          text: 'لا يوجد اتصال بالإنترنت — تُعرض آخر بيانات محفوظة',
          color: AppColors.neutral,
          icon: Icons.wifi_off_rounded,
        );
      case NetworkStatus.unreachable:
        return (
          text: _service.isUnstable
              ? 'الاتصال غير مستقر — نحاول إعادة الاتصال'
              : 'متصل بالشبكة لكن تعذّر الوصول إلى الخدمة — نحاول إعادة الاتصال',
          color: AppColors.warning,
          icon: Icons.cloud_off_rounded,
        );
      case NetworkStatus.online:
        if (_showRestored) {
          return (
            text: 'عاد الاتصال بالإنترنت',
            color: AppColors.success,
            icon: Icons.wifi_rounded,
          );
        }
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: banner == null
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  child: Material(
                    color: banner.color,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        child: Row(children: [
                          Icon(banner.icon, color: Colors.white, size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              banner.text,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
        ),
        Expanded(
          // The banner already consumed the status-bar inset.
          child: MediaQuery.removePadding(
              context: context,
              removeTop: banner != null,
              child: widget.child),
        ),
      ],
    );
  }
}

