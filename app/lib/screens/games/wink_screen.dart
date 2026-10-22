import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/json_safe.dart';
import 'wink_controller.dart';
import 'wink_playing_card.dart';
import 'wink_style.dart';
import 'wink_feedback.dart';
import 'wink_local_screen.dart';

class WinkScreen extends StatefulWidget {
  static bool _opening = false;
  static Future<void> open(BuildContext context) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const WinkScreen()));
    } finally {
      _opening = false;
    }
  }

  final WinkController? controller;
  final bool isActive, embedInShell;
  final VoidCallback? onBack;
  const WinkScreen(
      {super.key,
      this.controller,
      this.isActive = true,
      this.embedInShell = false,
      this.onBack});
  @override
  State<WinkScreen> createState() => _WinkScreenState();
}

class _WinkScreenState extends State<WinkScreen> {
  late final WinkController game;
  final feedback = WinkFeedback();
  BuildContext? _surfaceContext;
  final code = TextEditingController();
  final _scroll = ScrollController();
  String _lastPhase = 'hub';
  bool revealing = false, sawRole = false, sounds = false, vibration = false;
  int _round = -1;
  String? _roomCode, _recoveryNotice;
  bool _leaving = false;
  bool _accusing = false, _editingSettings = false;
  bool _started = false;
  bool _audioSheetOpen = false;
  String t(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void initState() {
    super.initState();
    game = widget.controller ?? WinkController();
    _round = (game.room?['round'] as num?)?.toInt() ?? -1;
    _roomCode = game.room?['code']?.toString();
    _lastPhase = game.phase;
    feedback.observe(game.room,
        sound: false, vibration: false, active: false, emit: false);
    game.visible = widget.isActive;
    game.addListener(_changed);
    if (widget.isActive) {
      _started = true;
      unawaited(game.start());
    }
    unawaited(_preferences());
  }

  @override
  void didUpdateWidget(covariant WinkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    game.visible = widget.isActive;
    if (!widget.isActive) {
      revealing = false;
      unawaited(feedback.stop());
    }
    if (widget.isActive && !oldWidget.isActive) {
      if (!_started) {
        _started = true;
        unawaited(game.start());
      } else {
        unawaited(game.refresh());
      }
    }
  }

  Future<void> _preferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        sounds = prefs.getBool('wink_sounds') ?? false;
        vibration = prefs.getBool('wink_vibration') ?? false;
      });
    }
  }

  void _changed() {
    if (!mounted) return;
    final round = (game.room?['round'] as num?)?.toInt() ?? -1;
    final roomCode = game.room?['code']?.toString();
    if (round != _round || roomCode != _roomCode || game.phase != _lastPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    _lastPhase = game.phase;
    if (round != _round || roomCode != _roomCode || game.phase == 'lobby') {
      _round = round;
      _roomCode = roomCode;
      revealing = false;
      sawRole = false;
    }
    if (!widget.isActive || !game.active) revealing = false;
    feedback.observe(game.room,
        sound: sounds,
        vibration: vibration,
        active: widget.isActive &&
            game.active &&
            (_audioSheetOpen ||
                _surfaceContext == null ||
                (ModalRoute.of(_surfaceContext!)?.isCurrent ?? true)));
    setState(() {});
  }

  @override
  void dispose() {
    game.removeListener(_changed);
    game.dispose();
    feedback.dispose();
    code.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final yes = await showDialog<bool>(
          context: _surfaceContext ?? context,
          builder: (ctx) => AlertDialog(
                  title: Text(t('تغادر الغرفة؟', 'Leave room?')),
                  content: Text(t(
                      'الخروج أثناء الجولة يستبعدك. خروج الغمّاز ينهي الجولة بفوز اللاعبين.',
                      'Leaving eliminates you. If the winker leaves, the players win.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(t('إلغاء', 'Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(t('مغادرة', 'Leave')))
                  ]));
      if (yes == true && mounted) await game.action('leave');
    } finally {
      _leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final sky = WinkSky.theme(base);
    return Theme(
        data: sky,
        child: Builder(builder: (surfaceContext) {
          _surfaceContext = surfaceContext;
          return PopScope(
            canPop:
                !widget.isActive || (!widget.embedInShell && game.room == null),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && widget.isActive) {
                if (widget.embedInShell || game.room == null) {
                  widget.onBack?.call();
                } else if (game.canAct) {
                  unawaited(_leave());
                }
              }
            },
            child: Scaffold(
              appBar: AppBar(
                  title: Text(t('الغمّازة', 'The Winker'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 27, fontWeight: FontWeight.bold)),
                  backgroundColor: WinkSky.header,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: !widget.embedInShell,
                  actions: [
                    if (game.room != null)
                      IconButton(
                          tooltip: t('مغادرة الغرفة', 'Leave room'),
                          onPressed: game.canAct ? _leave : null,
                          icon: const Icon(Icons.logout)),
                    SizedBox(
                        width: 108,
                        child: TextButton(
                            key: const ValueKey('wink-rules'),
                            onPressed: _rules,
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(t('قواعد اللعبة', 'Game rules'))))),
                    IconButton(
                        tooltip: t('الصوت والاهتزاز', 'Sound and vibration'),
                        onPressed: _audio,
                        icon: const Icon(Icons.tune))
                  ]),
              body: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                        WinkSky.header,
                        WinkSky.sky,
                        Color(0xFFF1FAFF)
                      ])),
                  child: Stack(children: [
                    const Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        height: 150,
                        child: IgnorePointer(
                            child: CustomPaint(painter: WinkSkyClouds()))),
                    SafeArea(
                        child: RefreshIndicator(
                            onRefresh: game.refresh,
                            child: ListView(
                                controller: _scroll,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 28),
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  if (game.busy)
                                    const LinearProgressIndicator(),
                                  if (game.errorCode != null)
                                    _panel(
                                        child: Text(_error(game.errorCode!),
                                            style: const TextStyle(
                                                color: Color(0xFFAF3325)))),
                                  if (!game.initialized)
                                    const Center(
                                        child: Padding(
                                            padding: EdgeInsets.all(40),
                                            child: CircularProgressIndicator()))
                                  else if (game.room == null)
                                    ..._hub()
                                  else
                                    ..._room(),
                                ]))),
                  ])),
            ),
          );
        }));
  }

  Widget _panel({required Widget child, Color? color}) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: color ?? const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFFFFFF)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12086EAB), blurRadius: 22, offset: Offset(0, 7))
          ]),
      child: child);
  Widget _button(String label, VoidCallback onTap, {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FilledButton.icon(
          onPressed: game.canAct ? onTap : null,
          icon: Icon(icon ?? Icons.arrow_forward_rounded),
          label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(label, textAlign: TextAlign.center))));
  Widget _deck() => SizedBox(
      height: 170,
      width: 250,
      child: Stack(alignment: Alignment.center, children: [
        for (final angle in [-0.24, 0.24, 0.0])
          Transform.translate(
              offset: Offset(angle * 150, angle == 0 ? -4 : 8),
              child: Transform.rotate(
                  angle: angle,
                  child: SizedBox(
                      width: 96,
                      child: WinkPlayingCard(
                          revealed: angle == 0,
                          number: angle == 0 ? 11 : null)))),
      ]));

  Widget _section(IconData icon, String title, {String? detail}) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFFFF741C)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold))),
        if (detail != null)
          Text(detail,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Color(0xFF6683A4), fontSize: 12)),
      ]));

  Widget _players(String phase, bool selfAlive) => _panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section(Icons.people_outline, t('اللاعبون', 'Players'),
            detail: '${game.players.length} / 11'),
        if (game.players.length > 4)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                  t('اسحب لرؤية باقي اللاعبين',
                      'Swipe to see the other players'),
                  style: const TextStyle(color: WinkSky.muted, fontSize: 12))),
        LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final width = ((constraints.maxWidth - 24) / 4)
              .clamp(80.0 * scale.clamp(1, 1.6), 140.0);
          return SingleChildScrollView(
              key: const ValueKey('wink-player-strip'),
              scrollDirection: Axis.horizontal,
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < game.players.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  SizedBox(
                      key: ValueKey('wink-player-${game.players[i]['id']}'),
                      width: width,
                      child: _player(game.players[i], phase, selfAlive)),
                ],
              ]));
        }),
      ]));

  List<Widget> _hub() => [
        Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFEFF9FF),
                      Color(0xFFDDF3FF),
                      Color(0xFFFFFFFF)
                    ]),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFD7EDF8))),
            child: Column(children: [
              const Text('STUDY BIRDS',
                  style: TextStyle(
                      color: Color(0xFF6683A4),
                      fontSize: 10,
                      letterSpacing: 2)),
              _deck(),
              Text(t('مين الغمّاز؟', 'Who is the winker?'),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  t('خلي بالك… الغمّاز بينكم',
                      'Watch out… the winker is among you'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _feature(
                        Icons.people_outline, t('4–11 لاعبًا', '4–11 players')),
                    _feature(
                        Icons.all_inclusive, t('على راحتكم', 'No time limit')),
                  ]),
            ])),
        _panel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(t('العبوا بجهاز واحد', 'Play on one device'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              _button(
                  t('العبوا على جهاز واحد · 4–11 لاعبًا',
                      'One device · 4–11 people'), () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const WinkLocalScreen()));
                if (mounted) await _preferences();
              }, icon: Icons.groups_outlined),
              Text(
                  t('أربعة أشخاص حقيقيين على الأقل. مرّروا الجهاز لكشف الكروت سرًا، بدون بوتات أو إنترنت.',
                      'At least four real people. Pass the device to reveal cards privately, with no bots or internet.'),
                  textAlign: TextAlign.center),
            ])),
        _panel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(t('العب مع الشلة', 'Play with your friends'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(t('اجتمعوا بنفس المكان، وافتحوا غرفة أو انضموا بالكود.',
                  'Gather in the same place, create a room or join with a code.')),
              _button(t('إنشاء غرفة', 'Create room'), () => game.create(),
                  icon: Icons.add_circle_outline),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFD7EDF8)),
              const SizedBox(height: 24),
              TextField(
                  key: const ValueKey('wink-room-code-input'),
                  controller: code,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (value) {
                    if (game.canAct) game.join(value);
                  },
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  maxLength: 32,
                  decoration: InputDecoration(
                      labelText: t('كود الغرفة', 'Room code'),
                      hintText: 'AB12CD34',
                      counterText: '',
                      helperText: t('اكتب أو الصق كود الغرفة من 8 خانات',
                          'Type or paste the 8-character room code'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18)))),
              _button(t('انضمام بكود', 'Join with code'),
                  () => game.join(code.text),
                  icon: Icons.login),
            ])),
        TextButton(
            onPressed: game.busy ? null : _recoverRoom,
            child: Text(t('استعادة غرفتي', 'Recover my room'))),
        if (_recoveryNotice != null)
          Text(_recoveryNotice!, textAlign: TextAlign.center),
      ];

  Future<void> _recoverRoom() async {
    setState(() => _recoveryNotice = null);
    await game.start();
    if (mounted &&
        game.room == null &&
        game.errorCode == null &&
        game.connected) {
      setState(() => _recoveryNotice = t(
          'لا توجد غرفة سابقة نشطة لحسابك. أنشئ غرفة أو انضم بالكود.',
          'No active room was found for your account. Create one or join with a code.'));
    }
  }

  Widget _feature(IconData icon, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: const Color(0xFFCC5300)),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style:
                    const TextStyle(color: Color(0xFF426684), fontSize: 12))),
      ]);
  List<Widget> _room() {
    final r = game.room!;
    final practice = r['isPractice'] == true;
    final host = r['host'] == game.me['id'];
    final phase = game.phase;
    final vote = Json.mapOrNull(r['vote']) ?? {};
    final result = Json.mapOrNull(r['result']) ?? {};
    final alive = game.players
        .where((p) => p['eliminated'] != true && p['left'] != true)
        .toList();
    final selfAlive = game.me['eliminated'] != true;
    final winker = game.me['role'] == 'winker';
    final canStart = alive.length >= 4 &&
        alive.every((p) => p['ready'] == true && p['connected'] == true);
    return [
      _roomHeader(practice, phase, alive.length),
      if (phase == 'lobby') ...[
        if (!practice && host && alive.length == 1)
          _button(
              t('ابدأ تجربة خاصة مع 3 بوتات',
                  'Start private practice with 3 bots'), () async {
            await game.action('leave');
            if (mounted && game.room == null && game.connected) {
              await game.practice();
            }
          }, icon: Icons.smart_toy_outlined),
        if (r['lobbyReason'] != null)
          _panel(
              child: Text(r['lobbyReason'] == 'player-left'
                  ? t('رجعنا للغرفة لأن لاعبًا غادر أثناء توزيع الأدوار. أكدوا الجاهزية لنوزّع الكروت مجددًا.',
                      'A player left during role reveal. Confirm readiness to deal the cards again.')
                  : t('انتهت مهلة كشف الأدوار قبل تأكيد الجميع. أكدوا الجاهزية وحاولوا مجددًا.',
                      'The role reveal deadline expired before everyone confirmed. Ready up and try again.'))),
        Text(t('مستنيين باقي الشلة', 'Waiting for the group'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(t('${alive.length} من 11 · الحد الأدنى 4 · الكل لازم يكون جاهز',
            '${alive.length} of 11 · At least 4 · Everyone must be ready')),
        _panel(
            child: Text(t(
                'وضع القعدة يعتمد على التزام اللاعبين؛ التطبيق لا يتحقق من الغمزة ولا يستخدم الكاميرا.',
                'In-person mode relies on fair play; the app cannot verify real winks and uses no camera.'))),
        _button(
            game.players
                        .where((p) => p['id'] == game.me['id'])
                        .firstOrNull?['ready'] ==
                    true
                ? t('إلغاء الجاهزية', 'Not ready')
                : t('أنا جاهز', 'I am ready'),
            () => game.action('ready', {
                  'ready': game.players
                          .where((p) => p['id'] == game.me['id'])
                          .firstOrNull?['ready'] !=
                      true
                }),
            icon: Icons.check_circle_outline),
        if (host) ...[
          TextButton(
              onPressed: game.canAct ? _settings : null,
              child: Text(t('إعدادات الغرفة', 'Room settings'))),
          FilledButton(
              onPressed:
                  game.canAct && canStart ? () => game.action('start') : null,
              child: Text(t('وزّع الأدوار وابدأ', 'Deal roles and start'))),
        ],
      ],
      if (phase == 'reveal') ...[
        _role(),
        Text(t(
            'خذوا راحتكم. تبدأ الجولة عندما يؤكد الجميع رؤية دوره، بدون مهلة.',
            'Take your time. Play begins when everyone confirms their role, with no deadline.')),
        if (sawRole && game.me['seen'] != true)
          _button(t('شفت دوري، جاهز للجولة', 'I saw my role, ready'), () {
            game.action('seen');
          }),
        if (game.me['seen'] == true)
          Text(t('مستنيين باقي الشلة تكشف أدوارها',
              'Waiting for everyone to see their roles')),
      ],
      if (phase == 'playing' || phase == 'voting') ...[
        if (practice && phase == 'playing' && winker && selfAlive)
          Text(t('جرّب الغمزة وقت ما تحب من بطاقة أي بوت حي أدناه.',
              'Wink whenever you like using any living bot’s card below.')),
        if (selfAlive && phase == 'playing') _role(compact: true),
        if (!selfAlive)
          _panel(
              color: const Color(0xFFF0F7FE),
              child: Text(t('خرجت من الجولة! كمل تتفرج من غير غمز أو تصويت.',
                  'You are out! Keep watching without winking or voting.'))),
        if (game.me['notice'] == 'winked' && selfAlive)
          _panel(
              child: Text(t('اتغمزلك! استنى لحظات… خروجك هيتعلن تلقائيًا.',
                  'You were winked at! Your elimination will be announced shortly.'))),
        if (phase == 'playing' &&
            selfAlive &&
            !winker &&
            game.me['notice'] == null)
          _button(
              t('اتغمزلي', 'I was winked at'), () => game.action('got-wink'),
              icon: Icons.visibility_off_outlined),
        if (phase == 'voting')
          _panel(
              color: const Color(0xFFF0F7FE),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        t('شاكّين في ${_name(vote['accused'])}',
                            'Suspect: ${_name(vote['accused'])}'),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(t('الغمزات متوقفة · خذوا وقتكم حتى يصوّت الجميع',
                        'Winks paused · Take your time until everyone votes')),
                    Text(t(
                        'الموافقة تحتاج أكثر من نصف الأحياء غير المتهم. الامتناع وعدم الرد ليسا موافقة.',
                        'Approval needs more than half of the living players except the accused. Abstention and no response are not approval.')),
                    if (selfAlive &&
                        game.me['id'] != vote['accused'] &&
                        game.me['ballot'] == null)
                      Wrap(spacing: 8, children: [
                        for (final pair in [
                          ('yes', t('موافق', 'Agree')),
                          ('no', t('رافض', 'Reject')),
                          ('abstain', t('امتناع', 'Abstain'))
                        ])
                          TextButton(
                              onPressed: game.canAct
                                  ? () => game.action('vote',
                                      {'choice': pair.$1, 'voteId': vote['id']})
                                  : null,
                              child: Text(pair.$2))
                      ]),
                    if (game.me['ballot'] != null)
                      Text(t('تم تسجيل صوتك سرًا',
                          'Your vote was recorded privately')),
                  ])),
      ],
      if (phase == 'finished')
        _panel(
            color: const Color(0xFFF0F7FE),
            child: Column(children: [
              const Icon(Icons.emoji_events_outlined,
                  color: Color(0xFFFF741C), size: 58),
              Text(
                  result['winner'] == 'winker'
                      ? t('الغمّاز كسب!', 'The winker wins!')
                      : t('الشلة كسبت!', 'The players win!'),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              Text(t('الغمّاز كان: ${_name(result['winker'])}',
                  'The winker was: ${_name(result['winker'])}')),
              Text(_reason('${result['reason']}')),
              if (practice) ...[
                _button(t('جولة جديدة كلاعب', 'New round as a player'),
                    () => game.action('practice-restart', {'role': 'player'}),
                    icon: Icons.replay),
                _button(t('جرّب كغمّاز', 'Try as the winker'),
                    () => game.action('practice-restart', {'role': 'winker'}),
                    icon: Icons.visibility_outlined),
              ] else if (host) ...[
                _button(
                    t('جولة جديدة', 'New round'), () => game.action('reset'),
                    icon: Icons.replay),
                TextButton(
                    onPressed: game.canAct ? () => game.action('reset') : null,
                    child: Text(t('العودة للغرفة', 'Return to lobby'))),
              ] else
                Text(t('مستنيين المضيف يرجعكم للغرفة لجولة جديدة',
                    'Waiting for the host to return to the lobby for a new round')),
            ])),
      _players(phase, selfAlive),
      if (phase != 'lobby' &&
          phase != 'reveal' &&
          Json.list(r['events']).isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(t('أحداث الجولة', 'Round events'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        for (final e in Json.list(r['events']).reversed.take(10))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(_event(Json.map(e)))),
      ],
      TextButton.icon(
          onPressed: game.canAct ? _leave : null,
          icon: const Icon(Icons.logout),
          label: Text(t('مغادرة الغرفة', 'Leave room'))),
    ];
  }

  Widget _roomHeader(bool practice, String phase, int alive) {
    final stage = switch (phase) {
      'lobby' => t('جهّزوا الشلة', 'Lobby'),
      'reveal' => t('اكتشف دورك', 'Reveal roles'),
      'voting' => t('وقت القرار', 'Voting'),
      'finished' => t('نتيجة الجولة', 'Results'),
      _ => t('العيون على الشلة', 'In play'),
    };
    return _panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFF36C98C), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(stage,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold))),
        Text(
            t('جولة ${game.room?['round'] ?? 0}',
                'Round ${game.room?['round'] ?? 0}'),
            style: const TextStyle(color: Color(0xFF6683A4), fontSize: 12)),
      ]),
      const SizedBox(height: 14),
      if (practice)
        Text(t('وضع التجربة · أنت و3 بوتات', 'Practice · You and 3 bots'),
            style: const TextStyle(
                color: Color(0xFFCC5300), fontWeight: FontWeight.bold))
      else
        Container(
            padding: const EdgeInsetsDirectional.only(
                start: 14, end: 4, top: 4, bottom: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFEAF4FB),
                borderRadius: BorderRadius.circular(14)),
            child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('كود الغرفة', 'ROOM CODE'),
                            style: const TextStyle(
                                color: Color(0xFF6683A4),
                                fontSize: 10,
                                letterSpacing: 1)),
                        SelectableText('${game.room?['code']}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                                fontSize: 23,
                                letterSpacing: 3,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF09285C))),
                      ]),
                  IconButton(
                      tooltip: t('نسخ الكود', 'Copy code'),
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: '${game.room?['code']}')),
                      icon: const Icon(Icons.copy_outlined, size: 19)),
                  IconButton(
                      tooltip: t('مشاركة الكود', 'Share code'),
                      onPressed: _shareCode,
                      icon: const Icon(Icons.ios_share_outlined, size: 19)),
                ])),
      const SizedBox(height: 12),
      Wrap(spacing: 14, runSpacing: 6, children: [
        Text(t('$alive في الجولة', '$alive in play'),
            style: const TextStyle(color: Color(0xFF6683A4), fontSize: 12)),
        Text(t('بدون وقت محدد', 'No time limit'),
            style: const TextStyle(color: Color(0xFF6683A4), fontSize: 12)),
      ]),
    ]));
  }

  Future<void> _shareCode() async {
    final value = game.room?['code'];
    if (value == null) return;
    final message = t('تعال نلعب الغمّازة في Study Birds! كود الغرفة: $value',
        'Play The Winker in Study Birds! Room code: $value');
    final ok = await launchUrl(Uri.https('wa.me', '/', {'text': message}),
        mode: LaunchMode.externalApplication);
    if (!ok) await Clipboard.setData(ClipboardData(text: message));
  }

  Widget _role({bool compact = false}) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = compact &&
            constraints.maxWidth >= 350 &&
            MediaQuery.textScalerOf(context).scale(14) <= 19;
        final face = GestureDetector(
            onLongPress: game.connected && game.active
                ? () {
                    unawaited(feedback.play(WinkCue.reveal,
                        sound: sounds, vibration: vibration));
                    setState(() {
                      revealing = true;
                      sawRole = true;
                    });
                  }
                : null,
            child: Semantics(
                label: t('اضغط مطولًا لكشف دورك. يبقى مفتوحًا حتى تخفيه.',
                    'Hold to reveal your role. It stays open until you hide it.'),
                child: SizedBox(
                    width: compact ? 138 : 190,
                    child: WinkPlayingCard(
                        revealed: revealing,
                        number: (game.me['card'] as num?)?.toInt()))));
        final details = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(t('كرتك الخاص · سرّك معك', 'YOUR SECRET CARD'),
                  style: const TextStyle(
                      color: Color(0xFF6683A4),
                      fontSize: 11,
                      letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Text(
                  revealing
                      ? (game.me['role'] == 'winker'
                          ? t('إنت الغمّاز', 'You are the winker')
                          : t('إنت لاعب… اكتشف الغمّاز',
                              'You are a player… find the winker'))
                      : t('اضغط مطولًا لكشف دورك', 'Hold to reveal your role'),
                  textAlign: wide ? TextAlign.start : TextAlign.center,
                  style: TextStyle(
                      fontSize: compact ? 23 : 25,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF09285C))),
              const SizedBox(height: 10),
              Text(
                  t(
                      revealing
                          ? 'خلّي دورك سرّك. راقب الشلة والعب على راحتك.'
                          : 'اضغط على الكرت مطولًا لفتحه. يظل ظاهرًا حتى تخفيه.',
                      revealing
                          ? 'Keep your role to yourself. Watch the group and play at your own pace.'
                          : 'Hold your card to open it. It stays visible until you hide it.'),
                  textAlign: wide ? TextAlign.start : TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, height: 1.6, color: Color(0xFF6683A4))),
              if (revealing) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                    key: const ValueKey('wink-hide-card'),
                    onPressed: () => setState(() => revealing = false),
                    style: FilledButton.styleFrom(
                        backgroundColor: WinkSky.orange,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.visibility_off_outlined, size: 17),
                    label: Text(t('إخفاء الكرت', 'Hide card'))),
              ],
            ]);
        return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFD7EDF8)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x16086EAB),
                      blurRadius: 20,
                      offset: Offset(0, 8))
                ]),
            child: wide
                ? Row(children: [
                    face,
                    const SizedBox(width: 22),
                    Expanded(child: details)
                  ])
                : Column(
                    children: [face, const SizedBox(height: 22), details]));
      });
  Widget _player(Map<String, dynamic> p, String phase, bool selfAlive) {
    final living = p['eliminated'] != true && p['left'] != true;
    final other = p['id'] != game.me['id'];
    final canTarget = phase == 'playing' &&
        selfAlive &&
        living &&
        other &&
        game.me['notice'] == null;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final caption = p['left'] == true
        ? t('غادر', 'Left')
        : !living
            ? t('يشاهد', 'Spectating')
            : p['connected'] != true
                ? t('غير متصل', 'Offline')
                : p['isBot'] == true
                    ? t('بوت', 'Bot')
                    : t('متصل', 'Connected');
    return Semantics(
        label: '${p['name']}, $caption',
        child: Column(children: [
          Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color:
                          !other ? const Color(0xFFFFC991) : Colors.transparent,
                      width: 2)),
              child: Stack(clipBehavior: Clip.none, children: [
                WinkAvatar(
                    id: '${p['id']}',
                    url: p['avatar'] is String ? p['avatar'] as String : null,
                    size: 60),
                if (p['id'] == game.room?['host'])
                  Positioned(
                      left: -2,
                      bottom: -2,
                      child: Tooltip(
                          message: t('المضيف', 'Host'),
                          child: const Icon(Icons.stars_rounded,
                              size: 20, color: WinkSky.orange))),
                Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: living && p['connected'] == true
                                ? WinkSky.green
                                : const Color(0xFF9CB1C5),
                            border:
                                Border.all(color: Colors.white, width: 2)))),
              ])),
          const SizedBox(height: 8),
          SizedBox(
              height: 38 * scale.clamp(1, 2),
              child: Center(
                  child: Text(other ? '${p['name']}' : t('أنت', 'You'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: !other
                              ? const Color(0xFFCB570D)
                              : WinkSky.navy)))),
          Text(caption,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: WinkSky.muted)),
          if (phase == 'lobby' || phase == 'reveal') ...[
            const SizedBox(height: 6),
            Icon(
                (phase == 'lobby' ? p['ready'] : p['seen']) == true
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                size: 20,
                color: (phase == 'lobby' ? p['ready'] : p['seen']) == true
                    ? WinkSky.green
                    : WinkSky.muted),
          ],
          if (canTarget) ...[
            const SizedBox(height: 8),
            if (game.room?['isPractice'] == true &&
                game.me['role'] == 'winker' &&
                p['isBot'] == true)
              TextButton(
                  key: ValueKey('practice-wink-${p['id']}'),
                  style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEEE1),
                      foregroundColor: const Color(0xFFC65105),
                      minimumSize: const Size(double.infinity, 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: game.canAct
                      ? () => game.action('practice-wink', {'target': p['id']})
                      : null,
                  child: Text(t('غمزة تجريبية', 'Practice wink'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12))),
            if (game.me['accused'] != true)
              TextButton(
                  style: TextButton.styleFrom(
                      backgroundColor: WinkSky.pale,
                      minimumSize: const Size(double.infinity, 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: game.canAct ? () => _accuse(p) : null,
                  child: Text(t('اتهام', 'Accuse'),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ]));
  }

  Future<void> _accuse(Map<String, dynamic> player) async {
    if (_accusing || !game.canAct || game.phase != 'playing') return;
    _accusing = true;
    final round = game.room?['round'];
    final roomCode = game.room?['code'];
    try {
      final confirmed = await showDialog<bool>(
          context: _surfaceContext ?? context,
          builder: (ctx) => AlertDialog(
                  title: Text(t('شاكك في ${player['name']}؟',
                      'Suspect ${player['name']}?')),
                  content: Text(t(
                      'لك محاولة اتهام واحدة في الجولة. سيبدأ تصويت عام وتتوقف الغمزات.',
                      'You have one accusation per round. A public vote will start and winks will pause.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(t('إلغاء', 'Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(t('ابدأ التصويت', 'Start vote')))
                  ]));
      if (confirmed == true &&
          mounted &&
          game.phase == 'playing' &&
          game.room?['round'] == round &&
          game.room?['code'] == roomCode) {
        await game.action('accuse', {'target': player['id']});
      }
    } finally {
      _accusing = false;
    }
  }

  String _name(dynamic id) =>
      game.players
          .where((p) => p['id'] == id)
          .firstOrNull?['name']
          ?.toString() ??
      t('لاعب', 'Player');

  String _reason(String reason) => switch (reason) {
        'last-two' => t('بقي الغمّاز ومعه لاعب واحد.',
            'Only the winker and one other player remain.'),
        'time' => t('انتهى الوقت وبقي لاعبان عاديان على الأقل.',
            'Time ran out with at least two ordinary players remaining.'),
        _ => t('تم اكتشاف الغمّاز أو غادر الجولة.',
            'The winker was found or left the round.'),
      };
  String _event(Map<String, dynamic> e) => switch (e['type']) {
        'started' => t('بدأت الجولة', 'Round started'),
        'eliminated' => t('${_name(e['player'])} اتغمزله وخرج',
            '${_name(e['player'])} was winked at and is out'),
        'left' => t('${_name(e['player'])} غادر', '${_name(e['player'])} left'),
        'vote-started' => t('بدأ التصويت على ${_name(e['player'])}',
            'Voting on ${_name(e['player'])} started'),
        'vote-approved' => t('تمت الموافقة على الاتهام', 'Accusation approved'),
        'vote-rejected' => t('لم يحصل الاتهام على الأغلبية',
            'Accusation did not reach a majority'),
        'vote-cancelled' => t('أُلغي التصويت لأن المتهم غادر الجولة',
            'Vote cancelled because the accused left the round'),
        'accused-out' => t('${_name(e['player'])} خرج بالتصويت',
            '${_name(e['player'])} was voted out'),
        'finished' => t('انتهت الجولة', 'Round finished'),
        _ => t('تم تحديث الغرفة', 'Room updated'),
      };
  String _error(String code) => switch (code) {
        'connection' => t(
            'الاتصال انقطع… بنحاول نرجعك. الأزرار متوقفة لحين استعادة حالة الخادم.',
            'Connection lost… reconnecting. Actions are paused until server state is restored.'),
        'sign-in' => t('سجّل دخولك أولًا للعب.', 'Sign in to play.'),
        'room-not-found' || 'invalid-code' => t(
            'كود الغرفة غير صحيح أو انتهت صلاحيتها.',
            'Invalid or expired room code.'),
        'already-in-room' => t('عندك غرفة بالفعل. اضغط استعادة غرفتي.',
            'You already have a room. Tap Recover my room.'),
        'already-started' => t('الجولة بدأت؛ انضم بعد العودة للغرفة.',
            'The round has started. Join when it returns to the lobby.'),
        'room-full' =>
          t('الغرفة مكتملة: 11 لاعبًا.', 'The room is full: 11 players.'),
        'not-member' => t('انتهت مهلة رجوعك أو غادرت الغرفة. انضم من جديد.',
            'Your return window expired or you left. Join again.'),
        'not-ready' => t('يلزم 4 لاعبين على الأقل، متصلين وجاهزين.',
            'At least 4 connected, ready players are required.'),
        'cooldown' =>
          t('استنى مهلة الغمزة القادمة.', 'Wait for the wink cooldown.'),
        'cannot-accuse' => t('استخدمت محاولتك أو تغيّرت حالتك؛ حدّث الغرفة.',
            'Your attempt was used or your status changed. Refresh the room.'),
        'stale-round' => t('بدأت جولة جديدة؛ حدّث الغرفة قبل اتخاذ إجراء.',
            'A new round started. Refresh before taking an action.'),
        'practice-private' => t(
            'هذه غرفة تجربة خاصة؛ أنشئ تجربتك من زر تجربة اللعبة.',
            'This is a private practice room. Start your own using Try with 3 bots.'),
        _ => t('تغيّرت حالة الجولة. حدّث الغرفة وحاول مجددًا.',
            'The round state changed. Refresh and try again.'),
      };
  Future<void> _settings() async {
    if (_editingSettings) return;
    _editingSettings = true;
    try {
      await showModalBottomSheet<void>(
          context: _surfaceContext ?? context,
          isScrollControlled: true,
          builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.all_inclusive, size: 40),
                    const SizedBox(height: 12),
                    Text(t('العبوا على راحتكم', 'Play at your own pace'),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                        t('بدون مؤقت للجولة أو كشف الأدوار أو التصويت، وبدون انتظار بين الغمزات. تنتهي الجولة باكتشاف الغمّاز أو بقاء لاعبين فقط.',
                            'No round timer, role reveal deadline, voting deadline or wait between winks. The round ends when you find the winker or only two players remain.'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(t('تمام', 'Done'))),
                  ]))));
    } finally {
      _editingSettings = false;
    }
  }

  Future<void> _audio() async {
    if (_audioSheetOpen) return;
    _audioSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
          context: _surfaceContext ?? context,
          isScrollControlled: true,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, update) => SafeArea(
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                    SwitchListTile(
                        title: Text(
                            t('مؤثرات اللعبة الصوتية', 'Game sound effects')),
                        value: sounds,
                        onChanged: (v) async {
                          update(() => sounds = v);
                          if (v) {
                            unawaited(feedback.play(WinkCue.deal,
                                sound: true, vibration: false));
                          } else {
                            unawaited(feedback.stop());
                          }
                          await (await SharedPreferences.getInstance())
                              .setBool('wink_sounds', v);
                        }),
                    SwitchListTile(
                        title: Text(t('اهتزاز خفيف', 'Light vibration')),
                        value: vibration,
                        onChanged: (v) async {
                          update(() => vibration = v);
                          if (v) unawaited(HapticFeedback.lightImpact());
                          await (await SharedPreferences.getInstance())
                              .setBool('wink_vibration', v);
                        }),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t(
                            'مؤثرات توزيع الكروت والخروج والتصويت ونهاية الجولة. اختياريان ومغلقان افتراضيًا لخصوصية اللعب. اضبط صوت الوسائط في جهازك.',
                            'Effects for dealing, elimination, voting and round end. Optional and off by default for privacy. Adjust your device media volume.'))),
                  ])))));
    } finally {
      _audioSheetOpen = false;
    }
  }

  Future<void> _rules() => showModalBottomSheet<void>(
      context: _surfaceContext ?? context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        t('قواعد الغمّازة في Study Birds',
                            'The Winker rules in Study Birds'),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    for (final rule in [
                      t('جهاز واحد: 4–11 شخصًا حقيقيًا يتناوبون على رؤية كروتهم سرًا، بدون إنترنت أو بوتات. الغرف بالكود: لكل لاعب جهازه ويختار الخادم غمّازًا واحدًا عشوائيًا. لا يبدأ اللعب حتى يؤكد الجميع رؤية دوره.',
                          'One device: 4–11 real people privately view their cards in turn, offline with no bots. Code rooms: each player has a device and the server randomly chooses one winker. Everyone confirms their role before play starts.'),
                      t('القعدة: الغمزة تحدث بالعين في الواقع؛ المتلقي ينتظر قليلًا ويضغط «اتغمزلي». نعتمد على التزامكم؛ لا كاميرا ولا تحقق من حركة العين.',
                          'In person: wink in real life; the recipient waits briefly and taps “I was winked at”. Fair play is required; there is no camera or eye detection.'),
                      t('لكل لاعب حي اتهام واحد في الجولة. التصويت بدون مهلة وينتهي بعد تصويت الجميع، والغمز يتوقف أثناءه. قبل التصويت تُسوّى الغمزات المقبولة المعلقة.',
                          'Each living player gets one accusation per round. Voting has no deadline and ends after everyone votes. Winks pause during voting. Accepted pending winks are settled before voting.'),
                      t('المتهم لا يصوّت. الموافقة بأكثر من نصف بقية الأحياء؛ الامتناع وعدم الرد ليسا موافقة. إذا وافقوا يخرج المتهم، وإذا كان بريئًا تستمر الجولة.',
                          'The accused cannot vote. Approval requires more than half of the other living players; abstention and no response are not approval. An approved accusation eliminates the suspect; play continues if innocent.'),
                      t('الشلة تفوز باكتشاف الغمّاز. الغمّاز يفوز إذا بقي معه لاعب واحد. لا يوجد مؤقت للجولة أو انتظار بين الغمزات؛ العبوا على راحتكم.',
                          'Players win by finding the winker. The winker wins when only one other player remains. No round timer or wait between winks: play at your own pace.'),
                      t('المستبعد يتفرج فقط. الانقطاع يعطيك 60 ثانية للرجوع؛ بعدها تعتبر مغادرًا. خروج الغمّاز ينهي الجولة بفوز اللاعبين. تنتقل الاستضافة تلقائيًا عند خروج المضيف.',
                          'Eliminated players spectate only. Disconnection allows 60 seconds to return; then you leave. If the winker leaves, players win. Hosting transfers automatically.'),
                      t('الجولة الجديدة تعيدكم للانتظار لتأكيد الجاهزية ثم توزع الأدوار عشوائيًا وتمسح حالات الجولة السابقة. ترتيب البطاقات ثابت أثناء الجولة.',
                          'A new round returns to the lobby for readiness, redistributes roles randomly and clears previous round state. Card order stays fixed during play.'),
                    ])
                      Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(rule,
                              style:
                                  const TextStyle(height: 1.7, fontSize: 16))),
                  ]))));
}
