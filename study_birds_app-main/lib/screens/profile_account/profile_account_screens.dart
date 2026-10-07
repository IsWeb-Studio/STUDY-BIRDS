import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'notification_preferences_screen.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../applications_documents_payments/payments_screens.dart';
import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/auth_session.dart';
import '../../core/services/analytics_service.dart';
import '../../core/repositories/student_repository.dart';
import 'security_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'delete_account_screen.dart';
import '../services_support/support_team_ai_screens.dart' show SupportCenterScreen;
import '../universities_programs_countries/explore_hub_screen.dart';
import 'student_rewards_currency_screens.dart';
import '../services_support/student_life_alumni_screens.dart';
import '../services_support/knowledge_base_screen.dart' show ExhibitionArticleScreen;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  // صورة الملف الشخصي
  Uint8List? _avatarBytes;
  bool _avatarUploading = false;

  static const _avatarPrefKey = 'profile_avatar_b64';

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screenView('profile');
    _load();
    _loadCachedAvatar();
  }

  Future<void> _loadCachedAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b64 = prefs.getString(_avatarPrefKey);
      if (b64 != null && b64.isNotEmpty && mounted) {
        setState(() => _avatarBytes = base64Decode(b64));
      }
    } catch (_) {}
  }

  Future<void> _cacheAvatar(Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPrefKey, base64Encode(bytes));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await StudentRepository.instance.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل ملفك الشخصي.';
        _loading = false;
      });
    }
  }

  String? _str(String key) {
    final v = _profile?[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _pickProfilePhoto() async {
    final choice = await showPickSourceSheet(context, title: 'الصورة الشخصية');
    if (choice == null || !mounted) return;

    // كلا الخيارين عبر image_picker لتجنب مشاكل file_picker مع المعرض
    final source = choice == PickSource.camera ? ImageSource.camera : ImageSource.gallery;
    final img = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (img == null || !mounted) return;

    final bytes = await img.readAsBytes();
    if (!mounted) return;

    setState(() {
      _avatarBytes = bytes;
      _avatarUploading = true;
    });

    // احفظ الصورة محلياً فوراً حتى لو فشل الرفع
    await _cacheAvatar(bytes);

    try {
      await StudentRepository.instance.uploadDocument(
        fileBytes: bytes,
        fileName: img.name,
        type: 'biometric-photo',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الصورة الشخصية بنجاح ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر رفع الصورة: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _goToSection(ProfileSection section) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(section: section),
      ),
    );
    if (saved == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;

    return AppScaffold(
      title: 'الملف الشخصي',
      showBackButton: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonCard(),
                ),
              )
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _buildContent(context, user),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AuthUser? user) {
    final personalComplete = _str('phone') != null && _str('nationality') != null;
    final academicComplete = _str('currentEducationLevel') != null;
    final passportComplete = _str('passportNumber') != null;
    final studyComplete = _str('intake') != null;

    final sections = [
      (
        label: 'المعلومات الشخصية',
        icon: Icons.person_outline_rounded,
        value: [_str('nationality'), _str('currentResidenceCountry'), _str('phone')]
            .where((e) => e != null)
            .join(' • '),
        complete: personalComplete,
        section: ProfileSection.personal,
      ),
      (
        label: 'المعلومات الأكاديمية',
        icon: Icons.school_outlined,
        value: [_str('currentEducationLevel'), _str('gpa')]
            .where((e) => e != null)
            .join(' • '),
        complete: academicComplete,
        section: ProfileSection.academic,
      ),
      (
        label: 'جواز السفر',
        icon: Icons.badge_outlined,
        value: passportComplete ? 'مسجّل' : null,
        complete: passportComplete,
        section: ProfileSection.passport,
      ),
      (
        label: 'تفضيلات الدراسة',
        icon: Icons.tune_rounded,
        value: _str('intake'),
        complete: studyComplete,
        section: ProfileSection.study,
      ),
    ];

    final completedCount = sections.where((s) => s.complete).length;
    final completion = sections.isEmpty ? 0.0 : completedCount / sections.length;
    final missingLabels =
        sections.where((s) => !s.complete).map((s) => s.label).join('، ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- بطاقة المستخدم مع الصورة ---
        AppCard(
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickProfilePhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.border,
                      backgroundImage: _avatarBytes != null
                          ? MemoryImage(_avatarBytes!)
                          : null,
                      child: _avatarBytes == null
                          ? const Icon(Icons.person_rounded, color: AppColors.navy, size: 28)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _avatarUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '—', style: AppTextStyles.cardTitle),
                    Text(user?.email ?? '', style: AppTextStyles.caption),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: _pickProfilePhoto,
                      child: const Text(
                        'تغيير الصورة الشخصية',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- شريط الاكتمال ---
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('اكتمال الملف الشخصي', style: AppTextStyles.caption),
                  Text(
                    '${(completion * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: completion,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.orange),
                ),
              ),
              if (missingLabels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('الناقص: $missingLabels', style: AppTextStyles.caption),
                ),
              ],
            ],
          ),
        ),

        // --- أقسام الملف الشخصي ---
        ...sections.map(
          (s) => AppCard(
            onTap: () => _goToSection(s.section),
            child: Row(
              children: [
                Icon(s.icon, color: AppColors.navy, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label, style: AppTextStyles.cardTitle),
                      if ((s.value ?? '').isNotEmpty)
                        Text(s.value!, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Icon(
                  s.complete
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 16,
                  color: s.complete ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        AppCard(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReferralProgramScreen())),
          child: Row(children: const [
            Icon(Icons.card_giftcard_rounded, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(child: Text('برنامج الإحالة', style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StudentRewardsScreen())),
          child: Row(children: const [
            Icon(Icons.workspace_premium_rounded, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(child: Text('مكافآتي', style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StudentWalletScreen())),
          child: Row(children: const [
            Icon(Icons.account_balance_wallet_rounded, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(
                child: Text('محفظتي الإلكترونية', style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MyWalletScreen())),
          child: Row(children: const [
            Icon(Icons.account_balance_wallet_outlined, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(
                child: Text('الفواتير والمدفوعات', style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          child: Row(children: const [
            Icon(Icons.favorite_border_rounded, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(child: Text('المفضلة', style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const StudentLifeOffersScreen())),
          child: Row(children: const [
            Icon(Icons.celebration_rounded, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(
                child: Text('الحياة الطلابية والفعاليات',
                    style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlumniNetworkScreen())),
          child: Row(children: const [
            Icon(Icons.school_rounded, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(
                child: Text('شبكة الخريجين', style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
        AppCard(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScholarshipsScreen())),
          child: Row(children: const [
            Icon(Icons.workspace_premium_outlined, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(
                child: Text('المنح الدراسية', style: AppTextStyles.cardTitle)),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: AppColors.textSecondary),
          ]),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإعدادات',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ChangePasswordScreen())),
            child: Row(
              children: const [
                Icon(Icons.lock_outline_rounded, color: AppColors.navy),
                SizedBox(width: 12),
                Expanded(
                    child: Text('تغيير كلمة المرور',
                        style: AppTextStyles.cardTitle)),
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SecuritySettingsScreen())),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, color: AppColors.navy),
                SizedBox(width: 12),
                Expanded(child: Text('الأمان', style: AppTextStyles.cardTitle)),
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const NotificationPreferencesScreen())),
            child: Row(
              children: const [
                Icon(Icons.notifications_none_rounded, color: AppColors.navy),
                SizedBox(width: 12),
                Expanded(
                    child: Text('تفضيلات الإشعارات',
                        style: AppTextStyles.cardTitle)),
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
          AppCard(
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('اللغة'),
                content: const Text('التطبيق متاح باللغة العربية فقط حالياً.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسناً'),
                  ),
                ],
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.language_rounded, color: AppColors.navy),
                SizedBox(width: 12),
                Expanded(child: Text('اللغة', style: AppTextStyles.cardTitle)),
                Text('العربية', style: AppTextStyles.caption),
              ],
            ),
          ),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CurrencyConverterScreen())),
            child: Row(
              children: const [
                Icon(Icons.currency_exchange_rounded, color: AppColors.navy),
                SizedBox(width: 12),
                Expanded(
                    child: Text('تحويل العملات', style: AppTextStyles.cardTitle)),
                Icon(Icons.arrow_back_ios_new_rounded,
                    size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showAppConfirmDialog(
                context,
                title: 'تسجيل الخروج',
                message: 'هل تريد تسجيل الخروج من حسابك؟',
                confirmLabel: 'تسجيل الخروج',
                danger: true,
              );
              if (confirmed) {
                await AuthSession.instance.logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              }
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
            label: const Text('تسجيل الخروج',
                style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
            icon: const Icon(Icons.delete_forever_rounded,
                color: AppColors.danger, size: 18),
            label: const Text('حذف الحساب نهائياً',
                style: TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class ReferralProgramScreen extends StatefulWidget {
  const ReferralProgramScreen({super.key});
  @override
  State<ReferralProgramScreen> createState() => _ReferralProgramScreenState();
}

class _ReferralProgramScreenState extends State<ReferralProgramScreen> {
  late Future<Map<String, dynamic>?> future =
      StudentRepository.instance.getProfile();
  @override
  Widget build(BuildContext context) => AppScaffold(
      title: 'رمز الإحالة',
      body: FutureBuilder<Map<String, dynamic>?>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(
                  child: SkeletonBox(width: 200, height: 120, borderRadius: 16));
            if (snapshot.hasError)
              return ErrorState(
                  message: 'تعذر تحميل رمز الإحالة',
                  onRetry: () => setState(
                      () => future = StudentRepository.instance.getProfile()));
            final code =
                snapshot.data?['referralCode']?.toString().trim() ?? '';
            if (code.isEmpty)
              return EmptyState(
                  icon: Icons.card_giftcard,
                  title: 'لا يوجد رمز إحالة لحسابك',
                  message: 'تواصل مع الدعم لمعرفة شروط برنامج الإحالة.',
                  ctaLabel: 'تواصل مع الدعم',
                  onCta: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SupportCenterScreen())));
            return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  SelectableText(code, style: AppTextStyles.screenTitle),
                  const SizedBox(height: 16),
                  PrimaryButton(
                      label: 'نسخ الرمز',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ الرمز')));
                      }),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('مشاركة عبر واتساب'),
                    onPressed: () async {
                      final msg = Uri.encodeComponent(
                          'انضم إلى Study Birds باستخدام رمز الإحالة الخاص بي: $code');
                      final uri = Uri.parse('whatsapp://send?text=$msg');
                      if (!await launchUrl(uri,
                          mode: LaunchMode.externalApplication)) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تعذر فتح واتساب')));
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: AppColors.navy),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button)),
                    ),
                  ),
                ]));
          }));
}

class MyWalletScreen extends StatelessWidget {
  const MyWalletScreen({super.key});
  @override
  Widget build(BuildContext context) => const PaymentsSummaryScreen();
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<dynamic> _favorites = [];
  bool _loading = true;
  String? _error;

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
      final data = await StudentRepository.instance.getFavorites();
      if (!mounted) return;
      setState(() {
        _favorites = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المفضلة.';
        _loading = false;
      });
    }
  }

  Future<void> _remove(String id) async {
    try {
      await StudentRepository.instance.removeFavorite(id);
      if (mounted)
        setState(() => _favorites
            .removeWhere((f) => (f as Map<String, dynamic>)['_id'] == id));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إزالة العنصر من المفضلة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'المفضلة',
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12), child: SkeletonCard()))
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _favorites.isEmpty
                  ? EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'لا يوجد لديك عناصر مفضلة',
                      message:
                          'احفظ الجامعات والبرامج اللي تعجبك عشان ترجعلها بسهولة.',
                      ctaLabel: 'استكشف الجامعات',
                      onCta: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ExploreHubScreen())),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.navy,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _favorites.length,
                        itemBuilder: (context, i) {
                          final fav = _favorites[i] as Map<String, dynamic>;
                          final itemType =
                              fav['itemType'] as String? ?? 'university';
                          final isUniversity = itemType == 'university';
                          final isArticle = itemType == 'article';
                          final university =
                              fav['university'] as Map<String, dynamic>?;
                          final program =
                              fav['program'] as Map<String, dynamic>?;
                          final String label;
                          final String? subtitle;
                          final IconData icon;
                          if (isUniversity) {
                            label = university?['name'] as String? ?? '—';
                            subtitle = null;
                            icon = Icons.account_balance_rounded;
                          } else if (isArticle) {
                            label = fav['articleTitle'] as String? ?? '—';
                            subtitle = 'مقال';
                            icon = Icons.article_outlined;
                          } else {
                            label = program?['title'] as String? ?? '—';
                            subtitle = (program?['university']
                                as Map<String, dynamic>?)?['name'] as String?;
                            icon = Icons.menu_book_rounded;
                          }

                          return AppCard(
                            onTap: isArticle
                                ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ExhibitionArticleScreen(item: {
                                              'slug': fav['articleSlug'],
                                              'title': fav['articleTitle'],
                                            })))
                                : null,
                            child: Row(
                              children: [
                                Icon(icon, color: AppColors.navy, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(label,
                                          style: AppTextStyles.cardTitle),
                                      if (subtitle != null)
                                        Text(subtitle,
                                            style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.favorite_rounded,
                                      color: AppColors.orange, size: 20),
                                  onPressed: () =>
                                      _remove(fav['_id'] as String),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
