import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_rules.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/controller/src/firebase_event_provider.dart';
import 'package:ludo_prince/games/ludo/controller/src/game_event_provider.dart';
import 'package:ludo_prince/utils/app_logger.dart';
import 'package:ludo_prince/core/constants/firebase_paths.dart';

import 'package:ludo_prince/services/social_service.dart';

class LudoMultiplayerController extends LudoController {
  final String gameId;
  final String gameType;
  final bool initialIsPrivate;
  final FirebaseDatabase _db = firebaseService.database;
  int _lastAppliedEventId = 0;
  Timer? _timeoutMonitor;
  int? _turnStartedAt;
  StreamSubscription? _prefRollSubscription;

  @override
  GameMode get gameMode => state.gameMode;

  LudoMultiplayerController(
    super.config, {
    required this.gameId,
    required PlayerSlot super.localPlayerSlot,
    super.gameMode,
    this.initialIsPrivate = false,
    this.gameType = 'ludo',
  }) : super(
          eventProvider: FirebaseEventProvider(gameId: gameId),
          rules: const GameRules(),
        ) {
    // Mark the game as online immediately so LudoGameOverDialog navigates correctly.
    // Explicitly enforce standard classic rules for all online multiplayer games.
    state = state.copyWith(
      gameType: GameType.online,
      isPrivate: initialIsPrivate,
      rules: const GameRules(),
    );
    socialService.updatePresence(UserStatus.inGame, gameId: gameId);
  }

  Future<void> initializeFromSnapshot() async {
    final gameEvent =
        await _db.ref().child(FirebasePaths.session(gameType, gameId)).once();
    if (!gameEvent.snapshot.exists) return;

    final data = Map<String, dynamic>.from(gameEvent.snapshot.value as Map);
    final turnTime = (data['settings']?['turnTimeSeconds'] as int?) ?? 15;
    final dbTurnStartedAt = (data['turnStartedAt'] as num?)?.toInt();
    final now = firebaseService.serverTimeMillis;
    // If the timestamp in DB is from more than turnTimeSeconds ago (e.g. stale lobby creation timestamp),
    // clamp it to the current server time so timeout monitor does not fire prematurely on startup!
    if (dbTurnStartedAt == null || (now - dbTurnStartedAt) > (turnTime * 1000)) {
      _turnStartedAt = now;
    } else {
      _turnStartedAt = dbTurnStartedAt;
    }

    // Instant Reconnection via Server-Authoritative Token State
    final dbMode = data['gameMode'];
    final mode = dbMode != null
        ? GameMode.values.firstWhere((e) => e.name == dbMode, orElse: () => GameMode.classic)
        : GameMode.classic;
        
    final currentTurnName = data['currentTurn'] as String?;
    PlayerSlot? currentTurn = currentTurnName != null
        ? PlayerSlot.values.firstWhere((e) => e.name == currentTurnName, orElse: () => state.currentTurn)
        : null;

    final turnOrderData = data['turnOrder'] as List?;
    final List<PlayerSlot>? turnOrder = turnOrderData
        ?.map((e) => PlayerSlot.values.firstWhere((p) => p.name == e))
        .toList();

    final isPrivate = (data['isPrivate'] as bool?) ?? state.isPrivate;

    state = state.copyWith(
      gameType: GameType.online,
      gameMode: mode,
      isPrivate: isPrivate,
      rules: const GameRules(),
      turnStartedAt: _turnStartedAt,
      turnTimeSeconds: turnTime,
      prefetchedSeed: data['prefetchedSeed'] as int?,
      currentTurn: currentTurn,
      turnOrder: turnOrder ?? state.turnOrder,
      diceValue: (data['diceValue'] as int?) ?? state.diceValue,
      isDiceRolled: (data['isDiceRolled'] as bool?) ?? state.isDiceRolled,
    );

    // Sync token positions instantly from Firebase
    final firebasePlayers = data['players'] as Map<dynamic, dynamic>?;
    if (firebasePlayers != null) {
      final updatedPlayers = state.players.map((p) {
        final fbp = firebasePlayers[p.slot.name];
        if (fbp != null) {
          final pData = Map<String, dynamic>.from(fbp as Map);
          if (pData['tokens'] != null) {
            final tokensList = (pData['tokens'] as List).map((e) {
                final tokenMap = Map<String, dynamic>.from(e as Map);
                tokenMap['slot'] ??= p.slot.name;
                return Token.fromJson(tokenMap);
            }).toList();
            return p.copyWith(
                tokens: tokensList, 
                skipCount: pData['skipCount'] ?? p.skipCount,
                status: pData['status'] == 'left' ? PlayerStatus.left : PlayerStatus.active,
            );
          }
        }
        return p;
      }).toList();
      state = state.copyWith(players: updatedPlayers);
    }

    _lastAppliedEventId = (data['eventCounter'] as int?) ?? 0;
    
    _startPrefRollListener();

    // Now start listening for new events
    if (eventProvider is FirebaseEventProvider) {
      final newLastIdPad = _lastAppliedEventId.toString().padLeft(5, '0');
      (eventProvider as FirebaseEventProvider).startListening(newLastIdPad);
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

  int _lastTimeoutRequestTime = 0;

  void _startTimeoutMonitor() {
    _timeoutMonitor?.cancel();
    _timeoutMonitor = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isDisposed || state.isGameOver || _turnStartedAt == null) return;

      final now = firebaseService.serverTimeMillis;
      final turnBufferMs = (state.turnTimeSeconds * 1000) + 2000;
      if (now > _turnStartedAt! + turnBufferMs) {
        if (now > _lastTimeoutRequestTime + 5000) {
          _lastTimeoutRequestTime = now;
          _sendTimeoutRequest();
        }
      }
    });
  }

  Future<void> _sendTimeoutRequest() async {
    final currentUser = firebaseService.auth.currentUser;
    if (currentUser == null) return;

    AppLogger.debug(
      '[LudoMultiplayerController] Sending timeout request to Firebase for game $gameId',
    );

    // Target the player whose turn actually timed out, so we don't pollute the local player's actionRequests node
    final timedOutPlayer = state.players.firstWhere(
      (p) => p.slot == state.currentTurn,
      orElse: () => state.players.first,
    );
    final targetUid =
        timedOutPlayer.uid.isNotEmpty ? timedOutPlayer.uid : currentUser.uid;

    await _db
        .ref()
        .child(FirebasePaths.session(gameType, gameId))
        .child('actionRequests')
        .child(targetUid)
        .set({'type': 'timeout', 'requestedAt': ServerValue.timestamp});
  }

  @override
  Future<void> dispose() async {
    _timeoutMonitor?.cancel();
    _prefRollSubscription?.cancel();
    socialService.updatePresence(UserStatus.online);
    await super.dispose();
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
  Future<void> handleGameEvent(GameEvent event,
      {bool fastForward = false}) async {
    if (isDisposed) return;

    if (event.id != null) {
      final parsedId = int.tryParse(event.id!);
      if (parsedId != null) {
        _lastAppliedEventId = parsedId;
      } else {
        _lastAppliedEventId++;
      }
    } else {
      _lastAppliedEventId++;
    }

    // Align current turn if server-authoritative event carries explicit playerSlot
    if (event is RollEvent &&
        event.playerSlot != null &&
        state.currentTurn != event.playerSlot) {
      state = state.copyWith(currentTurn: event.playerSlot);
    } else if (event is MoveEvent &&
        event.playerSlot != null &&
        state.currentTurn != event.playerSlot) {
      state = state.copyWith(currentTurn: event.playerSlot);
    }

    if (event is SkipEvent) {
      if (event.playerSlot == state.currentTurn) {
        if (event.isTimeout) {
          state = engine.skipTurn(state).state;
        } else {
          state = engine.passTurn(state).state;
        }
        // Increment action count for SkipEvent since super.handleGameEvent isn't called
        state = state.copyWith(
          turnActionCount: state.turnActionCount + 1,
          isRolling: false,
          isWaitingForResult: false,
        );
      } else {
        AppLogger.debug('Ignoring stale SkipEvent for ${event.playerSlot}');
      }
    } else {
      await super.handleGameEvent(event, fastForward: fastForward);
    }

    final timestamp = firebaseService.serverTimeMillis;
    _turnStartedAt = timestamp;
    state = state.copyWith(turnStartedAt: timestamp);

    // CRITICAL: Always emit the final state after updating the timestamp
    if (!isDisposed) streamController.add(state);

    if (state.isGameOver &&
        state.players.length >= 2 &&
        localPlayerSlot == PlayerSlot.slot1) {
      final winnerUids = state.winners.map((slot) {
        final p = state.players.where((p) => p.slot == slot).firstOrNull;
        return p?.uid ?? slot.name;
      }).toList();

      _db.ref().child(FirebasePaths.session(gameType, gameId)).update({
        'status': 'finished',
        'winners': winnerUids,
      });
    }

    _checkSnapshotRequirement();
  }
}
