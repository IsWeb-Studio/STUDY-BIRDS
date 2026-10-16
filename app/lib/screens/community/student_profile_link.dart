import 'package:flutter/material.dart';
import 'student_public_profile.dart';

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
  final bool linkToProfile;
  final VoidCallback? onClosed;
  const StudentIdentity(
      {super.key,
      required this.id,
      required this.name,
      this.avatar = '',
      this.linkToProfile = true,
      this.onClosed});
  @override
  Widget build(BuildContext context) {
    final identity = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE8EEFC),
              backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
              child: avatar.isEmpty
                  ? const Icon(Icons.person_outline, size: 20)
                  : null),
          const SizedBox(width: 8),
          Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]));
    return linkToProfile
        ? StudentProfileLink(studentId: id, onClosed: onClosed, child: identity)
        : identity;
  }
}
