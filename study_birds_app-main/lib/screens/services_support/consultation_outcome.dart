import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_theme.dart';
import '../../core/repositories/consultation_repository.dart';

class ConsultationOutcomeView extends StatelessWidget {
  final Map<String, dynamic> outcome;
  const ConsultationOutcomeView({super.key, required this.outcome});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              outcome['result'] == 'no-show'
                  ? 'لم يحضر الطالب'
                  : 'استشارة مكتملة',
              style: AppTextStyles.cardTitle),
          Text('${outcome['summary'] ?? ''}'),
          if ('${outcome['nextSteps'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('الخطوات التالية', style: AppTextStyles.caption),
            Text('${outcome['nextSteps']}'),
          ],
        ],
      );
}

class ConsultationOutcomeEditor extends StatefulWidget {
  final Map<String, dynamic> booking;
  const ConsultationOutcomeEditor({super.key, required this.booking});

  @override
  State<ConsultationOutcomeEditor> createState() =>
      _ConsultationOutcomeEditorState();
}

class _ConsultationOutcomeEditorState extends State<ConsultationOutcomeEditor> {
  late final TextEditingController summary;
  late final TextEditingController nextSteps;
  late String result;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final outcome = widget.booking['outcome'] as Map?;
    summary = TextEditingController(text: '${outcome?['summary'] ?? ''}');
    nextSteps = TextEditingController(text: '${outcome?['nextSteps'] ?? ''}');
    result = outcome?['result'] == 'no-show' ? 'no-show' : 'completed';
  }

  @override
  void dispose() {
    summary.dispose();
    nextSteps.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || summary.text.trim().isEmpty) return;
    if (!await showAppConfirmDialog(context,
        title: 'مشاركة نتيجة الاستشارة',
        message:
            'سيظهر الملخص والخطوات التالية للطالب وسيصله إشعار داخل التطبيق.',
        confirmLabel: 'حفظ ومشاركة')) {
      return;
    }
    if (!mounted || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ConsultationRepository.instance.saveOutcome(widget.booking,
          result: result, summary: summary.text, nextSteps: nextSteps.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
            () => error = e is ApiException ? e.message : 'تعذر حفظ النتيجة.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'نتيجة الاستشارة',
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${widget.booking['student']?['name'] ?? 'الطالب'}',
              style: AppTextStyles.cardTitle),
          const Text(
              'هذه الملاحظات مشتركة مع الطالب. اكتب ملخص الاستشارة والخطوات المطلوبة منه.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
              initialValue: result,
              decoration: const InputDecoration(labelText: 'النتيجة'),
              items: const [
                DropdownMenuItem(
                    value: 'completed', child: Text('تمت الاستشارة')),
                DropdownMenuItem(
                    value: 'no-show', child: Text('لم يحضر الطالب')),
              ],
              onChanged:
                  saving ? null : (value) => setState(() => result = value!)),
          TextField(
              controller: summary,
              enabled: !saving,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'ملخص الاستشارة'),
              onChanged: (_) => setState(() {})),
          TextField(
              controller: nextSteps,
              enabled: !saving,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'الخطوات التالية (اختياري)')),
          if (error != null)
            Text(error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 16),
          PrimaryButton(
              label: saving ? 'جاري الحفظ...' : 'حفظ النتيجة',
              onPressed: saving || summary.text.trim().isEmpty ? null : save),
        ]),
      );
}
