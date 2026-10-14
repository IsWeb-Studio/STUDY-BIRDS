import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/utils/passport_scan.dart';
import 'package:study_birds/screens/profile_account/passport_scanner_screen.dart';
import 'passport_scan_test.dart' show td3;

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            PassportScan.channel,
            (_) async => {
                  'text': td3(),
                  'documentDetected': true,
                  'sharpness': 100.0,
                  'brightness': 120.0,
                  'glare': .02,
                  'confidence': .95
                });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(PassportScan.channel, null));
  final image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');

  testWidgets(
      'review requires consent, keeps user edits separate and returns only after confirmation',
      (tester) async {
    ReviewedPassportFile? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context)
                          .push<ReviewedPassportFile>(MaterialPageRoute(
                              builder: (_) => PassportScannerScreen(
                                  initialFile: PlatformFile(
                                      name: 'passport.png',
                                      size: image.length,
                                      bytes: image))));
                    },
                    child: const Text('scan'))))));
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة بيانات الجواز'), findsOneWidget);
    expect(result, isNull);
    final confirm =
        find.widgetWithText(FilledButton, 'تأكيد المعلومات ومتابعة الرفع');
    await tester.scrollUntilVisible(find.byType(TextFormField).first, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextFormField).first, 'ABC123');
    await tester.pump();
    expect(find.text('عدلته أنت؛ يحتاج مراجعة يدوية'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(confirm, 150,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.reviewedFields['number'], 'ABC123');
    expect(result!.analysis.mrz.details!.number, 'L898902C3');
    expect(result!.correctedFields, contains('number'));
    expect(result!.submissionMetadata['extracted'],
        isNot(result!.submissionMetadata['reviewed']));
  });

  testWidgets('PDF imports show the actual analyzed page preview',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            PassportScan.channel,
            (_) async => {
                  'text': td3(),
                  'documentDetected': false,
                  'sharpness': 100.0,
                  'brightness': 120.0,
                  'glare': .02,
                  'confidence': .95,
                  'originalPreviewBytes': image
                });
    final pdf = base64Decode('JVBERi0=');
    await tester.pumpWidget(MaterialApp(
        home: PassportScannerScreen(
            initialFile: PlatformFile(
                name: 'passport.pdf', size: pdf.length, bytes: pdf))));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('لم تتضح حدود المستند؛ راجع الصورة كاملة يدويًا.'),
        findsOneWidget);
  });

  testWidgets('failed MRZ cannot be confirmed or labeled complete',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            PassportScan.channel,
            (_) async => {
                  'text': 'random document',
                  'documentDetected': true,
                  'sharpness': 100.0,
                  'brightness': 120.0,
                  'glare': .02
                });
    await tester.pumpWidget(MaterialApp(
        home: PassportScannerScreen(
            initialFile: PlatformFile(
                name: 'other.png', size: image.length, bytes: image))));
    await tester.pumpAndSettle();
    expect(find.text('يلزم إعادة التصوير أو مراجعة يدوية'), findsOneWidget);
    expect(find.text('اكتمال المسح: أعد المحاولة'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(FilledButton), 200);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });
}
