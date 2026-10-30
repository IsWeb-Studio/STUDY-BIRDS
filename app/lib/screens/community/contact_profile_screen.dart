import 'package:flutter/material.dart';
import '../services_support/community_screen.dart';
import '../../core/widgets/safety_controls.dart';

import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/utils/json_safe.dart';
import '../../core/widgets/verified_admin_badge.dart';

/// Opens the safe, relationship-scoped profile available to chat contacts.
/// The server returns only public identity fields for an authorized contact.
class ContactProfileLink extends StatefulWidget {
  final String userId;
  final Widget child;
  final bool communityMode;

  const ContactProfileLink({
    super.key,
    required this.userId,
    required this.child,
    this.communityMode = false,
  });

  @override
  State<ContactProfileLink> createState() => _ContactProfileLinkState();
}

class _ContactProfileLinkState extends State<ContactProfileLink> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Semantics(
      button: widget.userId.isNotEmpty,
      label: isArabic ? 'عرض الملف الشخصي' : 'View profile',
      child: InkWell(
        onTap: widget.userId.isEmpty
            ? null
            : () async {
                if (_opening) return;
                _opening = true;
                try {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ContactProfileScreen(
                      userId: widget.userId,
                      communityMode: widget.communityMode,
                    ),
                  ));
                } finally {
                  _opening = false;
                }
              },
        child: widget.child,
      ),
    );
  }
}

class ContactProfileScreen extends StatefulWidget {
  final String userId;
  final bool communityMode;

  const ContactProfileScreen(
      {super.key, required this.userId, this.communityMode = false});

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.instance.get(
        Uri(
          path:
              '/mobile-workspace/contacts/${Uri.encodeComponent(widget.userId)}',
          queryParameters:
              widget.communityMode ? const {'community': '1'} : null,
        ).toString(),
        token: AuthSession.instance.token,
        cached: false,
      );
      final profile = Json.map(data);
      if (profile['_id'] == null || profile['name'] == null) {
        throw const ApiException(404, 'Contact unavailable');
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException && [403, 404].contains(error.statusCode)
            ? (_isArabic
                ? 'هذا الملف غير متاح لحسابك.'
                : 'This profile is unavailable to your account.')
            : (_isArabic
                ? 'تعذّر تحميل الملف. حاول مرة أخرى.'
                : 'Could not load this profile. Please try again.');
      });
    }
  }

  String _roleLabel(String? role) {
    if (_isArabic) {
      return switch (role) {
        'student' => 'طالب',
        'employee' => 'موظف دعم',
        'admin' => 'مسؤول',
        'university' => 'حساب جامعة',
        'parent' => 'ولي أمر',
        'agent' || 'partner' => 'مستشار',
        _ => 'مستخدم COVEY',
      };
    }
    return switch (role) {
      'student' => 'Student',
      'employee' => 'Support staff',
      'admin' => 'Administrator',
      'university' => 'University account',
      'parent' => 'Parent',
      'agent' || 'partner' => 'Advisor',
      _ => 'COVEY member',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isArabic ? 'الملف الشخصي' : 'Profile'),
        actions: [
          BlockUserButton(userId: widget.userId),
          IconButton(
            tooltip: _isArabic ? 'تحديث' : 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_off_outlined, size: 40),
                      const SizedBox(height: 12),
                      Text(_error ??
                          (_isArabic
                              ? 'الملف غير متاح.'
                              : 'This profile is unavailable.')),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_isArabic ? 'إعادة المحاولة' : 'Try again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _avatar(_profile!['avatar']?.toString() ?? ''),
                              const SizedBox(height: 16),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _profile!['name'].toString(),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    if (_profile!['role'] == 'admin') ...[
                                      const SizedBox(width: 6),
                                      const VerifiedAdminBadge(
                                          role: 'admin', size: 19),
                                    ],
                                  ]),
                              const SizedBox(height: 8),
                              Chip(
                                avatar: const Icon(Icons.verified_user_outlined,
                                    size: 17),
                                label: Text(
                                    _roleLabel(_profile!['role']?.toString())),
                              ),
                              if (widget.communityMode) ...[
                                const SizedBox(height: 24),
                                CommunityAuthorPosts(authorId: widget.userId),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _avatar(String url) {
    final fallback = CircleAvatar(
      radius: 46,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.person_outline_rounded, size: 48),
    );
    if (!url.startsWith('https://')) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: 92,
        height: 92,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
