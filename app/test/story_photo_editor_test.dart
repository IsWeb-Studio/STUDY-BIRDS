import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:study_birds/screens/stories/story_photo_editor.dart';

void main() {
  final image =
      Uint8List.fromList(img.encodePng(img.Image(width: 32, height: 32)));
  testWidgets(
      'cancel keeps source intact; confirming returns exported bytes only',
      (tester) async {
    EditedStoryPhoto? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await Navigator.of(context).push<EditedStoryPhoto>(
                      MaterialPageRoute(
                          builder: (_) => StoryPhotoEditor(
                              bytes: image, publishOnConfirm: true)));
                },
              ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text, stickers & filters'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 400));
    final editor = tester.widget<ProImageEditor>(find.byType(ProImageEditor));
    final exported = Uint8List.fromList(image);
    await editor.callbacks.onImageEditingComplete!(exported);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish story'));
    await tester.pumpAndSettle();
    expect(identical(result!.image, exported), isTrue);
    expect(result!.audio, isNull);
    expect(
        image,
        equals(Uint8List.fromList(
            img.encodePng(img.Image(width: 32, height: 32)))));
  });
  testWidgets('photo preview fits narrow Arabic screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!),
      home: StoryPhotoEditor(bytes: image, publishOnConfirm: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('نشر الستوري'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
