import 'package:flutter/material.dart';
import '../network/api_client.dart';
import 'app_components.dart';

class ClearCacheTile extends StatefulWidget {
  const ClearCacheTile({super.key});
  @override
  State<ClearCacheTile> createState() => _ClearCacheTileState();
}

class _ClearCacheTileState extends State<ClearCacheTile> {
  bool _busy = false;
  Future<void> _clear() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String message;
    try {
      await ApiClient.instance.clearDownloadedCache();
      await AppNetworkImage.clearDownloadedImages();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      message = ar
          ? 'تم مسح الكاش. حسابك ومستنداتك لم تُحذف.'
          : 'Cache cleared. Your account and documents were kept.';
    } catch (_) {
      message = ar
          ? 'تعذر مسح بعض الملفات. حاول مجددًا.'
          : 'Some cached files could not be cleared. Please retry.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return ListTile(
      leading: const Icon(Icons.cleaning_services_outlined),
      title: Text(ar ? 'مسح الكاش' : 'Clear cache'),
      subtitle: Text(ar
          ? 'تنظيف الصور والبيانات المؤقتة المحفوظة على الجهاز'
          : 'Remove downloaded images and temporary saved data'),
      trailing: _busy
          ? const SizedBox.square(
              dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: _busy ? null : _clear,
    );
  }
}
