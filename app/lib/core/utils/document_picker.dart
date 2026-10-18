import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../screens/profile_account/passport_scanner_screen.dart';

Future<PlatformFile?> pickDocument(BuildContext context,
    {bool passport = false, bool allowPassportEditing = true}) async {
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
    if (passport && source == 'camera') {
      return await Navigator.of(context).push<ReviewedPassportFile>(
          MaterialPageRoute(
              builder: (_) =>
                  PassportScannerScreen(allowEditing: allowPassportEditing)));
    }
    if (source == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      if (!passport || !context.mounted) return passport ? null : file;
      return await Navigator.of(context).push<ReviewedPassportFile>(
          MaterialPageRoute(
              builder: (_) => PassportScannerScreen(
                  initialFile: file, allowEditing: allowPassportEditing)));
    }
    final image = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    final file =
        PlatformFile(name: image.name, size: bytes.length, bytes: bytes);
    if (!passport || !context.mounted) return passport ? null : file;
    return await Navigator.of(context).push<ReviewedPassportFile>(
        MaterialPageRoute(
            builder: (_) => PassportScannerScreen(
                initialFile: file, allowEditing: allowPassportEditing)));
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
