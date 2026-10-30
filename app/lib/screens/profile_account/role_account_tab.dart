import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/utils/json_safe.dart';
import '../../core/widgets/app_notice.dart';
import '../../core/widgets/current_user_avatar.dart';
import '../../core/widgets/verified_admin_badge.dart';
import 'my_streak.dart';
import 'notification_preferences_screen.dart';
import 'security_settings_screen.dart';
import '../games/wink_screen.dart';

/// Personal account tab for non-student roles. Student academic and passport
/// data stays in the student-only profile editor.
class RoleAccountTab extends StatefulWidget {
  final bool showStreakAndGame;
  final Future<void> Function() onLogout;
  final Key? streakCardKey;
  final Key? gameCardKey;

  const RoleAccountTab({
    super.key,
    required this.onLogout,
    this.showStreakAndGame = true,
    this.streakCardKey,
    this.gameCardKey,
  });

  @override
  State<RoleAccountTab> createState() => _RoleAccountTabState();
}

class _RoleAccountTabState extends State<RoleAccountTab> {
  bool _uploadingAvatar = false;
  bool _savingName = false;
  final _nameController = TextEditingController();

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    AuthSession.instance.addListener(_accountChanged);
  }

  void _accountChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _changeAvatar() async {
    if (_uploadingAvatar) return;
    final owner = AuthSession.instance.currentUser?.id;
    setState(() => _uploadingAvatar = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 768,
      );
      if (picked == null ||
          !mounted ||
          owner != AuthSession.instance.currentUser?.id) {
        return;
      }
      final user = AuthSession.instance.currentUser;
      final token = AuthSession.instance.token;
      if (user == null || token == null) {
        throw const ApiException(401, 'يلزم تسجيل الدخول مجددًا.');
      }
      final response = Json.map(await ApiClient.instance.postMultipart(
        '/auth/avatar',
        fileBytes: await picked.readAsBytes(),
        fileName: picked.name,
        fields: const {},
        token: token,
      ));
      final account = Json.mapOrNull(response['user']);
      if (owner != AuthSession.instance.currentUser?.id) return;
      if (account == null) {
        throw const ApiException(500, 'تعذر تحديث بيانات الحساب.');
      }
      await AuthSession.instance.updateAccount(account);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content:
            Text(_isArabic ? 'تم تحديث صورة الحساب' : 'Profile photo updated'),
        backgroundColor: AppColors.success,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: Text(_isArabic
            ? 'تعذر تحديث الصورة: ${error is ApiException ? error.message : 'حاول مرة أخرى'}'
            : 'Could not update the photo. Please try again.'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editName() async {
    final user = AuthSession.instance.currentUser;
    if (user == null || _savingName) return;
    _nameController.text = user.name;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void close([String? value]) {
          FocusScope.of(dialogContext).unfocus();
          Navigator.pop(dialogContext, value);
        }

        return AlertDialog(
          title: Text(_isArabic ? 'تعديل الاسم' : 'Edit name'),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 120,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
                labelText: _isArabic ? 'الاسم الظاهر' : 'Display name'),
            onSubmitted: (value) => close(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => close(),
              child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => close(_nameController.text.trim()),
              child: Text(_isArabic ? 'حفظ' : 'Save'),
            ),
          ],
        );
      },
    );
    if (name == null || !mounted) return;
    if (name.trim().isEmpty || name.trim().length > 120) {
      _showMessage(
          _isArabic
              ? 'أدخل اسمًا من 1 إلى 120 حرفًا.'
              : 'Enter a name from 1 to 120 characters.',
          error: true);
      return;
    }

    setState(() => _savingName = true);
    try {
      final token = AuthSession.instance.token;
      if (token == null) {
        throw const ApiException(401, 'يلزم تسجيل الدخول مجددًا.');
      }
      final response = Json.map(await ApiClient.instance.patch(
        '/auth/me/profile',
        token: token,
        body: {'name': name.trim()},
      ));
      final account = Json.mapOrNull(response['user']);
      if (account == null) {
        throw const ApiException(500, 'تعذر تحديث بيانات الحساب.');
      }
      await AuthSession.instance.updateAccount(account);
      if (mounted) _showMessage(_isArabic ? 'تم تحديث الاسم' : 'Name updated');
    } catch (error) {
      if (mounted) {
        _showMessage(
          _isArabic && error is ApiException
              ? error.message
              : (_isArabic
                  ? 'تعذر تحديث الاسم. حاول مرة أخرى.'
                  : 'Could not update the name. Please try again.'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ));
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_accountChanged);
    _nameController.dispose();
    super.dispose();
  }

  String _roleName(UserRole role) {
    if (!_isArabic) {
      return switch (role) {
        UserRole.parent => 'Parent',
        UserRole.agent => 'Agent',
        UserRole.university => 'University',
        UserRole.employee => 'Employee',
        UserRole.admin => 'Administrator',
        UserRole.student => 'Student',
      };
    }
    return role.label;
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text(_isArabic
            ? 'سجّل الدخول لعرض حسابك.'
            : 'Sign in to view your account.'),
      );
    }

    return ListView(
      key: const ValueKey('role-account-tab'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CurrentUserAvatar(
                      radius: 42,
                      key: ValueKey('role-account-avatar-${user.id}')),
                  Material(
                    color: AppColors.green,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const ValueKey('role-account-change-avatar'),
                      customBorder: const CircleBorder(),
                      onTap: _uploadingAvatar ? null : _changeAvatar,
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: _uploadingAvatar
                            ? const Padding(
                                padding: EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt_outlined,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                  child: Text(user.name,
                      key: const ValueKey('role-account-name'),
                      style: AppTextStyles.cardTitle,
                      textAlign: TextAlign.center),
                ),
                if (user.role == UserRole.admin) ...[
                  const SizedBox(width: 6),
                  const VerifiedAdminBadge(role: 'admin', size: 19),
                ],
              ]),
              const SizedBox(height: 3),
              Text(user.email,
                  style: AppTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(_roleName(user.role),
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('role-account-edit-name'),
                onPressed: _savingName ? null : _editName,
                icon: _savingName
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                    _isArabic ? 'تعديل الاسم والصورة' : 'Edit name and photo'),
              ),
            ],
          ),
        ),
        if (widget.showStreakAndGame && user.role != UserRole.agent)
          MyStreakCard(
            key: widget.streakCardKey ??
                ValueKey('role-account-streak-${user.id}'),
            isActive: true,
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isArabic ? 'بيانات الحساب' : 'Account details',
                  style: AppTextStyles.sectionLabel),
              const SizedBox(height: 14),
              _DetailRow(
                  icon: Icons.alternate_email_rounded,
                  label: _isArabic ? 'البريد الإلكتروني' : 'Email',
                  value: user.email),
              const Divider(height: 22),
              _DetailRow(
                icon: user.emailVerified
                    ? Icons.verified_outlined
                    : Icons.mark_email_read_outlined,
                label: _isArabic ? 'حالة البريد' : 'Email status',
                value: user.emailVerified
                    ? (_isArabic ? 'موثّق' : 'Verified')
                    : (_isArabic ? 'غير موثّق' : 'Not verified'),
              ),
              if ((user.verifiedPhone ?? '').isNotEmpty) ...[
                const Divider(height: 22),
                _DetailRow(
                    icon: Icons.phone_outlined,
                    label: _isArabic ? 'الهاتف الموثّق' : 'Verified phone',
                    value: user.verifiedPhone!),
              ],
              if (user.role == UserRole.employee &&
                  user.employeeRole != null) ...[
                const Divider(height: 22),
                _DetailRow(
                    icon: Icons.badge_outlined,
                    label: _isArabic ? 'المسمى الوظيفي' : 'Position',
                    value: user.employeeRole!),
              ],
            ],
          ),
        ),
        if (widget.showStreakAndGame && user.role != UserRole.agent)
          AppCard(
            key: widget.gameCardKey ?? const ValueKey('role-account-wink-game'),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const WinkScreen())),
            child: Row(children: [
              const Icon(Icons.sports_esports_rounded, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(_isArabic ? 'لعبة الغمّازة' : 'The Winker game',
                      style: AppTextStyles.cardTitle)),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ]),
          ),
        const SizedBox(height: 4),
        Text(_isArabic ? 'إعدادات الحساب' : 'Account settings',
            style: AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.notifications_outlined,
          label: _isArabic ? 'تفضيلات الإشعارات' : 'Notification preferences',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const NotificationPreferencesScreen())),
        ),
        _ActionCard(
          icon: Icons.lock_outline_rounded,
          label: _isArabic ? 'تغيير كلمة المرور' : 'Change password',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ChangePasswordScreen())),
        ),
        _ActionCard(
          icon: Icons.security_outlined,
          label: _isArabic ? 'أمان الحساب' : 'Account security',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SecuritySettingsScreen())),
        ),
        _ActionCard(
          icon: Icons.logout_rounded,
          label: _isArabic ? 'تسجيل الخروج' : 'Sign out',
          danger: true,
          onTap: widget.onLogout,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 19),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyles.caption)),
        const SizedBox(width: 12),
        Flexible(
            child: Text(value,
                style: AppTextStyles.body,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis)),
      ]);
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.danger = false});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Row(children: [
          Icon(icon,
              color: danger ? AppColors.danger : AppColors.navy, size: 21),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: AppTextStyles.cardTitle
                      .copyWith(color: danger ? AppColors.danger : null))),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.textSecondary),
        ]),
      );
}
