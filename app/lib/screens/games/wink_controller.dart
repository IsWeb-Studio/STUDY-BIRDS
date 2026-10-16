import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_session.dart';
import '../../core/utils/json_safe.dart';

class WinkController extends ChangeNotifier with WidgetsBindingObserver {
  final ApiClient api;
  WinkController({ApiClient? api}) : api = api ?? ApiClient.instance;
  Map<String, dynamic>? room;
  bool busy = false, connected = true, initialized = false, active = true;
  String? errorCode;
  Timer? _timer;
  bool _polling = false, _disposed = false;
  Duration _clockOffset = Duration.zero;
  String? _pendingOperation;
  String? _pendingAction;
  Map<String, dynamic>? _pendingPayload;
  int? _pendingRound;
  int _ticks = 0;
  int _stateEpoch = 0;
  bool visible = true;
  String? _owner;
  String? get _identity => AuthSession.instance.currentUser?.id ?? token;
  Future<dynamic> _call(Future<dynamic> Function() request) async {
    final owner = _identity;
    _owner = owner;
    try {
      final data = await request();
      if (owner != _identity) throw const _WinkSessionChanged();
      return data;
    } catch (_) {
      if (owner != _identity) throw const _WinkSessionChanged();
      rethrow;
    }
  }

  String? get token => AuthSession.instance.token;
  Map<String, dynamic> get me => _owner != null && _owner != _identity
      ? {}
      : Json.mapOrNull(room?['me']) ?? {};
  List<Map<String, dynamic>> get players =>
      (Json.listOrNull(room?['players']) ?? []).map(Json.map).toList();
  String get phase => '${room?['phase'] ?? 'hub'}';
  int get now => DateTime.now().add(_clockOffset).millisecondsSinceEpoch;
  int remaining(dynamic deadline) =>
      deadline is num ? ((deadline - now) / 1000).ceil().clamp(0, 3600) : 0;
  bool get canAct =>
      connected &&
      !busy &&
      _pendingOperation == null &&
      active &&
      (_owner == null || _owner == _identity);

  Future<void> start() async {
    if (_timer == null) {
      WidgetsBinding.instance.addObserver(this);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!active || _disposed) return;
        if (visible) notifyListeners();
        if (++_ticks % 2 == 0 && (room != null || (visible && !connected))) {
          unawaited(refresh());
        }
      });
    }
    await _run(() async {
      final current = Json.map(await _call(
          () => api.get('/games/wink/current', token: token, cached: false)));
      connected = true;
      if (current['code'] is String) {
        await _load('${current['code']}');
      } else {
        room = null;
      }
    });
    initialized = true;
    _emit();
  }

  void _accept(dynamic data) {
    if (_disposed) return;
    final next = Json.map(data);
    final previousRevision = room?['revision'];
    final revision = next['revision'];
    if (room?['code'] == next['code'] &&
        previousRevision is num &&
        revision is num &&
        revision < previousRevision) {
      return;
    }
    if (next['serverNow'] is num) {
      _clockOffset = Duration(
          milliseconds: (next['serverNow'] as num).toInt() -
              DateTime.now().millisecondsSinceEpoch);
    }
    room = next;
    connected = true;
    errorCode = null;
  }

  Future<void> _load(String code, {int? readEpoch}) async {
    final data = await _call(
        () => api.get('/games/wink/$code', token: token, cached: false));
    if (readEpoch != null && readEpoch != _stateEpoch) return;
    _accept(data);
  }

  Future<void> refresh() async {
    if (_polling || busy || !active || _disposed) return;
    if (_owner != null && _owner != _identity) {
      room = null;
      _pendingOperation = null;
      _pendingAction = null;
      _pendingPayload = null;
      await start();
      return;
    }
    if (room == null) {
      await start();
      return;
    }
    _polling = true;
    final readEpoch = _stateEpoch;
    try {
      if (_pendingOperation != null) {
        await _sendAction(
            _pendingAction!, _pendingPayload!, _pendingOperation!);
      } else {
        await _load('${room!['code']}', readEpoch: readEpoch);
      }
    } catch (e) {
      if (readEpoch == _stateEpoch) _error(e);
    } finally {
      _polling = false;
      _emit();
    }
  }

  Future<void> create() => _run(() async =>
      _accept(await _call(() => api.post('/games/wink', token: token))));
  Future<void> practice() => _run(() async => _accept(await _call(() => api
      .post('/games/wink/practice', token: token, body: {'role': 'player'}))));
  Future<void> join(String code) async {
    final normalized = normalizeRoomCode(code);
    if (!RegExp(r'^[A-F0-9]{8}$').hasMatch(normalized)) {
      errorCode = 'invalid-code';
      _emit();
      return;
    }
    await _run(() async => _accept(await _call(
        () => api.post('/games/wink/$normalized/join', token: token))));
  }

  static String normalizeRoomCode(String value) => value
      .replaceAllMapped(RegExp('[٠-٩۰-۹０-９]'), (match) {
        final digit = match[0]!.codeUnitAt(0);
        return '${digit - (digit >= 0xff10 ? 0xff10 : digit >= 0x6f0 ? 0x6f0 : 0x660)}';
      })
      .replaceAll(RegExp(r'[\s\-\u200e\u200f\u061c]'), '')
      .toUpperCase();

  Future<void> action(String action,
      [Map<String, dynamic> payload = const {}]) async {
    if (!canAct || room == null) return;
    _pendingOperation = ApiClient.newOperationId();
    _pendingAction = action;
    _pendingPayload = payload;
    _pendingRound = (room?['round'] as num?)?.toInt();
    await _run(() => _sendAction(action, payload, _pendingOperation!));
  }

  Future<void> _sendAction(
      String action, Map<String, dynamic> payload, String operation) async {
    final data = await _call(() => api.post(
            '/games/wink/${room!['code']}/actions',
            token: token,
            idempotencyKey: operation,
            body: {
              'action': action,
              'payload': payload,
              'operationId': operation,
              'round': _pendingRound
            }));
    _pendingOperation = null;
    _pendingAction = null;
    _pendingPayload = null;
    if (action == 'leave') {
      room = null;
      errorCode = null;
      connected = true;
    } else {
      _accept(data);
    }
  }

  Future<void> _run(Future<void> Function() work) async {
    if (busy || _disposed) return;
    if (token == null) {
      errorCode = 'sign-in';
      _emit();
      return;
    }
    busy = true;
    _stateEpoch++;
    errorCode = null;
    _emit();
    try {
      await work();
    } catch (e) {
      _error(e);
    } finally {
      busy = false;
      _emit();
    }
  }

  void _error(Object error) {
    if (_disposed) return;
    if (error is _WinkSessionChanged) {
      room = null;
      _pendingOperation = null;
      _pendingPayload = null;
      _pendingAction = null;
      errorCode = 'sign-in';
      connected = false;
      return;
    }
    final code = error is ApiException ? error.data['code']?.toString() : null;
    if (code != null) {
      _pendingOperation = null;
      _pendingAction = null;
      _pendingPayload = null;
      errorCode = code;
      connected = true;
      if (['not-member', 'room-not-found'].contains(code)) room = null;
    } else {
      connected = false;
      errorCode = error is ApiException && [401, 403].contains(error.statusCode)
          ? 'sign-in'
          : 'connection';
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) unawaited(refresh());
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _WinkSessionChanged implements Exception {
  const _WinkSessionChanged();
}
