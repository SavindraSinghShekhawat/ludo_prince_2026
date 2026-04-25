import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/domain/engine/game_engine.dart';
import 'package:ludo_prince/games/ludo/domain/engine/bot_ai.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/controller/src/firebase_event_provider.dart';
import 'package:ludo_prince/games/ludo/controller/src/game_event_provider.dart';
import 'package:ludo_prince/utils/app_logger.dart';
import 'package:ludo_prince/core/constants/firebase_paths.dart';

import 'package:ludo_prince/services/social_service.dart';

class MultiplayerGameController extends LudoController {
  final String gameId;
  final String gameType;
  final FirebaseDatabase _db = firebaseService.database;
  int _lastAppliedEventId = 0;
  Timer? _timeoutMonitor;
  int? _turnStartedAt;
  StreamSubscription? _prefRollSubscription;

  MultiplayerGameController(
    super.config, {
    required this.gameId,
    required PlayerSlot super.localPlayerSlot,
    this.gameType = 'ludo',
  }) : super(eventProvider: FirebaseEventProvider(gameId: gameId)) {
    // Mark the game as online immediately so GameOverDialog navigates correctly.
    state = state.copyWith(gameType: GameType.online);
    socialService.updatePresence(UserStatus.inGame, gameId: gameId);
  }

  Future<void> initializeFromSnapshot() async {
    final gameEvent =
        await _db.ref().child(FirebasePaths.session(gameType, gameId)).once();
    if (!gameEvent.snapshot.exists) return;

    final data = Map<String, dynamic>.from(gameEvent.snapshot.value as Map);
    _turnStartedAt = data['turnStartedAt'] as int?;

    final snapshot = data['stateSnapshot'];
    if (snapshot != null) {
      final gameStateJson = Map<String, dynamic>.from(snapshot['gameState']);
      _lastAppliedEventId = snapshot['lastEventId'] as int;
      final turnTime = (data['settings']?['turnTimeSeconds'] as int?) ?? 8;
      state = GameState.fromJson(gameStateJson).copyWith(
        gameType: GameType.online,
        turnStartedAt: _turnStartedAt,
        turnTimeSeconds: turnTime,
        prefetchedSeed: data['prefetchedSeed'] as int?,
      );
    } else {
      // If no snapshot, ensure state has correct mode from DB
      final dbMode = data['gameMode'];
      if (dbMode != null) {
        final mode = GameMode.values.firstWhere((e) => e.name == dbMode);
        state = state.copyWith(
          gameMode: mode,
          prefetchedSeed: data['prefetchedSeed'] as int?,
        );
      }
    }

    _startPrefRollListener();

    // Fetch missing events
    final lastIdPad = _lastAppliedEventId.toString().padLeft(5, '0');
    final eventsQuery = await _db
        .ref()
        .child(FirebasePaths.events(gameType, gameId))
        .orderByKey()
        .startAt(lastIdPad)
        .once();

    if (eventsQuery.snapshot.exists) {
      final eventsData = Map<dynamic, dynamic>.from(
        eventsQuery.snapshot.value as Map,
      );
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
    _startTimeoutMonitor();
  }

  void _startPrefRollListener() {
    _prefRollSubscription?.cancel();
    _prefRollSubscription = _db
        .ref()
        .child(FirebasePaths.session(gameType, gameId))
        .child('prefetchedSeed')
        .onValue
        .listen((event) {
      final val = event.snapshot.value as int?;
      if (isDisposed) return;

      // If we are currently rolling or already landed on this value optimistically,
      // ignore the server update to prevent "ping-ponging" the old value back.
      if (state.isRolling || state.isDiceRolled) {
        if (state.diceValue == val) return;
      }

      if (val != state.prefetchedSeed) {
        state = state.copyWith(prefetchedSeed: val);
        streamController.add(state);
      }
    });
  }

  void _startTimeoutMonitor() {
    _timeoutMonitor?.cancel();
    _timeoutMonitor = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isDisposed || state.isGameOver || _turnStartedAt == null) return;

      final now = firebaseService.serverTimeMillis;
      // We add a 2 second buffer to account for network latency and clock skew. Turn time is 15s.
      if (now > _turnStartedAt! + 17000) {
        _sendTimeoutRequest();
      }
    });
  }

  Future<void> _sendTimeoutRequest() async {
    final currentUser = firebaseService.auth.currentUser;
    if (currentUser == null) return;

    AppLogger.debug(
      '[MultiplayerGameController] Sending timeout request to Firebase for game $gameId',
    );

    // Only send if it's NOT our turn (let others claim the turn)
    // or if we've been offline and just came back.
    // Actually, any active client can send it.
    await _db
        .ref()
        .child(FirebasePaths.session(gameType, gameId))
        .child('actionRequests')
        .child(currentUser.uid)
        .set({'type': 'timeout', 'requestedAt': ServerValue.timestamp});
  }

  @override
  Future<void> dispose() async {
    _timeoutMonitor?.cancel();
    _prefRollSubscription?.cancel();
    await super.dispose();
  }

  Future<void> _applyEventLocally(
    GameEvent event, {
    bool isInitialSync = false,
  }) async {
    if (event is RollEvent) {
      await executeRoll(event.diceValue, skipSounds: isInitialSync);
    } else if (event is MoveEvent) {
      if (event.autoMove) {
        final currentPlayer = state.players.firstWhere(
          (p) => p.slot == state.currentTurn,
        );
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
    await _db.ref().child(FirebasePaths.session(gameType, gameId)).update({
      'stateSnapshot': {
        'gameState': state.toJson(),
        'lastEventId': _lastAppliedEventId,
      },
    });
  }

  @override
  Future<void> sendRollIntent() async {
    await super.sendRollIntent();
  }

  @override
  Future<void> sendMoveIntent(Token token) async {
    if (isDisposed || !isMyTurn || !state.isDiceRolled || isActionInProgress) {
      return;
    }

    await super.sendMoveIntent(token);
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

    if (event is SkipEvent) {
      if (event.playerSlot == state.currentTurn) {
        state = engine.skipTurn(state).state;
        // Increment action count for SkipEvent since super.handleGameEvent isn't called
        state = state.copyWith(turnActionCount: state.turnActionCount + 1);
      } else {
        AppLogger.debug('Ignoring stale SkipEvent for ${event.playerSlot}');
      }
    } else {
      await super.handleGameEvent(event);
    }

    final newTurn = state.currentTurn;
    final shouldRestartTimer =
        oldTurn != newTurn || event is RollEvent || event is MoveEvent;
    // ignore: unused_local_variable
    final turnChangedLocally = oldTurn != newTurn;

    final timestamp = firebaseService.serverTimeMillis;
    _turnStartedAt = timestamp;
    state = state.copyWith(turnStartedAt: timestamp);

    // CRITICAL: Always emit the final state after updating the timestamp
    if (!isDisposed) streamController.add(state);

    // Push new turn to Firebase so Cloud Function timer restarts
    if (shouldRestartTimer && !state.isGameOver) {
      final isLocalTurnEnding = oldTurn == localPlayerSlot;
      final isHost = localPlayerSlot == PlayerSlot.slot1;

      // Determine if this client should be the one to update the DB
      // We prioritize the player whose turn just ended, but fallback to host if they are absent
      bool shouldIUpdate = isLocalTurnEnding;
      if (!shouldIUpdate && isHost) {
        final oldPlayer = state.players.firstWhere((p) => p.slot == oldTurn);
        if (oldPlayer.status == PlayerStatus.left) {
          shouldIUpdate = true;
        }
      }

      if (shouldIUpdate) {
        final updates = <String, dynamic>{
          'currentTurn': newTurn.name,
          'turnStartedAt': ServerValue.timestamp,
          'turnActionCount': state.turnActionCount,
        };

        if (turnChangedLocally) {
          updates['turnNumber'] = ServerValue.increment(1);
          updates['isDiceRolled'] = false;
        }

        _db
            .ref()
            .child(FirebasePaths.session(gameType, gameId))
            .update(updates);
      }
    } else if (state.isGameOver && localPlayerSlot == PlayerSlot.slot1) {
      final winnerUids = state.winners.map((slot) {
        return state.players.firstWhere((p) => p.slot == slot).uid;
      }).toList();

      _db.ref().child(FirebasePaths.session(gameType, gameId)).update({
        'status': 'finished',
        'winners': winnerUids,
      });
    }

    _checkSnapshotRequirement();
  }
}
