import 'package:flutter/material.dart';

import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/employee_repository.dart';
import '../../core/utils/json_safe.dart';

class AdminStudentProfileScreen extends StatefulWidget {
  final String studentId;

  const AdminStudentProfileScreen({super.key, required this.studentId});

  @override
  State<AdminStudentProfileScreen> createState() =>
      _AdminStudentProfileScreenState();
}

class _AdminStudentProfileScreenState extends State<AdminStudentProfileScreen> {
  Map<String, dynamic>? _details;
  Map<String, dynamic> _team = const {};
  bool _loading = true;
  bool _saving = false;
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
      final results = await Future.wait([
        EmployeeRepository.instance.getStudentDetails(widget.studentId),
        EmployeeRepository.instance.getStudentSupportTeam(widget.studentId),
      ]);
      if (!mounted) return;
      setState(() {
        _details = Json.map(results[0]);
        _team = Json.map(results[1]);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            error is ApiException ? error.message : 'تعذر تحميل ملف الطالب.';
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus() async {
    final student = Json.mapOrNull(_details?['student']);
    if (student == null || _saving) return;
    final next = student['isActive'] == false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(next ? 'تفعيل حساب الطالب' : 'تعطيل حساب الطالب'),
        content: Text(next
            ? 'سيتمكن الطالب من الدخول إلى حسابه.'
            : 'سيتوقف الطالب عن الدخول إلى حسابه.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await EmployeeRepository.instance
          .updateStudentStatus(widget.studentId, isActive: next);
      if (!mounted) return;
      setState(() => _details = {
            ...?_details,
            'student': {...student, ...updated}
          });
      _notice(next ? 'تم تفعيل حساب الطالب.' : 'تم تعطيل حساب الطالب.');
    } catch (error) {
      if (mounted) {
        _notice(
            error is ApiException ? error.message : 'تعذر تحديث حالة الحساب.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editTeam() async {
    if (_team['canEdit'] != true || _saving) return;
    final candidates = Json.list(_team['candidates']).map(Json.map).toList();
    final selected =
        (Json.list(_team['memberIds'])).map((id) => id.toString()).toSet();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          StatefulBuilder(builder: (context, setSheetState) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('الموظفون المسؤولون عن الطالب',
                      style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 6),
                  const Text(
                      'اختر الموظفين الذين سيتابعون هذا الطالب. سيصل للطالب إشعار عند إضافة مسؤول جديد.'),
                  const SizedBox(height: 8),
                  Flexible(
                      child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (_, index) {
                      final person = candidates[index];
                      final id = person['_id']?.toString() ?? '';
                      if (id.isEmpty) return const SizedBox.shrink();
                      return CheckboxListTile(
                        value: selected.contains(id),
                        title: Text(person['name'] as String? ?? 'موظف'),
                        subtitle: Text(
                            person['employeeRole'] as String? ?? 'فريق الدعم'),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                      );
                    },
                  )),
                  const SizedBox(height: 10),
                  FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('حفظ الفريق')),
                ]),
          ),
        );
      }),
    );
    if (saved != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await EmployeeRepository.instance.saveStudentSupportTeam(widget.studentId,
          memberIds: selected.toList());
      await _load();
      if (mounted) _notice('تم حفظ فريق متابعة الطالب.');
    } catch (error) {
      if (mounted) {
        _notice(
            error is ApiException ? error.message : 'تعذر حفظ فريق الطالب.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editAdvisor() async {
    if (_team['canEdit'] != true || _saving) return;
    final candidates = Json.list(_team['candidates']).map(Json.map).toList();
    final current = Json.mapOrNull(_team['crmAdvisor']);
    String? selected = current?['_id']?.toString();
    final advisorId = await showDialog<String?>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('مستشار الطالب'),
          content: DropdownButtonFormField<String?>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المستشار المسؤول'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('بدون مستشار')),
              ...candidates.map((person) => DropdownMenuItem<String?>(
                    value: person['_id']?.toString(),
                    child: Text(person['name'] as String? ?? 'موظف',
                        overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (id) => setDialogState(() => selected = id),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected ?? ''),
                child: const Text('حفظ')),
          ],
        );
      }),
    );
    if (advisorId == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await EmployeeRepository.instance.saveStudentAdvisor(widget.studentId,
          advisorId: advisorId.isEmpty ? null : advisorId);
      await _load();
      if (mounted) _notice('تم تحديث مستشار الطالب.');
    } catch (error) {
      if (mounted) {
        _notice(error is ApiException
            ? error.message
            : 'تعذر تحديث مستشار الطالب.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'ملف الطالب',
      body: _loading
          ? const LoadingState(message: 'جاري تحميل ملف الطالب...')
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _buildDetails(),
    );
  }

  Widget _buildDetails() {
    final student =
        Json.mapOrNull(_details?['student']) ?? const <String, dynamic>{};
    final profile =
        Json.mapOrNull(student['profile']) ?? const <String, dynamic>{};
    final active = student['isActive'] != false;
    final applications =
        Json.list(_details?['applications']).map(Json.map).toList();
    final documents = Json.list(_details?['documents']).map(Json.map).toList();
    final invoices = Json.list(_details?['invoices']).map(Json.map).toList();
    final proofs = Json.list(_details?['paymentProofs']).map(Json.map).toList();
    final tickets =
        Json.list(_details?['supportTickets']).map(Json.map).toList();
    final notifications =
        Json.list(_details?['notifications']).map(Json.map).toList();
    final favorites = Json.list(_details?['favorites']).map(Json.map).toList();
    final assigned = Json.list(_team['teamMembers']).map(Json.map).toList();
    final advisor = Json.mapOrNull(_team['crmAdvisor']);
    final orientation = Json.mapOrNull(_details?['orientationResult']);
    final arrival = Json.mapOrNull(_details?['arrivalRequest']);
    final paidAmount = invoices
        .where((invoice) => invoice['status'] == 'paid')
        .fold<num>(
            0,
            (total, invoice) =>
                total + (num.tryParse('${invoice['amount'] ?? 0}') ?? 0));
    final outstandingAmount = invoices
        .where((invoice) => invoice['status'] != 'paid')
        .fold<num>(
            0,
            (total, invoice) =>
                total + (num.tryParse('${invoice['amount'] ?? 0}') ?? 0));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.greenSoft,
                child: Icon(Icons.person_rounded, color: AppColors.navy)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(student['name'] as String? ?? 'طالب',
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text(student['email'] as String? ?? '',
                      style: AppTextStyles.caption),
                ])),
            StatusBadge(
                label: active ? 'نشط' : 'معطل',
                color: active ? AppColors.success : AppColors.danger),
          ]),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _saving ? null : _changeStatus,
            icon: Icon(
                active ? Icons.block_outlined : Icons.check_circle_outline),
            label: Text(active ? 'تعطيل الحساب' : 'تفعيل الحساب'),
          ),
        ])),
        AppCard(
            child: Wrap(spacing: 10, runSpacing: 10, children: [
          _stat('الطلبات', '${applications.length}'),
          _stat('المستندات', '${documents.length}'),
          _stat('تذاكر الدعم', '${tickets.length}'),
          _stat('المستحق', _money(outstandingAmount)),
          _stat('المدفوع', _money(paidAmount)),
        ])),
        _section('البيانات الشخصية', [
          _field('الهاتف', profile['phone']),
          _field('الجنسية', profile['nationality']),
          _field('تاريخ الميلاد', profile['dateOfBirth']),
          _field('رقم جواز السفر', profile['passportNumber']),
          _field('المرحلة التعليمية', profile['currentEducation']),
          _field('المعدل', profile['gpa']),
          _field('موعد الدراسة', profile['intake']),
          _field('العنوان', profile['address']),
          _field(
              'الدول المستهدفة',
              (Json.listOrNull(profile['targetCountries']) ?? const [])
                  .join('، ')),
          _field('تاريخ إنشاء الحساب', _date(student['createdAt'])),
        ]),
        _section('فريق المتابعة', [
          if (advisor != null)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: const Text('مستشار CRM'),
                subtitle: Text(advisor['name'] as String? ?? '—')),
          if (assigned.isEmpty && advisor == null)
            const Text('لم يتم تعيين مسؤولين لهذا الطالب بعد.'),
          ...assigned.map((member) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.support_agent_rounded),
              title: Text(member['name'] as String? ?? 'موظف'),
              subtitle:
                  Text(member['employeeRole'] as String? ?? 'فريق المتابعة'))),
          if (_team['canEdit'] == true)
            Wrap(spacing: 8, runSpacing: 4, children: [
              OutlinedButton.icon(
                  onPressed: _saving ? null : _editTeam,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('تعديل الفريق')),
              OutlinedButton.icon(
                  onPressed: _saving ? null : _editAdvisor,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('تعديل المستشار')),
            ]),
        ]),
        _section(
            'طلبات القبول (${applications.length})',
            applications.isEmpty
                ? const [Text('لا توجد طلبات بعد.')]
                : applications
                    .take(8)
                    .map((application) => _record(
                          application['program'] is Map
                              ? Json.map(application['program'])['title']
                              : 'طلب دراسي',
                          '${application['status'] ?? '—'}${application['program'] is Map && Json.map(application['program'])['university'] is Map ? ' • ${Json.map(Json.map(application['program'])['university'])['name'] ?? ''}' : ''}',
                        ))
                    .toList()),
        _section(
            'المستندات (${documents.length})',
            documents.isEmpty
                ? const [Text('لا توجد مستندات.')]
                : documents
                    .take(8)
                    .map((document) => _record(
                        document['fileName'] ?? document['type'] ?? 'مستند',
                        document['detailedStatus'] ??
                            document['status'] ??
                            '—'))
                    .toList()),
        _section(
            'الفواتير والمدفوعات (${invoices.length} / ${proofs.length})', [
          if (invoices.isEmpty && proofs.isEmpty)
            const Text('لا توجد فواتير أو إثباتات دفع.'),
          ...invoices.take(5).map((invoice) => _record(
              invoice['description'] ?? invoice['invoiceNumber'] ?? 'فاتورة',
              '${invoice['amount'] ?? '—'} • ${invoice['status'] ?? '—'}')),
          ...proofs.take(3).map((proof) =>
              _record('إثبات دفع', proof['status'] ?? 'قيد المراجعة')),
        ]),
        _section('الوصول والخدمات', [
          _record('حالة طلب الوصول', arrival?['status'] ?? 'لا يوجد طلب'),
          if (arrival != null)
            _record('الخدمات', _services(arrival['services'])),
        ]),
        _section(
            'الدعم والإشعارات (${tickets.length} / ${notifications.length})', [
          if (tickets.isEmpty && notifications.isEmpty)
            const Text('لا توجد تذاكر أو إشعارات حديثة.'),
          ...tickets.take(4).map((ticket) => _record(
              ticket['subject'] ?? 'تذكرة دعم', ticket['status'] ?? '—')),
          ...notifications.take(4).map((notification) => _record(
              notification['title'] ?? 'إشعار',
              _date(notification['createdAt']))),
        ]),
        _section('المفضلة ونتيجة التوجيه', [
          _record('العناصر المفضلة', '${favorites.length}'),
          _record(
              'نتيجة اختبار التوجيه',
              orientation?['recommendationSummary'] ??
                  (orientation == null ? 'لا توجد نتيجة' : 'متوفرة')),
          if (orientation != null)
            _record(
                'المجالات المقترحة',
                (Json.listOrNull(orientation['suggestedFields']) ?? const [])
                    .join('، ')),
        ]),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _field(String title, dynamic value) {
    final text = value is String ? value.trim() : value?.toString() ?? '';
    if (text.isEmpty || text == 'null') return const SizedBox.shrink();
    return _record(title, text);
  }

  Widget _stat(String title, String value) => Container(
        constraints: const BoxConstraints(minWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.cardTitle),
        ]),
      );

  String _money(num amount) => amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);

  Widget _record(dynamic title, dynamic value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 2,
              child: Text(title.toString(), style: AppTextStyles.caption)),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: Text(value?.toString() ?? '—',
                  textAlign: TextAlign.end, style: AppTextStyles.body)),
        ]),
      );

  String _date(dynamic value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null
        ? value.toString()
        : '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  String _services(dynamic value) {
    final services = Json.mapOrNull(value);
    if (services == null) return '—';
    const labels = {
      'airportPickup': 'استقبال المطار',
      'studentHousing': 'السكن الطلابي',
      'residencePermitSupport': 'دعم الإقامة',
      'visaSupport': 'دعم التأشيرة',
    };
    final enabled = labels.entries
        .where((entry) => services[entry.key] == true)
        .map((entry) => entry.value)
        .toList();
    return enabled.isEmpty ? 'لا توجد خدمات محددة' : enabled.join('، ');
  }
}
