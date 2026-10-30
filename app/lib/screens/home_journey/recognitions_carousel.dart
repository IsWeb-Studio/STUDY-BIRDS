import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/external_link.dart';

class RecognitionsCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> recognitions;
  const RecognitionsCarousel({super.key, required this.recognitions});

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.textScalerOf(context).scale(14);
    return SizedBox(
      height: 140 + fontSize * 2.8 + 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recognitions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: (MediaQuery.sizeOf(context).width * .55).clamp(184.0, 260.0),
          child: RecognitionCard(recognition: recognitions[index]),
        ),
      ),
    );
  }
}

class RecognitionCard extends StatelessWidget {
  final Map<String, dynamic> recognition;
  const RecognitionCard({super.key, required this.recognition});

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
    const fallback = Center(
        child: Icon(Icons.workspace_premium_outlined,
            size: 52, color: AppColors.greenInk));
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
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
              height: 132,
              child: Stack(fit: StackFit.expand, children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: image.isEmpty
                        ? fallback
                        : AppNetworkImage(image,
                            height: 108,
                            fit: BoxFit.contain,
                            errorWidget: fallback)),
                PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: Tooltip(
                      message:
                          ar ? 'شهادة أو اعتراف' : 'Certificate or recognition',
                      child: Container(
                        key: const ValueKey('recognition-seal'),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.verified,
                            size: 24, color: AppColors.greenInk),
                      ),
                    )),
              ])),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Center(
                child: Text(caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
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
