import '../../core/utils/json_safe.dart';
import '../../core/widgets/feature_ui.dart';
import '../../core/widgets/app_notice.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/repositories/admin_modules_repository.dart';

enum CrudFieldType { text, multiline, number, boolean, image }

class CrudField {
  final String key;
  final String label;
  final CrudFieldType type;
  final bool required;
  final bool initialBoolValue;
  final Map<String, String>? choices;
  const CrudField(this.key, this.label,
      {this.type = CrudFieldType.text,
      this.required = false,
      this.choices,
      this.initialBoolValue = false});
}

/// A generic "list + create/edit/delete" screen driven by a field spec.
/// Covers the simpler content-management sections whose backend payload is
/// a flat set of text/number/boolean fields (no nested arrays/rich media).
class GenericCrudScreen extends StatefulWidget {
  final String title;
  final List<CrudField> fields;
  final Future<List<dynamic>> Function() fetchItems;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)
      createItem;
  final Future<Map<String, dynamic>> Function(
      String id, Map<String, dynamic> payload) updateItem;
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
        boolValues[f.key] =
            existing == null ? f.initialBoolValue : existing[f.key] == true;
      } else {
        controllers[f.key] = TextEditingController(
            text:
                existing?[f.key]?.toString() ?? (f.choices?.keys.first ?? ''));
      }
    }
    String? formError;
    final uploadingFields = <String, bool>{};
    final uploadErrors = <String, String>{};
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
              left: 16,
              right: 16,
              top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing != null ? 'تعديل' : 'إضافة جديد',
                    style: AppTextStyles.cardTitle),
                const SizedBox(height: 12),
                ...widget.fields.map((f) {
                  if (f.type == CrudFieldType.boolean) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(f.label),
                      value: boolValues[f.key] ?? false,
                      onChanged: (v) =>
                          setSheetState(() => boolValues[f.key] = v),
                    );
                  }
                  if (f.choices != null) {
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              f.choices!.containsKey(controllers[f.key]!.text)
                                  ? controllers[f.key]!.text
                                  : f.choices!.keys.first,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: f.label),
                          items: f.choices!.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) controllers[f.key]!.text = value;
                          },
                        ));
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
                                child: AppNetworkImage(controllers[f.key]!.text,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorWidget: const SizedBox(
                                        height: 90,
                                        child: Center(
                                            child: Icon(
                                                Icons.broken_image_outlined)))),
                              ),
                            ),
                          OutlinedButton.icon(
                            icon: isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.upload_rounded, size: 18),
                            label: Text(isUploading
                                ? 'جاري الرفع...'
                                : 'اختيار ورفع صورة'),
                            onPressed: (isUploading ||
                                    saving ||
                                    uploadPath == null)
                                ? null
                                : () async {
                                    setSheetState(() {
                                      uploadingFields[f.key] = true;
                                      uploadErrors.remove(f.key);
                                      formError = null;
                                    });
                                    try {
                                      final result = await FilePicker.platform
                                          .pickFiles(
                                              type: FileType.image,
                                              withData: true);
                                      if (!context.mounted ||
                                          result == null ||
                                          result.files.isEmpty) return;
                                      final file = result.files.single;
                                      if (file.size > 5 * 1024 * 1024)
                                        throw const ApiException(413,
                                            'اختر صورة أصغر من 5 ميجابايت.');
                                      final bytes = file.bytes ??
                                          await file.xFile.readAsBytes();
                                      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024)
                                        throw const ApiException(400,
                                            'تعذر قراءة الصورة المختارة. اخترها مجددًا.');
                                      if (!context.mounted) return;
                                      final url = await AdminModulesRepository
                                          .instance
                                          .uploadImage(
                                        uploadPath,
                                        fileBytes: bytes,
                                        fileName: file.name,
                                        fileFieldName:
                                            widget.imageFieldNames[f.key] ??
                                                'file',
                                      );
                                      if (!context.mounted) return;
                                      setSheetState(() {
                                        controllers[f.key]!.text = url;
                                      });
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      setSheetState(() {
                                        uploadErrors[f.key] = e is ApiException
                                            ? e.message
                                            : 'تعذر رفع الصورة.';
                                      });
                                    } finally {
                                      if (context.mounted)
                                        setSheetState(() =>
                                            uploadingFields[f.key] = false);
                                    }
                                  },
                          ),
                          if (uploadErrors[f.key] != null) ...[
                            InlineNotice(uploadErrors[f.key]!, error: true),
                            TextButton(
                                onPressed: () => setSheetState(
                                    () => uploadErrors.remove(f.key)),
                                child: Text(controllers[f.key]!.text.isEmpty
                                    ? 'المتابعة بدون صورة'
                                    : 'إبقاء الصورة السابقة')),
                          ],
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[f.key],
                      keyboardType: f.type == CrudFieldType.number
                          ? TextInputType.number
                          : TextInputType.text,
                      maxLines: f.type == CrudFieldType.multiline ? 4 : 1,
                      decoration: InputDecoration(
                          labelText: f.label + (f.required ? ' *' : '')),
                    ),
                  );
                }),
                if (formError != null) ...[
                  InlineNotice(formError!, error: true),
                  const SizedBox(height: 8),
                ],
                PrimaryButton(
                  label: 'حفظ',
                  onPressed: saving ||
                          uploadErrors.isNotEmpty ||
                          uploadingFields.values.any((value) => value)
                      ? null
                      : () async {
                          if (saving ||
                              uploadErrors.isNotEmpty ||
                              uploadingFields.values.any((value) => value))
                            return;
                          final payload = <String, dynamic>{};
                          for (final f in widget.fields) {
                            if (f.type == CrudFieldType.boolean) {
                              payload[f.key] = boolValues[f.key] ?? false;
                            } else if (f.type == CrudFieldType.number) {
                              payload[f.key] = num.tryParse(
                                      controllers[f.key]!.text.trim()) ??
                                  0;
                            } else {
                              final value = controllers[f.key]!.text.trim();
                              if (f.required && value.isEmpty) {
                                setSheetState(
                                    () => formError = '${f.label} مطلوب');
                                return;
                              }
                              payload[f.key] = value;
                            }
                          }
                          try {
                            setSheetState(() {
                              saving = true;
                              formError = null;
                            });
                            if (existing != null) {
                              await widget.updateItem(
                                  existing[widget.idKey] as String, payload);
                            } else {
                              await widget.createItem(payload);
                            }
                            if (context.mounted)
                              Navigator.of(context).pop(true);
                          } catch (e) {
                            if (!context.mounted) return;
                            setSheetState(() => formError =
                                e is ApiException ? e.message : 'تعذر الحفظ.');
                          } finally {
                            if (context.mounted)
                              setSheetState(() => saving = false);
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
      if (mounted) {
        setState(
            () => _items.removeWhere((i) => (Json.map(i))[widget.idKey] == id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
            content: Text(e is ApiException ? e.message : 'تعذر الحذف')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title,
      actions: [
        IconButton(
            tooltip: 'إضافة',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: Colors.white))
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.navy,
        child: _loading
            ? const LoadingState()
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'لا توجد عناصر',
                        message: 'أضف أول عنصر من زر الإضافة أعلى الشاشة.',
                        ctaLabel: 'إضافة',
                        onCta: () => _openForm())
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final item = Json.map(_items[i]);
                          return AppCard(
                            onTap: () => _openForm(existing: item),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.itemTitle(item),
                                          style: AppTextStyles.cardTitle),
                                      Text(widget.itemSubtitle(item),
                                          style: AppTextStyles.caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (widget.deleteItem != null)
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.danger),
                                    onPressed: () =>
                                        _delete(item[widget.idKey] as String),
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
