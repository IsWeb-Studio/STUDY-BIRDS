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

  static Future<void> save(String userId, Uint8List bytes) async {
    _photos[userId] = bytes;
    _changes.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_avatar_b64_$userId', base64Encode(bytes));
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
      var data = prefs.getString(key);
      // Move the old single-account cache once, then use account-specific keys.
      if (data == null) {
        data = prefs.getString('profile_avatar_b64');
        if (data != null) {
          await prefs.setString(key, data);
          await prefs.remove('profile_avatar_b64');
        }
      }
      if (data != null && !CurrentUserAvatar._photos.containsKey(id)) {
        CurrentUserAvatar._photos[id] = base64Decode(data);
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
    final initial = user?.name.trim().characters.firstOrNull?.toUpperCase() ?? '؟';
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.navy,
      child: ClipOval(child: SizedBox.square(
        dimension: widget.radius * 2,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initial(initial))
            : url != null && url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initial(initial))
                : _initial(initial),
      )),
    );
  }

  Widget _initial(String initial) => Center(child: Text(initial,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
          fontSize: widget.radius * .73)));
}
