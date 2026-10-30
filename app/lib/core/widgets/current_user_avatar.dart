import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_session.dart';
import '../config/app_theme.dart';

/// Shared, account-scoped photo for the profile and account menu.
class CurrentUserAvatar extends StatefulWidget {
  final double radius;
  const CurrentUserAvatar({super.key, this.radius = 22});
  static final _changes = ValueNotifier<int>(0);
  static final _photos = <String, Uint8List>{};
  static final _photoUrls = <String, String>{};

  static Future<void> save(String userId, Uint8List bytes) async {
    if (AuthSession.instance.currentUser?.id != userId) return;
    final url = AuthSession.instance.currentUser?.avatar ?? '';
    _photos[userId] = bytes;
    _photoUrls[userId] = url;
    _changes.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_avatar_b64_$userId', base64Encode(bytes));
      await prefs.setString('profile_avatar_url_$userId', url);
    } catch (_) {
      // Keep both visible avatars updated even if local persistence fails.
    }
  }

  @override
  State<CurrentUserAvatar> createState() => _CurrentUserAvatarState();
}

class _CurrentUserAvatarState extends State<CurrentUserAvatar> {
  String? _owner;
  @override
  void initState() {
    super.initState();
    AuthSession.instance.addListener(_changed);
    CurrentUserAvatar._changes.addListener(_changed);
    _load();
  }

  void _changed() {
    if (!mounted) return;
    _load();
    setState(() {});
  }

  Future<void> _load() async {
    final id = AuthSession.instance.currentUser?.id;
    if (_owner == id || id == null) return;
    _owner = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'profile_avatar_b64_$id';
      final data = prefs.getString(key);
      final savedUrl = prefs.getString('profile_avatar_url_$id') ?? '';
      // The legacy global photo has no trustworthy owner on shared devices.
      await prefs.remove('profile_avatar_b64');
      if (data != null && !CurrentUserAvatar._photos.containsKey(id)) {
        CurrentUserAvatar._photos[id] = base64Decode(data);
        CurrentUserAvatar._photoUrls[id] = savedUrl;
      }
      if (mounted) setState(() {});
    } catch (_) {
      // A missing or unreadable local cache falls back to the account avatar.
    }
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_changed);
    CurrentUserAvatar._changes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    final bytes = CurrentUserAvatar._photos[user?.id];
    final url = user?.avatar;
    final currentPhoto =
        bytes != null && CurrentUserAvatar._photoUrls[user?.id] == (url ?? '');
    final initial =
        user?.name.trim().characters.firstOrNull?.toUpperCase() ?? '؟';
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.navy,
      child: ClipOval(
          child: SizedBox.square(
        dimension: widget.radius * 2,
        child: currentPhoto
            ? Image.memory(bytes,
                key: ValueKey(
                    'local-avatar-${user?.id}-${CurrentUserAvatar._changes.value}'),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initial(initial))
            : url != null && url.isNotEmpty
                ? AppNetworkImage(url,
                    width: widget.radius * 2,
                    height: widget.radius * 2,
                    fit: BoxFit.cover,
                    errorWidget: _initial(initial))
                : _initial(initial),
      )),
    );
  }

  Widget _initial(String initial) => Center(
      child: Text(initial,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: widget.radius * .73)));
}
