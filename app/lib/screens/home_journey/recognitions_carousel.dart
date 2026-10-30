import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/external_link.dart';

class RecognitionsCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> recognitions;
  const RecognitionsCarousel({super.key, required this.recognitions});

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.textScalerOf(context).scale(11);
    return SizedBox(
      height: 54 + fontSize * 2.8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recognitions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => SizedBox(
          width: 130,
          child: RecognitionCard(recognition: recognitions[index]),
        ),
      ),
    );
  }
}

class RecognitionCard extends StatelessWidget {
  final Map<String, dynamic> recognition;
  const RecognitionCard({super.key, required this.recognition});

  // Artwork only for records already supplied by the server; never inserts
  // additional accreditations. An admin-uploaded image takes precedence.
  static String? artworkFor(String title) {
    final name = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (name.startsWith('iso10002')) return 'iso-10002.png';
    if (name.startsWith('iso9001')) return 'iso-9001.png';
    if (name.startsWith('britishcouncil')) return 'british-council.png';
    if (name == 'technesummit') return 'techne-summit.png';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final title = '${recognition['title'] ?? ''}'.trim();
    final rawImage = '${recognition['image'] ?? ''}'.trim();
    final uri = Uri.tryParse(rawImage);
    final image = uri != null &&
            ['https', 'http'].contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? rawImage
        : '';
    final link = '${recognition['link'] ?? ''}'.trim();
    final caption = title.isEmpty
        ? (ar ? 'شهادة أو اعتراف' : 'Certificate or recognition')
        : title;
    final artwork = artworkFor(title);
    final fallback = artwork == null
        ? const Center(
            child: Icon(Icons.workspace_premium_outlined,
                size: 30, color: AppColors.greenInk))
        : Image.asset(
            'assets/images/branding/recognitions/$artwork',
            fit: BoxFit.contain,
            color: artwork == 'techne-summit.png' ? AppColors.navy : null,
          );
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        key: ValueKey('recognition-${recognition['_id'] ?? caption}'),
        onTap: link.isNotEmpty
            ? () => openExternalLink(context, link)
            : image.isNotEmpty
                ? () => _preview(context, image, caption)
                : null,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: image.isEmpty
                  ? fallback
                  : AppNetworkImage(image,
                      height: 48, fit: BoxFit.contain, errorWidget: fallback),
            ),
          ),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Center(
                child: Text(caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.navy))),
          )),
        ]),
      ),
    );
  }

  Future<void> _preview(BuildContext context, String image, String title) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
            child: SizedBox(
          width: 600,
          height: MediaQuery.sizeOf(dialogContext).height * .75,
          child: Column(children: [
            Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: Row(children: [
                  Expanded(
                      child: Text(title,
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                  IconButton(
                      tooltip: MaterialLocalizations.of(dialogContext)
                          .closeButtonTooltip,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close)),
                ])),
            Expanded(
                child: InteractiveViewer(
                    maxScale: 4,
                    child: AppNetworkImage(image,
                        width: 600,
                        fit: BoxFit.contain,
                        errorWidget: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 48)))),
          ]),
        )),
      );
}
