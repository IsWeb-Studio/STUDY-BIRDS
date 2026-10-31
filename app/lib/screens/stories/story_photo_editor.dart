import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class EditedStoryPhoto {
  final Uint8List image;
  final Uint8List? audio;
  final String? audioName;
  const EditedStoryPhoto(this.image, this.audio, this.audioName);
  String get imageName {
    if (image.length >= 8 && image[0] == 137 && image[1] == 80) {
      return 'story.png';
    }
    if (image.length >= 12 && image[0] == 82 && image[8] == 87) {
      return 'story.webp';
    }
    return 'story.jpg';
  }
}

/// Editing is local. Nothing is uploaded until the caller publishes the result.
class StoryPhotoEditor extends StatefulWidget {
  final Uint8List bytes;
  final bool publishOnConfirm;
  const StoryPhotoEditor(
      {super.key, required this.bytes, this.publishOnConfirm = false});
  @override
  State<StoryPhotoEditor> createState() => _StoryPhotoEditorState();
}

class _StoryPhotoEditorState extends State<StoryPhotoEditor>
    with WidgetsBindingObserver {
  late Uint8List _image = widget.bytes;
  PlatformFile? _audio;
  AudioPlayer? _player;
  AudioPlayer get _sound => _player ??= AudioPlayer();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _player?.pause();
  }

  bool _busy = false;
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    await _player?.pause();
    if (!mounted) return;
    final result =
        await Navigator.of(context).push<Uint8List>(MaterialPageRoute(
      builder: (ctx) => ProImageEditor.memory(
        _image,
        configs: ProImageEditorConfigs(
          imageGeneration: const ImageGenerationConfigs(
              enableUseOriginalBytes: false,
              jpegQuality: 85,
              maxOutputSize: Size(1600, 2000)),
          i18n: I18n(
            cancel: t('إلغاء', 'Cancel'),
            done: t('حفظ', 'Done'),
            undo: t('تراجع', 'Undo'),
            redo: t('إعادة', 'Redo'),
            remove: t('حذف', 'Remove'),
            doneLoadingMsg: t('جارٍ حفظ التعديلات', 'Saving edits'),
            textEditor: I18nTextEditor(
                inputHintText: t('اكتب النص', 'Enter text'),
                bottomNavigationBarText: t('نص', 'Text'),
                done: t('حفظ', 'Done'),
                back: t('رجوع', 'Back')),
            paintEditor: I18nPaintEditor(
                bottomNavigationBarText: t('رسم', 'Draw'),
                done: t('حفظ', 'Done'),
                back: t('رجوع', 'Back')),
            filterEditor: I18nFilterEditor(
                bottomNavigationBarText: t('فلاتر', 'Filters'),
                done: t('حفظ', 'Done'),
                back: t('رجوع', 'Back')),
          ),
        ),
        callbacks:
            ProImageEditorCallbacks(onImageEditingComplete: (bytes) async {
          if (ctx.mounted) Navigator.pop(ctx, bytes);
        }),
      ),
    ));
    if (mounted && result != null) setState(() => _image = result);
  }

  Future<void> _pickAudio() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'm4a', 'wav'],
          withData: true);
      if (!mounted || picked == null) return;
      final file = picked.files.single;
      if (file.size > 10 * 1024 * 1024 ||
          file.bytes == null ||
          file.path == null) {
        throw Exception(t('اختر ملف صوت أصغر من 10 ميجابايت.',
            'Choose audio smaller than 10 MB.'));
      }
      await _player?.pause();
      if (!mounted) return;
      setState(() => _audio = null);
      final duration = await _sound.setFilePath(file.path!);
      if (!mounted) return;
      if (duration == null ||
          duration <= Duration.zero ||
          duration > const Duration(seconds: 60)) {
        throw Exception(t('اختر صوتًا مدته 60 ثانية أو أقل.',
            'Choose audio up to 60 seconds.'));
      }
      if (mounted) setState(() => _audio = file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('تعديل الستوري', 'Edit story'))),
        body: Column(children: [
          Expanded(
              child: Center(child: Image.memory(_image, fit: BoxFit.contain))),
          if (_audio != null)
            ListTile(
                title: Text(_audio!.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                leading: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _busy
                        ? null
                        : () {
                            _player?.seek(Duration.zero);
                            _player?.play().catchError((Object _) {});
                          }),
                trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _busy
                        ? null
                        : () {
                            _player?.stop();
                            setState(() => _audio = null);
                          })),
          SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _edit,
                            icon: const Icon(Icons.edit),
                            label: Text(t('كتابة، ملصقات وفلاتر',
                                'Text, stickers & filters'))),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _pickAudio,
                            icon: const Icon(Icons.music_note),
                            label: Text(t('صوت من الجهاز', 'Device audio'))),
                        FilledButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.pop(
                                    context,
                                    EditedStoryPhoto(
                                        _image, _audio?.bytes, _audio?.name)),
                            child: Text(widget.publishOnConfirm
                                ? t('نشر الستوري', 'Publish story')
                                : t('استخدام الصورة', 'Use photo'))),
                      ]))),
        ]),
      );
}
