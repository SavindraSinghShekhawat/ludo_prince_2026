import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';

class MatchmakingService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? "";

  String get _userId => _auth.currentUser?.uid ?? "anonymous";

  /// Creates a new game room in RTDB
  Future<String> createGame(String playerName) async {
    // 1. Ensure user is authenticated (minimally anonymous)
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }

    // 2. Generate a unique 6-digit Game ID
    final String gameId =
        (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

    // 3. Create initial state
    final host = Player(
      slot: PlayerSlot.slot1,
      name: playerName,
      userId: _userId,
      type: PlayerType.remoteHuman,
      tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot1)),
    );

    final initialState = GameState(
      gameId: gameId,
      hostId: _userId,
      status: GameStatus.waiting,
      players: [host],
      turnOrder: [PlayerSlot.slot1],
      currentTurn: PlayerSlot.slot1,
    );

    // 4. Save to RTDB
    await _db.ref('games/$gameId').set(initialState.toJson());

    return gameId;
  }

  /// Joins an existing game room
  Future<void> joinGame(String gameId, String playerName) async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }

    final gameRef = _db.ref('games/$gameId');
    final snapshot = await gameRef.get();

    if (!snapshot.exists) {
      throw Exception("Game not found");
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final state = GameState.fromJson(data);

    if (state.status != GameStatus.waiting) {
      throw Exception("Game already started or finished");
    }

    if (state.players.length >= 4) {
      throw Exception("Game is full");
    }

    // Check if player is already in
    if (state.players.any((p) => p.userId == _userId)) {
      return; // Already joined
    }

    // Determine next available slot
    final usedSlots = state.players.map((p) => p.slot).toSet();
    final nextSlot =
        PlayerSlot.values.firstWhere((s) => !usedSlots.contains(s));

    final newPlayer = Player(
      slot: nextSlot,
      name: playerName,
      userId: _userId,
      type: PlayerType.remoteHuman,
      tokens: List.generate(4, (i) => Token(id: i, slot: nextSlot)),
    );

    final updatedPlayers = List<Player>.from(state.players)..add(newPlayer);
    final updatedTurnOrder = List<PlayerSlot>.from(state.turnOrder)
      ..add(nextSlot);

    await gameRef.update({
      'players': updatedPlayers.map((p) => p.toJson()).toList(),
      'turnOrder': updatedTurnOrder.map((e) => e.name).toList(),
    });
  }

  /// Starts the game (Host only)
  Future<void> startGame(String gameId) async {
    final gameRef = _db.ref('games/$gameId');
    final snapshot = await gameRef.get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final hostId = data['hostId'];

    if (hostId != _userId) {
      throw Exception("Only the host can start the game");
    }

    await gameRef.update({'status': GameStatus.playing.name});
  }

  /// Listens to game state changes
  Stream<GameState> listenToGame(String gameId) {
    return _db.ref('games/$gameId').onValue.map((event) {
      if (event.snapshot.value == null) {
        throw Exception("Game data vanished");
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return GameState.fromJson(data);
    });
  }
}

final matchmakingService = MatchmakingService();
