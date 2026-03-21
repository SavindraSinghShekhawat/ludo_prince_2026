import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/game_state.dart';
import '../models/token.dart';
import '../engine/game_engine.dart';
import '../engine/bot_ai.dart';
import '../services/firebase_service.dart';
import 'ludo_controller.dart';
import 'src/firebase_event_provider.dart';
import 'src/game_event_provider.dart';

class MultiplayerGameController extends LudoController {
  final String gameId;
  final FirebaseDatabase _db = firebaseService.database;
  int _lastAppliedEventId = 0;

  final List<int> _pendingMoves = [];
  bool _optimisticTurnChangePending = false;

  bool get hasPendingMoves => _pendingMoves.isNotEmpty;

  MultiplayerGameController(
    Map<PlayerSlot, PlayerSetupConfig> config, {
    required this.gameId,
    required PlayerSlot localPlayerSlot,
  }) : super(config,
            localPlayerSlot: localPlayerSlot,
            eventProvider: FirebaseEventProvider(gameId: gameId)) {
    // Mark the game as online immediately so GameOverDialog navigates correctly.
    state = state.copyWith(gameType: GameType.online);
  }

  Future<void> initializeFromSnapshot() async {
    final gameEvent = await _db.ref().child('ludogames').child(gameId).once();
    if (!gameEvent.snapshot.exists) return;

    final data = Map<String, dynamic>.from(gameEvent.snapshot.value as Map);

    final snapshot = data['stateSnapshot'];
    if (snapshot != null) {
      final gameStateJson = Map<String, dynamic>.from(snapshot['gameState']);
      _lastAppliedEventId = snapshot['lastEventId'] as int;
      state =
          GameState.fromJson(gameStateJson).copyWith(gameType: GameType.online);
    } else {
      // If no snapshot, ensure state has correct mode from DB
      final dbMode = data['gameMode'];
      if (dbMode != null) {
        final mode = GameMode.values.firstWhere((e) => e.name == dbMode);
        state = state.copyWith(gameMode: mode);
      }
    }

    // Fetch missing events
    final lastIdPad = _lastAppliedEventId.toString().padLeft(5, '0');
    final eventsQuery = await _db
        .ref()
        .child('ludogames')
        .child(gameId)
        .child('events')
        .orderByKey()
        .startAt(lastIdPad)
        .once();

    if (eventsQuery.snapshot.exists) {
      final eventsData =
          Map<dynamic, dynamic>.from(eventsQuery.snapshot.value as Map);
      final sortedKeys = eventsData.keys.cast<String>().toList()..sort();

      for (var key in sortedKeys) {
        if (key == lastIdPad && _lastAppliedEventId != 0) continue;

        final eventMap = Map<String, dynamic>.from(eventsData[key]);
        final event = GameEvent.fromJson(eventMap);
        await _applyEventLocally(event, isInitialSync: true);
        _lastAppliedEventId = int.parse(key);
      }
    }

    // Now start listening for new events
    if (eventProvider is FirebaseEventProvider) {
      (eventProvider as FirebaseEventProvider).startListening(lastIdPad);
    }

    if (!isDisposed) streamController.add(state);
  }

  Future<void> _applyEventLocally(GameEvent event,
      {bool isInitialSync = false}) async {
    if (event is RollEvent) {
      await executeRoll(event.diceValue, skipSounds: isInitialSync);
    } else if (event is MoveEvent) {
      if (event.autoMove) {
        final currentPlayer =
            state.players.firstWhere((p) => p.slot == state.currentTurn);
        final bestToken = BotAI.getBestMove(currentPlayer, state);
        if (bestToken != null) {
          await executeMove(bestToken.id);
        }
      } else {
        await executeMove(event.tokenId);
      }
    } else if (event is QuitEvent) {
      final engine = GameEngine();
      final result = engine.quitPlayer(state, event.playerSlot);
      state = result.state;
    }

    _checkSnapshotRequirement();
  }

  void _checkSnapshotRequirement() {
    if (_lastAppliedEventId > 0 && _lastAppliedEventId % 20 == 0) {
      _saveSnapshot();
    }
  }

  Future<void> _saveSnapshot() async {
    await _db.ref().child('ludogames').child(gameId).update({
      'stateSnapshot': {
        'gameState': state.toJson(),
        'lastEventId': _lastAppliedEventId,
      }
    });
  }

  @override
  Future<void> sendRollIntent() async {
    if (hasPendingMoves) return;
    await super.sendRollIntent();
  }

  @override
  Future<void> sendMoveIntent(Token token) async {
    if (hasPendingMoves) return;
    if (isDisposed || !isMyTurn || !state.isDiceRolled || isActionInProgress)
      return;

    // We must call super first to send the request to the server
    await super.sendMoveIntent(token);

    // Optimistically execute the move locally to hide latency (0ms UI feedback)
    _pendingMoves.add(token.id);
    final oldTurn = state.currentTurn;

    await executeMove(token.id);

    final newTurn = state.currentTurn;
    if (oldTurn != newTurn) {
      _optimisticTurnChangePending = true;
    }
  }

  @override
  Future<void> handleGameEvent(GameEvent event) async {
    if (isDisposed) return;

    if (event is RollEvent) {
      _lastAppliedEventId++;
    } else if (event is MoveEvent) {
      _lastAppliedEventId++;
    }
    final oldTurn = state.currentTurn;

    bool skipSuper = false;
    if (event is MoveEvent && !event.autoMove) {
      if (_pendingMoves.isNotEmpty && _pendingMoves.first == event.tokenId) {
        _pendingMoves.removeAt(0);
        skipSuper = true; // We already optimistically executed this move
      }
    }

    if (!skipSuper) {
      await super.handleGameEvent(event);
    }
    final newTurn = state.currentTurn;
    bool shouldRestartTimer = false;
    bool turnChangedLocally = false;

    if (skipSuper) {
      shouldRestartTimer = true;
      if (_optimisticTurnChangePending) {
        turnChangedLocally = true;
        _optimisticTurnChangePending = false;
      }
    } else {
      shouldRestartTimer =
          oldTurn != newTurn || event is RollEvent || event is MoveEvent;
      turnChangedLocally = oldTurn != newTurn;
    }

    // Push new turn to Firebase so Cloud Function timer restarts
    if (shouldRestartTimer && !state.isGameOver) {
      final updates = <String, dynamic>{
        'currentTurn': newTurn.name,
        'turnStartedAt': ServerValue.timestamp,
      };

      if (turnChangedLocally) {
        updates['turnNumber'] = ServerValue.increment(1);
      }

      _db.ref().child('ludogames').child(gameId).update(updates);
    } else if (state.isGameOver) {
      final winnerUids = state.winners.map((slot) {
        return state.players.firstWhere((p) => p.slot == slot).uid;
      }).toList();

      _db.ref().child('ludogames').child(gameId).update({
        'status': 'finished',
        'winners': winnerUids,
      });
    }

    _checkSnapshotRequirement();
  }
}
