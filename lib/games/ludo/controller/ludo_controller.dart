import 'dart:async';
import 'dart:math';

import '../domain/engine/bot_ai.dart';
import '../domain/engine/game_engine.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import '../domain/models/token.dart';
import 'package:ludo_prince/utils/test_initialization.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'src/audio_listener.dart';
import 'src/move_executor.dart';
import 'src/game_event_provider.dart';

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

  PlayerSetupConfig({required this.name, this.type = PlayerType.localHuman});
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

  @override
  final PlayerSlot? localPlayerSlot;
  final GameMode gameMode;

  LudoController(
    Map<PlayerSlot, PlayerSetupConfig> config, {
    this.initialState = InitialGameState.normal,
    this.localPlayerSlot,
    this.gameMode = GameMode.classic,
    GameEventProvider? eventProvider,
  })  : _state = GameState(
          gameId: "",
          players: [],
          turnOrder: [],
          currentTurn: PlayerSlot.slot1,
        ),
        eventProvider = eventProvider ?? LocalEventProvider() {
    _state = _createInitialState(config, initialState, gameMode);
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

  bool get isMyTurn =>
      localPlayerSlot == null || state.currentTurn == localPlayerSlot;

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
    await Future.delayed(const Duration(milliseconds: 200));
    _isActionInProgress = false;

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

  static const List<double> _prdChances = [
    0.00,
    0.02,
    0.05,
    0.133077,
    0.21,
    0.34,
    0.55,
    0.82,
    1.00
  ];

  static int generatePRDDice(int seed, int pity) {
    if (pity < 0) pity = 0;
    if (pity >= _prdChances.length) pity = _prdChances.length - 1;

    double chanceOfSix = _prdChances[pity];
    int threshold = (chanceOfSix * 10000000).toInt();

    if (seed < threshold) {
      return 6;
    } else {
      return (seed % 5) + 1;
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

    if (prefetchedSeed != null && state.gameType == GameType.online) {
      // OPTIMISTIC PREFETCH FLOW
      final currentPlayer =
          _state.players.firstWhere((p) => p.slot == _state.currentTurn);
      final diceValue = generatePRDDice(prefetchedSeed, currentPlayer.sixPity);

      _state = _state.copyWith(
        isRolling: true,
        isWaitingForResult: true,
        diceValue: diceValue,
        prefetchedSeed: null, // Clear it locally so it cannot be reused
      );
      if (!_isDisposed) _streamController.add(_state);

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

      int? localDice;
      if (state.gameType == GameType.local) {
        final currentPlayer =
            _state.players.firstWhere((p) => p.slot == _state.currentTurn);
        localDice =
            generatePRDDice(generateRandomSeed(), currentPlayer.sixPity);
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
    if (_isDisposed || _state.isDiceRolled || _isActionInProgress) return;
    _isActionInProgress = true;

    // Initial "anticipation" phase for all players (Local, Remote, and Bot)
    // If the local player already optimistically landed, we skip the waiting phase
    bool alreadyLanded = !_state.isWaitingForResult &&
        _state.isRolling &&
        _state.diceValue == value;

    if (!alreadyLanded && !fastForward) {
      _state = _state.copyWith(isRolling: true, isWaitingForResult: true);
      if (!_isDisposed) _streamController.add(_state);

      // Minimum "anticipation" duration to ensure the loop is heard/seen
      await Future.delayed(const Duration(milliseconds: 300));
      if (_isDisposed) {
        _isActionInProgress = false;
        return;
      }

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

    int? autoMoveId;
    bool isTurnSkipped = result.events.contains(EngineEvent.turnSkipped);

    // Auto move if only 1 valid token or all valid tokens at same place
    if (resultState.isDiceRolled) {
      final player = resultState.players.firstWhere(
        (p) => p.slot == resultState.currentTurn,
      );

      final validTokens = player.tokens
          .where((t) => _engine.isValidMove(t, resultState.diceValue))
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

    _state = resultState.copyWith(
      isRolling: false,
      lastAction: GameAction.roll,
      turnStartedAt: firebaseService.serverTimeMillis,
      turnActionCount: _state.turnActionCount + 1,
    );

    if (!skipSounds && !fastForward && !_isDisposed) {
      _audioListener.handleEngineEvents(result.events);
    }

    if (!_isDisposed) _streamController.add(_state);

    bool isAutoAction = autoMoveId != null || isTurnSkipped;

    if (isAutoAction && !fastForward) {
      // Pause so user can digest the roll before the auto-move/skip
      await Future.delayed(const Duration(milliseconds: 150));
      if (_isDisposed) {
        _isActionInProgress = false;
        return;
      }
    }

    _isActionInProgress = false;

    if (autoMoveId != null) {
      final player = _state.players.firstWhere(
        (p) => p.slot == _state.currentTurn,
      );
      final token = player.tokens.firstWhere((t) => t.id == autoMoveId);
      // Yield to the event loop before auto-move to allow UI to render
      if (!fastForward) await Future.delayed(const Duration(milliseconds: 50));
      await sendMoveIntent(token);
    } else {
      // Schedule on event loop (not microtask) so UI can paint between bot turns
      Future.delayed(Duration.zero, _checkBotTurn);
    }
  }

  @override
  Future<void> executeMove(int tokenId, {bool fastForward = false}) async {
    if (_isDisposed || _isActionInProgress) return;
    _isActionInProgress = true;
    await _executor.execute(_state, tokenId, _state.diceValue,
        fastForward: fastForward);
    _isActionInProgress = false;
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
    GameMode gameMode,
  ) {
    List<Player> players = config.entries.map((e) {
      List<Token> tokens = List.generate(4, (i) => Token(id: i, slot: e.key));

      tokens = TestInitialization.applyTestState(tokens, initialState);

      return Player(
        slot: e.key,
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
      lastAction: GameAction.none,
      winners: const [],
      gameType: GameType.local,
      turnStartedAt: firebaseService.serverTimeMillis,
    );
  }
}
