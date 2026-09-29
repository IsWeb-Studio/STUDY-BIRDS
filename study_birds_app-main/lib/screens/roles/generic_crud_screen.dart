import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/admin_modules_repository.dart';

enum CrudFieldType { text, multiline, number, boolean, image }

class CrudField {
  final String key;
  final String label;
  final CrudFieldType type;
  final bool required;
  const CrudField(this.key, this.label, {this.type = CrudFieldType.text, this.required = false});
}

/// A generic "list + create/edit/delete" screen driven by a field spec.
/// Covers the simpler content-management sections whose backend payload is
/// a flat set of text/number/boolean fields (no nested arrays/rich media).
class GenericCrudScreen extends StatefulWidget {
  final String title;
  final List<CrudField> fields;
  final Future<List<dynamic>> Function() fetchItems;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload) createItem;
  final Future<Map<String, dynamic>> Function(String id, Map<String, dynamic> payload) updateItem;
  final Future<void> Function(String id)? deleteItem;
  final String Function(Map<String, dynamic> item) itemTitle;
  final String Function(Map<String, dynamic> item) itemSubtitle;
  final String idKey;
  /// For fields of type [CrudFieldType.image] — maps the field key to the
  /// backend's real upload endpoint (e.g. '/admin/countries/upload-image').
  final Map<String, String> imageUploadPaths;
  /// Override the multipart field name per image field — defaults to
  /// 'file'; the university logo endpoint expects 'files' (array upload).
  final Map<String, String> imageFieldNames;

  const GenericCrudScreen({
    super.key,
    required this.title,
    required this.fields,
    required this.fetchItems,
    required this.createItem,
    required this.updateItem,
    this.deleteItem,
    required this.itemTitle,
    required this.itemSubtitle,
    this.idKey = '_id',
    this.imageUploadPaths = const {},
    this.imageFieldNames = const {},
  });

  @override
  State<GenericCrudScreen> createState() => _GenericCrudScreenState();
}

class _GenericCrudScreenState extends State<GenericCrudScreen> {
  List<dynamic> _items = [];
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
      final data = await widget.fetchItems();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'تعذر تحميل البيانات.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final controllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};
    for (final f in widget.fields) {
      if (f.type == CrudFieldType.boolean) {
        boolValues[f.key] = existing?[f.key] == true;
      } else {
        controllers[f.key] = TextEditingController(text: existing?[f.key]?.toString() ?? '');
      }
    }
    String? formError;
    final uploadingFields = <String, bool>{};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing != null ? 'تعديل' : 'إضافة جديد', style: AppTextStyles.cardTitle),
                const SizedBox(height: 12),
                ...widget.fields.map((f) {
                  if (f.type == CrudFieldType.boolean) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(f.label),
                      value: boolValues[f.key] ?? false,
                      onChanged: (v) => setSheetState(() => boolValues[f.key] = v),
                    );
                  }
                  if (f.type == CrudFieldType.image) {
                    final uploadPath = widget.imageUploadPaths[f.key];
                    final isUploading = uploadingFields[f.key] == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.label, style: AppTextStyles.caption),
                          const SizedBox(height: 6),
                          if (controllers[f.key]!.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(controllers[f.key]!.text, height: 90, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(height: 90, child: Center(child: Icon(Icons.broken_image_outlined)))),
                              ),
                            ),
                          OutlinedButton.icon(
                            icon: isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_rounded, size: 18),
                            label: Text(isUploading ? 'جاري الرفع...' : 'اختيار ورفع صورة'),
                            onPressed: (isUploading || uploadPath == null)
                                ? null
                                : () async {
                                    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                                    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
                                    setSheetState(() => uploadingFields[f.key] = true);
                                    try {
                                      final url = await AdminModulesRepository.instance.uploadImage(
                                        uploadPath,
                                        fileBytes: result.files.single.bytes!,
                                        fileName: result.files.single.name,
                                        fileFieldName: widget.imageFieldNames[f.key] ?? 'file',
                                      );
                                      setSheetState(() {
                                        controllers[f.key]!.text = url;
                                        uploadingFields[f.key] = false;
                                      });
                                    } catch (e) {
                                      setSheetState(() {
                                        formError = e is ApiException ? e.message : 'تعذر رفع الصورة.';
                                        uploadingFields[f.key] = false;
                                      });
                                    }
                                  },
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[f.key],
                      keyboardType: f.type == CrudFieldType.number ? TextInputType.number : TextInputType.text,
                      maxLines: f.type == CrudFieldType.multiline ? 4 : 1,
                      decoration: InputDecoration(labelText: f.label + (f.required ? ' *' : '')),
                    ),
                  );
                }),
                if (formError != null) ...[
                  Text(formError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(
                  label: 'حفظ',
                  onPressed: () async {
                    final payload = <String, dynamic>{};
                    for (final f in widget.fields) {
                      if (f.type == CrudFieldType.boolean) {
                        payload[f.key] = boolValues[f.key] ?? false;
                      } else if (f.type == CrudFieldType.number) {
                        payload[f.key] = num.tryParse(controllers[f.key]!.text.trim()) ?? 0;
                      } else {
                        final value = controllers[f.key]!.text.trim();
                        if (f.required && value.isEmpty) {
                          setSheetState(() => formError = '${f.label} مطلوب');
                          return;
                        }
                        payload[f.key] = value;
                      }
                    }
                    try {
                      if (existing != null) {
                        await widget.updateItem(existing[widget.idKey] as String, payload);
                      } else {
                        await widget.createItem(payload);
                      }
                      if (context.mounted) Navigator.of(context).pop(true);
                    } catch (e) {
                      setSheetState(() => formError = e is ApiException ? e.message : 'تعذر الحفظ.');
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(String id) async {
    if (widget.deleteItem == null) return;
    try {
      await widget.deleteItem!(id);
      if (mounted) setState(() => _items.removeWhere((i) => (i as Map<String, dynamic>)[widget.idKey] == id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'تعذر الحذف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      actions: [IconButton(onPressed: () => _openForm(), icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white))],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(icon: Icons.inbox_outlined, title: 'لا توجد عناصر', message: 'أضف أول عنصر من زر الإضافة أعلى الشاشة.', ctaLabel: 'إضافة', onCta: () => _openForm())
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i] as Map<String, dynamic>;
                        return AppCard(
                          onTap: () => _openForm(existing: item),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.itemTitle(item), style: AppTextStyles.cardTitle),
                                    Text(widget.itemSubtitle(item), style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (widget.deleteItem != null)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                                  onPressed: () => _delete(item[widget.idKey] as String),
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
