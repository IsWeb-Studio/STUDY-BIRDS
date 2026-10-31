import 'package:flutter/material.dart';
import '../../core/utils/knowledge_resource.dart';
import '../../core/widgets/external_link.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_theme.dart';
import '../../core/repositories/agent_repository.dart';
import '../../core/services/auth_session.dart';
import '../../core/utils/document_picker.dart';
import '../../core/utils/json_safe.dart';
import '../../core/widgets/app_notice.dart';

enum _PartnerArea {
  referral,
  marketing,
  verification,
  support,
  notifications,
  activity,
  knowledge,
  profile,
}

class AgentPartnerWorkspaceScreen extends StatelessWidget {
  const AgentPartnerWorkspaceScreen({super.key});

  static const _areas = <(_PartnerArea, IconData, String, String)>[
    (
      _PartnerArea.referral,
      Icons.link_rounded,
      'رابط الإحالة',
      'Referral link'
    ),
    (
      _PartnerArea.marketing,
      Icons.campaign_outlined,
      'المواد التسويقية',
      'Marketing toolkit'
    ),
    (
      _PartnerArea.verification,
      Icons.verified_user_outlined,
      'توثيق الحساب',
      'Account verification'
    ),
    (
      _PartnerArea.support,
      Icons.support_agent_rounded,
      'تذاكر الدعم',
      'Support tickets'
    ),
    (
      _PartnerArea.notifications,
      Icons.notifications_outlined,
      'الإشعارات',
      'Notifications'
    ),
    (
      _PartnerArea.activity,
      Icons.history_rounded,
      'سجل النشاط',
      'Activity log'
    ),
    (
      _PartnerArea.knowledge,
      Icons.menu_book_outlined,
      'قاعدة المعرفة',
      'Knowledge base'
    ),
    (
      _PartnerArea.profile,
      Icons.business_outlined,
      'بيانات الشركة',
      'Company profile'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return AppScaffold(
      title: ar ? 'مساحة الشريك' : 'Partner workspace',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(children: [
              const Icon(Icons.handshake_outlined,
                  color: AppColors.navy, size: 28),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                ar
                    ? 'أدوات الشراكة وإدارة الحساب، متصلة ببيانات الويب.'
                    : 'Partner tools and account management, connected to the website data.',
                style: AppTextStyles.body,
              )),
            ]),
          ),
          ..._areas.map((area) => AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _AgentPartnerAreaScreen(area: area.$1))),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: AppColors.navy.withValues(alpha: .08),
                    child: Icon(area.$2, color: AppColors.navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(ar ? area.$3 : area.$4,
                          style: AppTextStyles.cardTitle)),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                ]),
              )),
        ],
      ),
    );
  }
}

class _AgentPartnerAreaScreen extends StatefulWidget {
  final _PartnerArea area;
  const _AgentPartnerAreaScreen({required this.area});

  @override
  State<_AgentPartnerAreaScreen> createState() =>
      _AgentPartnerAreaScreenState();
}

class _AgentPartnerAreaScreenState extends State<_AgentPartnerAreaScreen> {
  dynamic _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  final _form = <String, TextEditingController>{};
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'student-application';

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _ar ? ar : en;

  String get _title => switch (widget.area) {
        _PartnerArea.referral => _t('رابط الإحالة', 'Referral link'),
        _PartnerArea.marketing => _t('المواد التسويقية', 'Marketing toolkit'),
        _PartnerArea.verification => _t('توثيق الحساب', 'Account verification'),
        _PartnerArea.support => _t('تذاكر الدعم', 'Support tickets'),
        _PartnerArea.notifications => _t('الإشعارات', 'Notifications'),
        _PartnerArea.activity => _t('سجل النشاط', 'Activity log'),
        _PartnerArea.knowledge => _t('قاعدة المعرفة', 'Knowledge base'),
        _PartnerArea.profile => _t('بيانات الشركة', 'Company profile'),
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _form.values) {
      controller.dispose();
    }
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = switch (widget.area) {
        _PartnerArea.referral =>
          await AgentRepository.instance.getReferralSummary(),
        _PartnerArea.marketing =>
          await AgentRepository.instance.getMarketingAssets(),
        _PartnerArea.verification =>
          await AgentRepository.instance.getVerification(),
        _PartnerArea.support =>
          await AgentRepository.instance.getSupportTickets(),
        _PartnerArea.notifications =>
          await AgentRepository.instance.getNotifications(),
        _PartnerArea.activity =>
          await AgentRepository.instance.getActivityLog(),
        _PartnerArea.knowledge =>
          await AgentRepository.instance.getKnowledgeBase(),
        _PartnerArea.profile => await AgentRepository.instance.getProfile(),
      };
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
      if (widget.area == _PartnerArea.profile) _fillProfile(Json.map(result));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _fillProfile(Map<String, dynamic> profile) {
    final user = Json.mapOrNull(profile['user']) ?? {};
    final values = <String, String>{
      'name': '${user['name'] ?? ''}',
      'email': '${user['email'] ?? ''}',
      'companyName': '${profile['companyName'] ?? ''}',
      'location': '${profile['location'] ?? ''}',
      'phone': '${profile['phone'] ?? ''}',
      'address': '${profile['address'] ?? ''}',
      'website': '${profile['website'] ?? ''}',
      'taxId': '${profile['taxId'] ?? ''}',
      'bio': '${profile['bio'] ?? ''}',
    };
    for (final entry in values.entries) {
      _form.putIfAbsent(entry.key, TextEditingController.new).text =
          entry.value;
    }
  }

  Future<void> _pickFile() async {
    final file = await pickDocument(context);
    if (file == null || file.bytes == null || !mounted) return;
    setState(() {
      _selectedFileName = file.name;
      _selectedFileBytes = file.bytes;
    });
  }

  Future<void> _uploadVerification(String type) async {
    final file = await pickDocument(context);
    if (file == null || file.bytes == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await AgentRepository.instance.uploadVerificationDocument(
          fileBytes: file.bytes!, fileName: file.name, type: type);
      await _load();
      if (mounted) {
        _notice(_t('تم رفع المستند وإرساله للمراجعة.',
            'Document uploaded for review.'));
      }
    } catch (error) {
      if (mounted) {
        _notice(_t('تعذر رفع المستند: ', 'Upload failed: ') + error.toString(),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitTicket() async {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      _notice(
          _t('اكتب عنوان المشكلة والرسالة أولًا.',
              'Enter a subject and message first.'),
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await AgentRepository.instance.createSupportTicket(
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        category: _category,
        fileBytes: _selectedFileBytes,
        fileName: _selectedFileName,
      );
      _subject.clear();
      _message.clear();
      _selectedFileBytes = null;
      _selectedFileName = null;
      await _load();
      if (mounted) {
        _notice(_t('تم إرسال تذكرة الدعم.', 'Support ticket submitted.'));
      }
    } catch (error) {
      if (mounted) {
        _notice(
            _t('تعذر إرسال التذكرة: ', 'Could not submit ticket: ') +
                error.toString(),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    if ((_form['companyName']?.text.trim().isEmpty ?? true) ||
        (_form['location']?.text.trim().isEmpty ?? true)) {
      _notice(
          _t('اسم الشركة والموقع مطلوبان.',
              'Company name and location are required.'),
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await AgentRepository.instance.updateProfile({
        for (final key in _form.keys) key: _form[key]!.text.trim(),
      });
      final updatedUser = Json.mapOrNull(updated['user']);
      final currentUser = AuthSession.instance.currentUser;
      if (updatedUser != null && currentUser != null) {
        AuthSession.instance.currentUser = AuthUser.fromJson({
          ...currentUser.toJson(),
          ...updatedUser,
        });
      }
      await _load();
      if (mounted) {
        _notice(_t('تم حفظ بيانات الشركة.', 'Company profile saved.'));
      }
    } catch (error) {
      if (mounted) {
        _notice(
            _t('تعذر حفظ البيانات: ', 'Could not save profile: ') +
                error.toString(),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success));
  }

  Widget _field(String key, String label,
          {bool multiline = false, TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _form.putIfAbsent(key, TextEditingController.new),
          keyboardType: keyboard,
          maxLines: multiline ? 3 : 1,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title,
      actions: [
        IconButton(
            tooltip: _t('تحديث', 'Refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded))
      ],
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _content(),
                  )),
    );
  }

  List<Widget> _content() => switch (widget.area) {
        _PartnerArea.referral => _referral(),
        _PartnerArea.marketing => _marketing(),
        _PartnerArea.verification => _verification(),
        _PartnerArea.support => _support(),
        _PartnerArea.notifications => _notifications(),
        _PartnerArea.activity => _activity(),
        _PartnerArea.knowledge => _knowledge(),
        _PartnerArea.profile => _profile(),
      };

  List<Widget> _referral() {
    final data = Json.map(_data);
    final summary = Json.mapOrNull(data['summary']) ?? {};
    final link = '${data['referralLink'] ?? ''}';
    final labels = <String, String>{
      _t('النقرات', 'Clicks'): '${summary['clicks'] ?? 0}',
      _t('التسجيلات', 'Registrations'): '${summary['signups'] ?? 0}',
      _t('الطلاب المقبولون', 'Accepted students'):
          '${summary['acceptedStudents'] ?? 0}',
      _t('العمولات الناتجة', 'Generated commissions'):
          '\$${summary['generatedCommissions'] ?? 0}',
    };
    return [
      AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t('رابطك ورمز الإحالة', 'Your referral link and code'),
            style: AppTextStyles.cardTitle),
        const SizedBox(height: 10),
        SelectableText(link, textDirection: TextDirection.ltr),
        const SizedBox(height: 8),
        Text('${_t('الرمز', 'Code')}: ${data['referralCode'] ?? '—'}'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: link.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (mounted) _notice(_t('تم نسخ الرابط.', 'Link copied.'));
                },
          icon: const Icon(Icons.copy_rounded),
          label: Text(_t('نسخ الرابط', 'Copy link')),
        ),
      ])),
      AppCard(
          child: Column(
              children: labels.entries
                  .map((e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.key),
                        trailing: Text(e.value, style: AppTextStyles.cardTitle),
                      ))
                  .toList())),
    ];
  }

  List<Widget> _marketing() {
    final assets = Json.list(_data);
    if (assets.isEmpty) {
      return [
        EmptyState(
            icon: Icons.campaign_outlined,
            title: _t('لا توجد مواد بعد', 'No materials yet'),
            message: _t('ستظهر هنا الملفات التي تنشرها الإدارة.',
                'Materials published by the admin will appear here.'))
      ];
    }
    return assets.map((raw) {
      final asset = Json.map(raw);
      return AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${asset['title'] ?? asset['fileName'] ?? '—'}',
            style: AppTextStyles.cardTitle),
        if ('${asset['description'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${asset['description']}', style: AppTextStyles.caption),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.tryParse('${asset['fileUrl'] ?? ''}');
              if (uri == null ||
                  !uri.hasScheme ||
                  !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (mounted) {
                  _notice(_t('تعذر فتح الملف.', 'Could not open the file.'),
                      error: true);
                }
              }
            },
            icon: const Icon(Icons.download_outlined),
            label: Text(_t('فتح / تنزيل', 'Open / download'))),
      ]));
    }).toList();
  }

  List<Widget> _verification() {
    final data = Json.map(_data);
    final docs = Json.list(data['documents']);
    const types = <(String, String, String)>[
      ('identity', 'الهوية أو جواز السفر', 'Identity / passport'),
      ('commercial-license', 'الرخصة أو السجل التجاري', 'Commercial license'),
      ('supporting-document', 'مستند داعم', 'Supporting document'),
    ];
    return [
      AppCard(
          child: Row(children: [
        Text(_t('حالة التوثيق: ', 'Verification: '),
            style: AppTextStyles.cardTitle),
        StatusBadge(
            label: '${data['status'] ?? 'pending'}', color: AppColors.info)
      ])),
      if ('${data['reason'] ?? ''}'.isNotEmpty)
        AppCard(child: Text('${data['reason']}')),
      ...types.map((entry) => AppCard(
              child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_ar ? entry.$2 : entry.$3),
            trailing: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_rounded),
            onTap: _saving ? null : () => _uploadVerification(entry.$1),
          ))),
      if (docs.isNotEmpty) ...[
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_t('المستندات المرفوعة', 'Uploaded documents'),
                style: AppTextStyles.sectionLabel)),
        ...docs.map((raw) {
          final doc = Json.map(raw);
          return AppCard(
              child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${doc['fileName'] ?? doc['type'] ?? '—'}'),
            subtitle: Text('${doc['status'] ?? 'pending'}'),
            leading:
                const Icon(Icons.description_outlined, color: AppColors.navy),
          ));
        }),
      ],
    ];
  }

  List<Widget> _support() {
    final tickets = Json.list(_data);
    return [
      AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_t('فتح تذكرة دعم', 'Open a support ticket'),
            style: AppTextStyles.cardTitle),
        const SizedBox(height: 12),
        TextField(
            controller: _subject,
            decoration: InputDecoration(
                labelText: _t('العنوان', 'Subject'),
                border: const OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
                labelText: _t('التصنيف', 'Category'),
                border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                  value: 'student-application',
                  child: Text(_t('طلب طالب', 'Student application'))),
              DropdownMenuItem(
                  value: 'commission',
                  child: Text(_t('العمولات', 'Commission'))),
              DropdownMenuItem(
                  value: 'technical-issue',
                  child: Text(_t('مشكلة تقنية', 'Technical issue'))),
              DropdownMenuItem(
                  value: 'other', child: Text(_t('أخرى', 'Other'))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            }),
        const SizedBox(height: 10),
        TextField(
            controller: _message,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
                labelText: _t('تفاصيل المشكلة', 'Message'),
                border: const OutlineInputBorder())),
        TextButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(_selectedFileName ??
                _t('إرفاق ملف اختياري', 'Optional attachment'))),
        PrimaryButton(
            label: _saving
                ? _t('جارٍ الإرسال...', 'Sending...')
                : _t('إرسال التذكرة', 'Submit ticket'),
            onPressed: _saving ? null : _submitTicket),
      ])),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
              _t('تذاكري وردود الإدارة', 'My tickets and admin replies'),
              style: AppTextStyles.sectionLabel)),
      if (tickets.isEmpty)
        EmptyState(
            icon: Icons.inbox_outlined,
            title: _t('لا توجد تذاكر', 'No tickets'),
            message: _t('ستظهر التذاكر والردود هنا.',
                'Your tickets and replies will appear here.')),
      ...tickets.map((raw) {
        final ticket = Json.map(raw);
        final replies = Json.list(ticket['replies']);
        return AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${ticket['subject'] ?? '—'}', style: AppTextStyles.cardTitle),
          Text('${ticket['status'] ?? ''} · ${ticket['category'] ?? ''}',
              style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Text('${ticket['message'] ?? ''}'),
          ...replies.map((replyRaw) {
            final reply = Json.map(replyRaw);
            return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      '${reply['fromRole'] ?? ''}: ${reply['message'] ?? ''}'),
                ));
          }),
        ]));
      }),
    ];
  }

  List<Widget> _notifications() {
    final items = Json.list(_data);
    if (items.isEmpty) {
      return [
        EmptyState(
            icon: Icons.notifications_none,
            title: _t('لا توجد إشعارات', 'No notifications'),
            message: _t('ستظهر التحديثات هنا.', 'Updates will appear here.'))
      ];
    }
    return items.map((raw) {
      final item = Json.map(raw);
      final id = '${item['_id'] ?? ''}';
      final read = item['isRead'] == true;
      return AppCard(
          onTap: read || id.isEmpty
              ? null
              : () async {
                  try {
                    await AgentRepository.instance.markNotificationRead(id);
                    if (mounted) await _load();
                  } catch (_) {
                    if (mounted) {
                      _notice(
                          _t('تعذر تحديث الإشعار. حاول مجددًا.',
                              'Could not update the notification. Try again.'),
                          error: true);
                    }
                  }
                },
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                read
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: read ? AppColors.textSecondary : AppColors.green),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${item['title'] ?? ''}',
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text('${item['message'] ?? ''}',
                      style: AppTextStyles.caption),
                ])),
            if (!read)
              const Icon(Icons.circle, color: AppColors.green, size: 9),
          ]));
    }).toList();
  }

  List<Widget> _activity() {
    final items = Json.list(_data);
    if (items.isEmpty) {
      return [
        EmptyState(
            icon: Icons.history,
            title: _t('لا يوجد نشاط بعد', 'No activity yet'),
            message: _t('النشاط الأخير سيظهر هنا.',
                'Recent account activity will appear here.'))
      ];
    }
    return items.map((raw) {
      final item = Json.map(raw);
      return AppCard(
          child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history_rounded, color: AppColors.navy),
        title: Text('${item['action'] ?? '—'}', style: AppTextStyles.cardTitle),
        subtitle:
            Text('${item['description'] ?? ''}\n${item['createdAt'] ?? ''}'),
        isThreeLine: true,
      ));
    }).toList();
  }

  List<Widget> _knowledge() {
    final items = Json.list(_data);
    if (items.isEmpty) {
      return [
        EmptyState(
            icon: Icons.menu_book_outlined,
            title: _t('لا يوجد محتوى بعد', 'No guides yet'),
            message: _t('سيظهر محتوى التدريب الذي تنشره الإدارة هنا.',
                'Guides published by the admin will appear here.'))
      ];
    }
    return items.map((raw) {
      final item = Json.map(raw);
      final url = knowledgeResourceUrl(item);
      return AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${item['category'] ?? 'general'}',
            style: AppTextStyles.caption.copyWith(color: AppColors.greenInk)),
        const SizedBox(height: 4),
        Text('${item['title'] ?? ''}', style: AppTextStyles.cardTitle),
        const SizedBox(height: 8),
        Text('${item['body'] ?? ''}'),
        if (url.isNotEmpty)
          TextButton.icon(
              onPressed: () async {
                try {
                  final uri = await resolveKnowledgeResource(url);
                  if (!mounted) return;
                  await openExternalLink(context, uri.toString());
                } catch (_) {
                  if (mounted)
                    _notice(
                        _t('رابط المورد غير صالح أو لم يعد متاحًا. تواصل مع الدعم لتحديثه.',
                            'The resource link is invalid or no longer available. Ask support to update it.'),
                        error: true);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(_t('فتح المورد', 'Open resource'))),
      ]));
    }).toList();
  }

  List<Widget> _profile() {
    if (_form.isEmpty) _fillProfile(Json.map(_data));
    return [
      AppCard(
          child: Column(children: [
        _field('name', _t('اسم الحساب', 'Account name')),
        _field('email', _t('البريد الإلكتروني', 'Email'),
            keyboard: TextInputType.emailAddress),
        _field('companyName', _t('اسم الشركة', 'Company name')),
        _field('location', _t('الموقع', 'Location')),
        _field('phone', _t('الهاتف', 'Phone'), keyboard: TextInputType.phone),
        _field('address', _t('العنوان', 'Address')),
        _field('website', _t('الموقع الإلكتروني', 'Website'),
            keyboard: TextInputType.url),
        _field('taxId', _t('الرقم الضريبي', 'Tax ID')),
        _field('bio', _t('نبذة', 'About'), multiline: true),
        PrimaryButton(
            label: _saving
                ? _t('جارٍ الحفظ...', 'Saving...')
                : _t('حفظ بيانات الشركة', 'Save company profile'),
            onPressed: _saving ? null : _saveProfile),
      ])),
    ];
  }
}
