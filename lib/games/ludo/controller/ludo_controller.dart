import 'dart:async';
import 'dart:math';

import '../domain/engine/bot_ai.dart';
import '../domain/engine/game_engine.dart';
import '../domain/models/game_rules.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import '../domain/models/token.dart';
import 'package:ludo_prince/utils/test_initialization.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'src/audio_listener.dart';
import 'src/move_executor.dart';
import 'src/game_event_provider.dart';
import 'package:ludo_prince/utils/app_logger.dart';

abstract class GameController {
  Stream<GameState> watchGame();
  GameState get state;

  PlayerSlot? get localPlayerSlot;
  bool get isActionInProgress;
  bool get isDisposed;

  // 1. Intents (called by the UI when a user taps something)
  Future<void> sendRollIntent();
  Future<void> sendMoveIntent(Token token);

  // 2. Executions (Apply the action to the state with animations/effects)
  Future<void> executeRoll(int value, {bool fastForward = false});
  Future<void> executeMove(int tokenId, {bool fastForward = false});

  // 3. Status
  void pause();
  void resume();
  void quitGame();
  Future<void> dispose();
}

class PlayerSetupConfig {
  final String name;
  final PlayerType type;
  final String? uid;

  PlayerSetupConfig(
      {required this.name, this.type = PlayerType.localHuman, this.uid});
}

class LudoController implements GameController {
  final _streamController = StreamController<GameState>.broadcast();
  final GameEngine _engine = GameEngine();

  GameEngine get engine => _engine;

  GameState _state;

  @override
  GameState get state => _state;

  set state(GameState newState) => _state = newState;

  StreamController<GameState> get streamController => _streamController;

  bool _isActionInProgress = false;
  bool _isPaused = false;

  bool _isDisposed = false;

  @override
  bool get isDisposed => _isDisposed;

  final InitialGameState initialState;
  late final AudioControllerListener _audioListener;
  late final MoveExecutor _executor;
  final GameEventProvider eventProvider;
  StreamSubscription<GameEvent>? _eventSubscription;

  final List<GameEvent> _eventQueue = [];
  bool _isProcessingQueue = false;
  Timer? _rollSafetyTimer;

  void _startRollSafetyTimer() {
    _rollSafetyTimer?.cancel();
    _rollSafetyTimer = Timer(const Duration(milliseconds: 3000), () {
      if (_isDisposed) return;
      if (_state.isRolling || _state.isWaitingForResult) {
        AppLogger.debug(
          '[LudoController] Roll response timed out after 3s. Unlocking dice.',
        );
        _state = _state.copyWith(
          isRolling: false,
          isWaitingForResult: false,
        );
        _isActionInProgress = false;
        if (!_isDisposed) _streamController.add(_state);
      }
    });
  }

  @override
  final PlayerSlot? localPlayerSlot;
  final GameMode gameMode;
  final GameRules rules;

  LudoController(
    Map<PlayerSlot, PlayerSetupConfig> config, {
    this.initialState = InitialGameState.normal,
    this.localPlayerSlot,
    this.gameMode = GameMode.classic,
    this.rules = const GameRules(),
    GameEventProvider? eventProvider,
  })  : _state = GameState(
          gameId: "",
          players: [],
          turnOrder: [],
          currentTurn: PlayerSlot.slot1,
          gameMode: gameMode,
          rules: rules,
        ),
        eventProvider = eventProvider ?? LocalEventProvider() {
    _state = _createInitialState(config, initialState, gameMode, rules: rules);
    _audioListener = AudioControllerListener(this);
    _audioListener.start();

    _executor = MoveExecutor(
      engine: _engine,
      onStateUpdate: (state) {
        _state = state;
        if (!_isDisposed) _streamController.add(_state);
      },
      onMoveStart: (steps) => _audioListener.playMoveSound(steps),
      onEngineEvents: (events) => _audioListener.handleEngineEvents(events),
      isDisposed: () => _isDisposed,
    );

    _eventSubscription = this.eventProvider.events.listen(_onEventReceived);
    // Use event-loop scheduling (not microtask) so the first frame renders before bot acts
    Future.delayed(Duration.zero, _checkBotTurn);
  }

  bool get isMyTurn {
    if (localPlayerSlot == null || state.currentTurn == localPlayerSlot) {
      return true;
    }
    return state.players.any(
      (p) => p.slot == state.currentTurn && p.type == PlayerType.localBot,
    );
  }

  void _onEventReceived(GameEvent event) {
    _eventQueue.add(event);
    if (!_isProcessingQueue) {
      _processEventQueue();
    }
  }

  Future<void> _processEventQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_eventQueue.isNotEmpty) {
        if (_isDisposed || _state.isGameOver) {
          _eventQueue.clear();
          break;
        }
        if (_isPaused) {
          break;
        }

        while (_isActionInProgress) {
          await Future.delayed(const Duration(milliseconds: 50));
          if (_isDisposed || _state.isGameOver || _isPaused) break;
        }

        if (_isDisposed || _state.isGameOver || _isPaused) break;

        final event = _eventQueue.removeAt(0);
        final bool fastForward =
            _eventQueue.isNotEmpty; // Fast forward if not the last event
        try {
          await handleGameEvent(event, fastForward: fastForward);
        } catch (e, st) {
          // Log the error and forcefully release locks to prevent permanent freeze
          print("Error processing game event: $e\n$st");
          _isActionInProgress = false;
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> handleGameEvent(GameEvent event,
      {bool fastForward = false}) async {
    if (_isDisposed || _state.isGameOver) {
      return;
    }

    if (event is RollEvent) {
      await executeRoll(event.diceValue, fastForward: fastForward);
    } else if (event is MoveEvent) {
      await executeMove(event.tokenId, fastForward: fastForward);
    } else if (event is QuitEvent) {
      final result = _engine.quitPlayer(_state, event.playerSlot);
      _state = result.state.copyWith(lastAction: GameAction.quit);
      if (!_isDisposed) _streamController.add(_state);
    }
  }

  void _checkBotTurn() async {
    if (_isDisposed || _isPaused || _isActionInProgress || _state.isGameOver) {
      return;
    }
    final currentPlayer = _state.players.firstWhere(
      (p) => p.slot == _state.currentTurn,
    );
    if (currentPlayer.type != PlayerType.localBot) return;

    _isActionInProgress = true;
    // Use Future.delayed (Timer-based) instead of Future.microtask to ensure
    // the UI event loop gets a chance to process frames between bot turns.
    // This prevents the freeze when multiple bots trade rapid-fire turns.
    try {
      await Future.delayed(const Duration(milliseconds: 200));
    } finally {
      _isActionInProgress = false;
    }

    if (_isDisposed ||
        _isPaused ||
        _state.currentTurn != currentPlayer.slot ||
        _state.isGameOver) {
      return;
    }

    if (!_state.isDiceRolled) {
      await sendRollIntent();
    } else {
      final bestToken = BotAI.getBestMove(currentPlayer, _state);
      if (bestToken != null) {
        await sendMoveIntent(bestToken);
      }
    }
  }

  @override
  Stream<GameState> watchGame() async* {
    yield _state;
    yield* _streamController.stream;
  }

  @override
  bool get isActionInProgress => _isActionInProgress;

  static Random? __rng;
  static Random get _rng {
    try {
      return __rng ??= Random.secure();
    } catch (e) {
      // Fallback only if Random.secure() is unsupported on the platform.
      // We use the current time and a few other entropy sources for the fallback seed.
      print(
        "WARNING: Random.secure() not supported. Using seeded Random as fallback.",
      );
      return __rng ??= Random(
        DateTime.now().microsecondsSinceEpoch ^ 0xDEADBEEF,
      );
    }
  }

  /// Determines if a player is stranded and genuinely needs base-exit pity.
  /// Edge cases handled:
  /// 1. Start of game (all tokens in base) -> true (needs pity)
  /// 2. Finished tokens + tokens in base, but 0 on the board -> true (needs pity)
  /// 3. Tokens on board but all are blocked in home stretch (pos >= 55) -> true (needs pity)
  /// 4. Tokens active on main board (pos 0..50) -> false (100% fair dice)
  /// 5. All tokens out of base -> false (100% fair dice)
  static bool playerNeedsBasePity(Player player) {
    final hasTokensInBase =
        player.tokens.any((t) => t.state == TokenState.home);
    if (!hasTokensInBase) return false;

    // If player has any active token on the main board track, they are in active play
    final hasTokensOnBoard =
        player.tokens.any((t) => t.state == TokenState.board);
    if (hasTokensOnBoard) return false;

    // If all active tokens are in homeStretch, check if any can still advance
    final hasMovableHomeStretch = player.tokens.any(
      (t) => t.state == TokenState.homeStretch && t.position < 55,
    );
    if (hasMovableHomeStretch) return false;

    // Player has 0 active board tokens and no movable home stretch tokens.
    // They are genuinely stranded and need a 6 to bring out a piece.
    return true;
  }

  static int generatePRDDice(
    int seed,
    int pity, {
    bool isBonusRoll = false,
    bool needsBasePity = false,
  }) {
    // Pity is applied ONLY when a player is stranded and needs to exit base.
    // In active board play or on any bonus roll (consecutive 6 / capture),
    // the die is 100% pure, mathematically fair 1-in-6 ((seed % 6) + 1).
    if (isBonusRoll || !needsBasePity) {
      return (seed % 6) + 1;
    }

    // Emergency Airbag Base-Exit Curve:
    // Turns 1..6 (pity 0..5): Pure natural 1/6 luck (~66.5% exit naturally)
    // Turn 7 (pity 6): 25% assist
    // Turn 8 (pity 7): 50% assist
    // Turn 9+ (pity >= 8): 100% guaranteed safety ceiling
    if (pity < 6) {
      return (seed % 6) + 1;
    } else if (pity == 6) {
      return (seed % 100 < 25) ? 6 : (seed % 5) + 1;
    } else if (pity == 7) {
      return (seed % 100 < 50) ? 6 : (seed % 5) + 1;
    } else {
      return 6;
    }
  }

  static int generateDiceValue() => _rng.nextInt(6) + 1;

  static int generateRandomSeed() => _rng.nextInt(10000000);

  @override
  Future<void> sendRollIntent() async {
    if (_isDisposed ||
        !isMyTurn ||
        _state.isDiceRolled ||
        _state.isRolling ||
        _isActionInProgress) {
      return;
    }

    final prefetchedSeed = _state.prefetchedSeed;
    final currentPlayer =
        _state.players.firstWhere((p) => p.slot == _state.currentTurn);
    final isBonusRoll =
        _state.consecutiveSixes > 0 || _state.lastAction == GameAction.capture;
    final needsPity = playerNeedsBasePity(currentPlayer);

    if (prefetchedSeed != null && state.gameType == GameType.online) {
      // OPTIMISTIC PREFETCH FLOW
      final diceValue = generatePRDDice(
        prefetchedSeed,
        currentPlayer.sixPity,
        isBonusRoll: isBonusRoll,
        needsBasePity: needsPity,
      );

      _state = _state.copyWith(
        isRolling: true,
        isWaitingForResult: true,
        diceValue: diceValue,
        prefetchedSeed: null, // Clear it locally so it cannot be reused
      );
      if (!_isDisposed) _streamController.add(_state);

      _startRollSafetyTimer();

      // Start the intent request immediately
      eventProvider.onRollRequested();

      // Artificial "rolling" duration for visual feel
      await Future.delayed(const Duration(milliseconds: 650));
      if (_isDisposed) return;

      // "Land" the dice locally
      _state = _state.copyWith(isWaitingForResult: false);
      if (!_isDisposed) _streamController.add(_state);

      // The actual execution (engine logic) will happen when the RollEvent
      // arrives from the server, making it authoritative.
    } else {
      // CLASSIC FLOW (Local, Bot, or fallback)
      _state = _state.copyWith(isRolling: true, isWaitingForResult: true);
      if (!_isDisposed) _streamController.add(_state);

      _startRollSafetyTimer();

      int? localDice;
      if (state.gameType == GameType.local) {
        localDice = generatePRDDice(
          generateRandomSeed(),
          currentPlayer.sixPity,
          isBonusRoll: isBonusRoll,
          needsBasePity: needsPity,
        );
      }

      eventProvider.onRollRequested(diceValue: localDice);
    }
  }

  @override
  Future<void> sendMoveIntent(Token token) async {
    if (_isDisposed ||
        !isMyTurn ||
        !_state.isDiceRolled ||
        _isActionInProgress) {
      return;
    }
    eventProvider.onMoveRequested(token.id);
  }

  @override
  Future<void> executeRoll(int value,
      {bool skipSounds = false, bool fastForward = false}) async {
    _rollSafetyTimer?.cancel();
    if (_isDisposed || _isActionInProgress) return;
    
    // Store whether it was our turn before we evaluate the roll
    bool wasMyTurn = localPlayerSlot == _state.currentTurn;
    int? autoMoveId;
    bool isTurnSkipped = false;

    _isActionInProgress = true;

    try {
      // For local human, pause execution if the previous action was a roll
      if (!fastForward && _state.lastAction == GameAction.roll) {
        // Pause slightly between sequential rolls
        await Future.delayed(const Duration(milliseconds: 300));
        if (_isDisposed) return;
      }

      bool alreadyLanded = _state.diceValue == value && !_state.isRolling;

      if (!alreadyLanded && !fastForward) {
        _state = _state.copyWith(
          isRolling: true,
          isWaitingForResult: true,
        );
        if (!_isDisposed) _streamController.add(_state);

        // Minimum "anticipation" duration to ensure the loop is heard/seen
        await Future.delayed(const Duration(milliseconds: 300));
        if (_isDisposed) return;

        // Transition from "waiting" to "showing result"
        _state = _state.copyWith(
          isRolling: true,
          isWaitingForResult: false,
          diceValue: value,
        );
        if (!_isDisposed) _streamController.add(_state);

        // Fixed duration for the "landing" animation
        await Future.delayed(const Duration(milliseconds: 450));
      } else if (!alreadyLanded && fastForward) {
        _state = _state.copyWith(
          isRolling: false,
          isWaitingForResult: false,
          diceValue: value,
        );
      }
      if (!_isDisposed) _streamController.add(_state);

      // Now calculate the engine result to determine if an auto-action is pending
      final result = _engine.rollDice(_state, value);
      final resultState = result.state;

      isTurnSkipped = result.events.contains(EngineEvent.turnSkipped);

      // Auto move if only 1 valid token or all valid tokens at same place
      if (resultState.isDiceRolled) {
        final player = resultState.players.firstWhere(
          (p) => p.slot == resultState.currentTurn,
        );

        final validTokens = player.tokens
            .where((t) => _engine.isValidMove(
                  t,
                  resultState.diceValue,
                  rules: resultState.rules,
                ))
            .toList();

        if (validTokens.isNotEmpty) {
          bool allSamePosition = validTokens.every(
            (t) =>
                t.state == validTokens.first.state &&
                t.position == validTokens.first.position,
          );

          bool allInHome = validTokens.every((t) => t.state == TokenState.home);

          if (validTokens.length == 1 || (allSamePosition && !allInHome)) {
            autoMoveId = validTokens.first.id;
          }
        }
      }

      // In online mode with a skipped turn, do NOT advance currentTurn eagerly on the client.
      // Wait for the server authoritative SkipEvent so the next player's dice doesn't activate
      // before the server has accepted the previous player's skip.
      final nextState = (_state.gameType == GameType.online && isTurnSkipped)
          ? resultState.copyWith(
              currentTurn: _state.currentTurn,
              isRolling: false,
              isWaitingForResult: false,
              isDiceRolled: true,
              lastAction: GameAction.roll,
              turnStartedAt: firebaseService.serverTimeMillis,
              turnActionCount: _state.turnActionCount + 1,
            )
          : resultState.copyWith(
              isRolling: false,
              isWaitingForResult: false,
              lastAction: GameAction.roll,
              turnStartedAt: firebaseService.serverTimeMillis,
              turnActionCount: _state.turnActionCount + 1,
            );

      _state = nextState;

      if (!skipSounds && !fastForward && !_isDisposed) {
        _audioListener.handleEngineEvents(result.events);
      }

      if (!_isDisposed) _streamController.add(_state);

      bool isAutoAction = autoMoveId != null || isTurnSkipped;

      if (isAutoAction && !fastForward) {
        // Pause so user can digest the roll before the auto-move/skip
        await Future.delayed(const Duration(milliseconds: 150));
        if (_isDisposed) return;
      }
    } finally {
      _isActionInProgress = false;
    }

    if (_isDisposed) return;

    if (autoMoveId != null) {
      final player = _state.players.firstWhere(
        (p) => p.slot == _state.currentTurn,
      );
      final token = player.tokens.firstWhere((t) => t.id == autoMoveId);
      // Yield to the event loop before auto-move to allow UI to render
      if (!fastForward) await Future.delayed(const Duration(milliseconds: 50));
      await sendMoveIntent(token);
    } else if (isTurnSkipped && wasMyTurn && _state.gameType == GameType.online) {
      eventProvider.onSkipRequested();
      Future.delayed(Duration.zero, _checkBotTurn);
    } else {
      // Schedule on event loop (not microtask) so UI can paint between bot turns
      Future.delayed(Duration.zero, _checkBotTurn);
    }
  }

  @override
  Future<void> executeMove(int tokenId, {bool fastForward = false}) async {
    if (_isDisposed || _isActionInProgress) return;
    _isActionInProgress = true;
    try {
      await _executor.execute(_state, tokenId, _state.diceValue,
          fastForward: fastForward);
    } finally {
      _isActionInProgress = false;
    }
    if (!_isDisposed) {
      // Always set new timestamp for whoever's turn it is now (Bonus turn or next player)
      _state = _state.copyWith(
        turnStartedAt: firebaseService.serverTimeMillis,
        turnActionCount: _state.turnActionCount + 1,
      );
      _streamController.add(_state);
    }
    // Schedule bot turn check on event loop to yield to UI between turns
    Future.delayed(Duration.zero, _checkBotTurn);
  }

  @override
  void quitGame() {
    _isDisposed =
        true; // Mark as disposed immediately to silence further actions
    _audioListener.stop();
    if (localPlayerSlot != null) {
      eventProvider.onQuitRequested(localPlayerSlot!);
    }
  }

  @override
  void pause() {
    _isPaused = true;
  }

  @override
  void resume() {
    if (_isPaused) {
      _isPaused = false;
      if (_eventQueue.isNotEmpty && !_isProcessingQueue) {
        _processEventQueue();
      }
      _checkBotTurn();
    }
  }

  @override
  Future<void> dispose() async {
    _rollSafetyTimer?.cancel();
    if (_isDisposed && _streamController.isClosed) return;

    _isDisposed = true;
    _audioListener.stop();
    _eventSubscription?.cancel();
    eventProvider.dispose();
    // Release all pooled audio players to free native resources
    audioService.disposeAllSfx();
    if (!_streamController.isClosed) {
      await _streamController.close();
    }
  }

  GameState _createInitialState(
    Map<PlayerSlot, PlayerSetupConfig> config,
    InitialGameState initialState,
    GameMode gameMode, {
    GameRules rules = const GameRules(),
  }) {
    List<Player> players = config.entries.map((e) {
      List<Token> tokens = List.generate(
        rules.tokensPerPlayer,
        (i) => Token(id: i, slot: e.key),
      );

      tokens = TestInitialization.applyTestState(tokens, initialState);

      return Player(
        slot: e.key,
        uid: e.value.uid,
        name: e.value.name,
        type: e.value.type,
        tokens: tokens,
      );
    }).toList();

    return GameState(
      gameId: "local_${DateTime.now().millisecondsSinceEpoch}",
      players: players,
      turnOrder: config.keys.toList(),
      currentTurn: config.keys.first,
      gameMode: gameMode,
      rules: rules,
      lastAction: GameAction.none,
      winners: const [],
      gameType: GameType.local,
      turnStartedAt: firebaseService.serverTimeMillis,
    );
  }
}
