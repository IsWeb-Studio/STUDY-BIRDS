import 'dart:math';

/// Pass-and-play only. No accounts, server rooms, rewards or persistent secrets.
class WinkLocalGame {
  final List<String> names;
  final int winker;
  final Set<int> eliminated = {}, accusedBy = {};
  final Map<int, bool> votes = {};
  int revealTurn = 0;
  String phase = 'reveal';
  String? winner;
  int? suspect;
  WinkLocalGame(List<String> players, {Random? random})
      : names = List.unmodifiable(players),
        winker =
            (random ?? Random.secure()).nextInt(players.length.clamp(4, 11)) {
    if (players.length < 4 || players.length > 11) {
      throw ArgumentError('4–11 players required');
    }
  }
  List<int> get living => [
        for (int i = 0; i < names.length; i++)
          if (!eliminated.contains(i)) i
      ];
  List<int> get voters => living.where((i) => i != suspect).toList();
  int? get nextVoter => voters.where((i) => !votes.containsKey(i)).firstOrNull;
  int cardFor(int player) =>
      player == winker ? 11 : 1 + (player > winker ? player - 1 : player);
  void confirmRole() {
    if (phase != 'reveal') return;
    if (++revealTurn == names.length) phase = 'playing';
  }

  void winkedAt(int player) {
    if (phase != 'playing' || !living.contains(player)) {
      throw StateError('Invalid elimination');
    }
    eliminated.add(player);
    _finishIfNeeded();
  }

  void accuse(int accuser, int target) {
    if (phase != 'playing' ||
        !living.contains(accuser) ||
        !living.contains(target) ||
        accuser == target ||
        accusedBy.contains(accuser)) {
      throw StateError('Invalid accusation');
    }
    accusedBy.add(accuser);
    suspect = target;
    votes.clear();
    phase = 'voting';
  }

  void vote(int voter, bool approve) {
    if (phase != 'voting' || voter != nextVoter) {
      throw StateError('Invalid vote');
    }
    votes[voter] = approve;
    if (nextVoter == null) {
      if (votes.values.where((v) => v).length > voters.length / 2) {
        eliminated.add(suspect!);
      }
      suspect = null;
      votes.clear();
      phase = 'playing';
      _finishIfNeeded();
    }
  }

  void _finishIfNeeded() {
    if (eliminated.contains(winker)) {
      winner = 'players';
      phase = 'finished';
    } else if (living.length <= 2) {
      winner = 'winker';
      phase = 'finished';
    }
  }
}
