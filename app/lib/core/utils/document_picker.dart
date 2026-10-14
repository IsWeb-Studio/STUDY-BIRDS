import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<PlatformFile?> pickDocument(BuildContext context,
    {bool passport = false}) async {
  try {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (passport)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('رفع جواز السفر'),
            ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('التقاط صورة بالكاميرا'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('اختيار من الصور'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('اختيار ملف PDF أو صورة'),
            onTap: () => Navigator.pop(ctx, 'file'),
          ),
        ]),
      ),
    );
    if (source == null || !context.mounted) return null;
    if (source == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      return result == null || result.files.isEmpty
          ? null
          : result.files.single;
    }
    final image = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    return PlatformFile(name: image.name, size: bytes.length, bytes: bytes);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'تعذر فتح الكاميرا أو قراءة المستند. تحقق من الأذونات وحاول مجددًا.'),
      ));
    }
    return null;
  }
}
