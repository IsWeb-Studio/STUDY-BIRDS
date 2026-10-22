import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wink_local_game.dart';
import 'wink_feedback.dart';
import 'wink_playing_card.dart';
import 'wink_style.dart';

class WinkLocalScreen extends StatefulWidget {
  const WinkLocalScreen({super.key});
  @override
  State<WinkLocalScreen> createState() => _WinkLocalScreenState();
}

class _WinkLocalScreenState extends State<WinkLocalScreen>
    with WidgetsBindingObserver {
  final names = List.generate(11, (_) => TextEditingController());
  final feedback = WinkFeedback();
  WinkLocalGame? game;
  int count = 4;
  bool revealed = false, voterReady = false, sounds = false, vibration = false;
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          sounds = p.getBool('wink_sounds') ?? false;
          vibration = p.getBool('wink_vibration') ?? false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      feedback.stop();
      setState(() {
        revealed = false;
        voterReady = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    feedback.dispose();
    for (final name in names) {
      name.dispose();
    }
    super.dispose();
  }

  void cue(WinkCue cue) {
    feedback.play(cue, sound: sounds, vibration: vibration);
  }

  Future<void> audio() => showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Theme(
          data: WinkSky.theme(Theme.of(ctx)),
          child: SafeArea(
              child: StatefulBuilder(
                  builder: (ctx, update) =>
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        SwitchListTile(
                            title: Text(t(
                                'مؤثرات اللعبة الصوتية', 'Game sound effects')),
                            value: sounds,
                            onChanged: (v) async {
                              setState(() => sounds = v);
                              update(() {});
                              if (v) {
                                feedback.play(WinkCue.deal,
                                    sound: true, vibration: false);
                              } else {
                                feedback.stop();
                              }
                              await (await SharedPreferences.getInstance())
                                  .setBool('wink_sounds', v);
                            }),
                        SwitchListTile(
                            title: Text(t('اهتزاز خفيف', 'Light vibration')),
                            value: vibration,
                            onChanged: (v) async {
                              setState(() => vibration = v);
                              update(() {});
                              feedback.play(WinkCue.notice,
                                  sound: false, vibration: v);
                              await (await SharedPreferences.getInstance())
                                  .setBool('wink_vibration', v);
                            }),
                      ])))));

  void start() {
    setState(() {
      game = WinkLocalGame([
        for (int i = 0; i < count; i++)
          names[i].text.trim().isEmpty
              ? t('اللاعب ${i + 1}', 'Player ${i + 1}')
              : names[i].text.trim()
      ]);
      revealed = false;
      voterReady = false;
    });
    cue(WinkCue.deal);
  }

  void changed(void Function() action, WinkCue sound) {
    setState(action);
    cue(game?.phase == 'finished' ? WinkCue.finish : sound);
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(content: Text(text), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(t('إلغاء', 'Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(t('تأكيد', 'Confirm')))
              ])) ??
      false;
  Future<void> accuse() async {
    final g = game!;
    final eligible = g.living.where((p) => !g.accusedBy.contains(p)).toList();
    if (eligible.isEmpty) return;
    int accuser = eligible.first;
    int target = g.living.firstWhere((p) => p != accuser);
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: Text(t('اتهام وتصويت', 'Accusation and vote')),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<int>(
                          initialValue: accuser,
                          decoration: InputDecoration(
                              labelText: t('صاحب الاتهام', 'Accuser')),
                          items: [
                            for (final p in eligible)
                              DropdownMenuItem(
                                  value: p, child: Text(g.names[p]))
                          ],
                          onChanged: (v) => update(() {
                                accuser = v!;
                                if (target == accuser) {
                                  target =
                                      g.living.firstWhere((p) => p != accuser);
                                }
                              })),
                      DropdownButtonFormField<int>(
                          key: ValueKey(accuser),
                          initialValue: target,
                          decoration: InputDecoration(
                              labelText: t('المتهم', 'Suspect')),
                          items: [
                            for (final p in g.living.where((p) => p != accuser))
                              DropdownMenuItem(
                                  value: p, child: Text(g.names[p]))
                          ],
                          onChanged: (v) => update(() => target = v!)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(t('إلغاء', 'Cancel'))),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(t('بدء التصويت', 'Start voting')))
                    ])));
    if (yes == true && mounted) {
      changed(() {
        g.accuse(accuser, target);
        voterReady = false;
      }, WinkCue.vote);
    }
  }

  Future<void> rules() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Text(t(
                  'قواعد اللعبة\n\n4–11 شخصًا على جهاز واحد. مرّروا الجهاز بالترتيب؛ كل شخص يكشف كرتَه وحده ثم يخفيه قبل تمرير الجهاز. الغمّاز يغمز بعينه في الواقع. من تصله الغمزة ينتظر قليلًا ثم يعلن خروجه. لا تضغط خروج لاعب آخر. لكل لاعب حي اتهام واحد؛ كل الأحياء عدا المتهم يصوّتون سرًا بالتناوب. موافقة أكثر من النصف تخرج المتهم. يفوز اللاعبون بكشف الغمّاز، ويفوز الغمّاز إذا بقي مع لاعب واحد. لا مكافآت أو نتائج تنافسية في هذا الوضع.',
                  'Game rules\n\n4–11 people share one device. Pass it in order, view your card privately, then hide it before passing. The winker winks in real life. Recipients wait briefly then declare their own elimination. Each living player has one accusation; all other living players except the suspect vote privately in turn. A strict majority eliminates the suspect. Players win by finding the winker; the winker wins when only one opponent remains. No rewards or ranked results in this mode.')))));
  @override
  Widget build(BuildContext context) {
    final g = game;
    return Theme(
        data: WinkSky.theme(Theme.of(context)),
        child: PopScope(
            canPop: g == null || g.phase == 'finished',
            onPopInvokedWithResult: (didPop, _) async {
              if (!didPop &&
                  await confirm(t('إنهاء الجولة المحلية؟ لن تُحفظ الأدوار.',
                      'End this local round? Roles will not be saved.')) &&
                  mounted) {
                setState(() => game = null);
              }
            },
            child: Scaffold(
                appBar: AppBar(
                    title: Text(
                        t('جهاز واحد · 4–11 لاعبًا',
                            'One device · 4–11 players'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    actions: [
                      SizedBox(
                          width: 108,
                          child: TextButton(
                              onPressed: rules,
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child:
                                      Text(t('قواعد اللعبة', 'Game rules'))))),
                      IconButton(
                          tooltip: t('الصوت والاهتزاز', 'Sound and vibration'),
                          onPressed: audio,
                          icon: const Icon(Icons.tune)),
                    ]),
                body: ListView(padding: const EdgeInsets.all(20), children: [
                  Text(t(
                      'لعب محلي بدون إنترنت أو بوتات. لا تُحفظ الأدوار ولا تُحتسب مكافآت.',
                      'Offline play with no bots. Roles are not saved and no rewards are awarded.')),
                  const SizedBox(height: 20),
                  if (g == null) ...[
                    DropdownButtonFormField<int>(
                        initialValue: count,
                        decoration: InputDecoration(
                            labelText: t('عدد اللاعبين', 'Number of players')),
                        items: [
                          for (int i = 4; i <= 11; i++)
                            DropdownMenuItem(value: i, child: Text('$i'))
                        ],
                        onChanged: (v) => setState(() => count = v!)),
                    for (int i = 0; i < count; i++)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: TextField(
                              controller: names[i],
                              maxLength: 40,
                              decoration: InputDecoration(
                                  labelText: t('اسم اللاعب ${i + 1}',
                                      'Player ${i + 1} name'),
                                  counterText: ''))),
                    FilledButton.icon(
                        onPressed: start,
                        icon: const Icon(Icons.style),
                        label: Text(t('توزيع الكروت', 'Deal cards'))),
                  ] else if (g.phase == 'reveal') ...[
                    Text(
                        t('مرّر الجهاز إلى ${g.names[g.revealTurn]}',
                            'Pass the device to ${g.names[g.revealTurn]}'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Center(
                        child: SizedBox(
                            width: 170,
                            child: WinkPlayingCard(
                                key: ValueKey(g.revealTurn),
                                revealed: revealed,
                                number: revealed
                                    ? g.cardFor(g.revealTurn)
                                    : null))),
                    if (!revealed)
                      FilledButton(
                          onPressed: () =>
                              changed(() => revealed = true, WinkCue.reveal),
                          child: Text(t(
                              'أنا ${g.names[g.revealTurn]} · اكشف كرتي',
                              'I am ${g.names[g.revealTurn]} · Show my card')))
                    else ...[
                      Text(g.revealTurn == g.winker
                          ? t('أنت الغمّاز. أخفِ دورك!',
                              'You are the winker. Keep it secret!')
                          : t('أنت لاعب. اكتشف الغمّاز!',
                              'You are a player. Find the winker!')),
                      FilledButton(
                          onPressed: () => setState(() {
                                revealed = false;
                                g.confirmRole();
                              }),
                          child: Text(t(
                              'إخفاء وتمرير الجهاز', 'Hide and pass device'))),
                    ],
                  ] else if (g.phase == 'playing') ...[
                    Text(t('ابدأوا الغمز في الواقع. يُعلن كل لاعب خروجه بنفسه.',
                        'Wink in real life. Each player declares their own elimination.')),
                    for (final p in g.living)
                      Card(
                          child: ListTile(
                              title: Text(g.names[p]),
                              trailing: TextButton(
                                  onPressed: () async {
                                    if (await confirm(t(
                                            'أنا ${g.names[p]} ووصلتني غمزة. أؤكد خروجي؟',
                                            'I am ${g.names[p]} and was winked at. Confirm my elimination?')) &&
                                        mounted) {
                                      changed(() => g.winkedAt(p),
                                          WinkCue.elimination);
                                    }
                                  },
                                  child:
                                      Text(t('اتغمزلي', 'I was winked at'))))),
                    FilledButton(
                        onPressed: g.living.any((p) => !g.accusedBy.contains(p))
                            ? accuse
                            : null,
                        child: Text(t('اتهام وتصويت', 'Accusation and vote'))),
                  ] else if (g.phase == 'voting') ...[
                    Text(t('المتهم: ${g.names[g.suspect!]}',
                        'Suspect: ${g.names[g.suspect!]}')),
                    Text(t(
                        'مرّر الجهاز إلى ${g.names[g.nextVoter!]} للتصويت سرًا',
                        'Pass to ${g.names[g.nextVoter!]} to vote privately')),
                    if (!voterReady)
                      FilledButton(
                          onPressed: () => setState(() => voterReady = true),
                          child: Text(t('الجهاز معي · ابدأ تصويتي',
                              'I have the device · Vote')))
                    else ...[
                      for (final approve in [true, false])
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: FilledButton(
                                onPressed: () => changed(() {
                                      g.vote(g.nextVoter!, approve);
                                      voterReady = false;
                                    }, WinkCue.vote),
                                child: Text(approve
                                    ? t('موافق على الاتهام',
                                        'Approve accusation')
                                    : t('غير موافق / امتناع',
                                        'Reject / abstain'))))
                    ],
                  ] else ...[
                    Text(
                        g.winner == 'players'
                            ? t('فاز اللاعبون!', 'Players win!')
                            : t('فاز الغمّاز!', 'The winker wins!'),
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text(t('الغمّاز: ${g.names[g.winker]}',
                        'Winker: ${g.names[g.winker]}')),
                    FilledButton(
                        onPressed: start,
                        child: Text(t('جولة جديدة', 'New round'))),
                    TextButton(
                        onPressed: () => setState(() => game = null),
                        child: Text(t('تعديل اللاعبين', 'Edit players'))),
                  ],
                ]))));
  }
}
