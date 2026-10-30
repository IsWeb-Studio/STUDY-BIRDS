import '../../core/config/app_theme.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/verified_admin_badge.dart';
import 'student_public_profile.dart';
import 'contact_profile_screen.dart';

/// Keeps avatar/name navigation consistent and prevents duplicate profile routes.
class StudentProfileLink extends StatefulWidget {
  final String studentId;
  final Widget child;
  final VoidCallback? onClosed;
  const StudentProfileLink(
      {super.key, required this.studentId, required this.child, this.onClosed});
  @override
  State<StudentProfileLink> createState() => _StudentProfileLinkState();
}

class _StudentProfileLinkState extends State<StudentProfileLink> {
  bool _opening = false;
  @override
  Widget build(BuildContext context) => Semantics(
      button: widget.studentId.isNotEmpty,
      label: 'عرض الملف الشخصي',
      child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.studentId.isEmpty
              ? null
              : () async {
                  if (_opening) return;
                  _opening = true;
                  try {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StudentPublicProfileScreen(
                            studentId: widget.studentId)));
                  } finally {
                    _opening = false;
                    if (mounted) widget.onClosed?.call();
                  }
                },
          child: widget.child));
}

class StudentIdentity extends StatelessWidget {
  final String id, name, avatar;
  final String role;
  final bool linkToProfile;
  final bool showRoleBadge;
  final String organizationName, organizationLogo;
  final VoidCallback? onClosed;
  const StudentIdentity(
      {super.key,
      required this.id,
      required this.name,
      this.avatar = '',
      this.role = 'student',
      this.linkToProfile = true,
      this.showRoleBadge = false,
      this.organizationName = '',
      this.organizationLogo = '',
      this.onClosed});
  @override
  Widget build(BuildContext context) {
    final publicName =
        role == 'university' && organizationName.trim().isNotEmpty
            ? organizationName.trim()
            : name;
    final publicAvatar = role == 'university' && organizationLogo.isNotEmpty
        ? organizationLogo
        : avatar;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final roleLabel = switch (role) {
      'parent' => isArabic ? 'ولي أمر' : 'Parent / Guardian',
      'university' => isArabic ? 'جامعة' : 'University',
      'employee' => isArabic ? 'موظف' : 'Employee',
      'admin' => isArabic ? 'إدارة' : 'Administrator',
      _ => isArabic ? 'طالب' : 'Student',
    };
    final identity = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.greenSoft,
              backgroundImage:
                  publicAvatar.isEmpty ? null : NetworkImage(publicAvatar),
              child: publicAvatar.isEmpty
                  ? const Icon(Icons.person_outline, size: 20)
                  : null),
          const SizedBox(width: 8),
          Flexible(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(publicName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (role == 'admin') ...[
                    const SizedBox(width: 4),
                    VerifiedAdminBadge(role: role, size: 16),
                  ],
                ]),
                if (showRoleBadge) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.greenSoft),
                    ),
                    child: Text(roleLabel,
                        style: const TextStyle(
                            color: AppColors.greenInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ])),
        ]));
    if (!linkToProfile) return identity;
    if (role != 'student') {
      return ContactProfileLink(
          userId: id, communityMode: true, child: identity);
    }
    return StudentProfileLink(
        studentId: id, onClosed: onClosed, child: identity);
  }
}
