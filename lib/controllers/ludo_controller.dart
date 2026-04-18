import 'dart:async';
import 'dart:math';

import '../engine/bot_ai.dart';
import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/firebase_service.dart';
import '../models/token.dart';
import '../utils/test_initialization.dart';
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
  Future<void> executeRoll(int value);
  Future<void> executeMove(int tokenId);

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

    _eventSubscription = this.eventProvider.events.listen(handleGameEvent);
    Future.microtask(_checkBotTurn);
  }

  bool get isMyTurn =>
      localPlayerSlot == null || state.currentTurn == localPlayerSlot;

  Future<void> handleGameEvent(GameEvent event) async {
    if (_isDisposed || _isPaused || _isActionInProgress || _state.isGameOver) {
      return;
    }

    if (event is RollEvent) {
      await executeRoll(event.diceValue);
    } else if (event is MoveEvent) {
      await executeMove(event.tokenId);
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
    await Future.delayed(const Duration(milliseconds: 600));
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

  static int generateDiceValue() => _rng.nextInt(6) + 1;

  @override
  Future<void> sendRollIntent() async {
    if (_isDisposed ||
        !isMyTurn ||
        _state.isDiceRolled ||
        _state.isRolling ||
        _isActionInProgress) {
      return;
    }

    final prefetched = _state.prefetchedRoll;

    if (prefetched != null && state.gameType == GameType.online) {
      // OPTIMISTIC PREFETCH FLOW
      _state = _state.copyWith(
        isRolling: true,
        isWaitingForResult: true,
        diceValue: prefetched,
        prefetchedRoll: null, // Clear it locally so it cannot be reused
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
      eventProvider.onRollRequested();
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
  Future<void> executeRoll(int value, {bool skipSounds = false}) async {
    if (_isDisposed || _state.isDiceRolled || _isActionInProgress) return;
    _isActionInProgress = true;

    // Initial "anticipation" phase for all players (Local, Remote, and Bot)
    // If the local player already optimistically landed, we skip the waiting phase
    bool alreadyLanded = !_state.isWaitingForResult &&
        _state.isRolling &&
        _state.diceValue == value;

    if (!alreadyLanded) {
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

    if (!skipSounds && !_isDisposed) {
      _audioListener.handleEngineEvents(result.events);
    }

    if (!_isDisposed) _streamController.add(_state);

    bool isAutoAction = autoMoveId != null || isTurnSkipped;

    if (isAutoAction) {
      // Pause so user can digest the roll before the auto-move/skip
      await Future.delayed(const Duration(milliseconds: 400));
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
      await Future.delayed(const Duration(milliseconds: 250));
      await sendMoveIntent(token);
    } else {
      _checkBotTurn();
    }
  }

  @override
  Future<void> executeMove(int tokenId) async {
    if (_isDisposed || _isActionInProgress) return;
    _isActionInProgress = true;
    await _executor.execute(_state, tokenId, _state.diceValue);
    _isActionInProgress = false;
    if (!_isDisposed) {
      // Always set new timestamp for whoever's turn it is now (Bonus turn or next player)
      _state = _state.copyWith(
        turnStartedAt: firebaseService.serverTimeMillis,
        turnActionCount: _state.turnActionCount + 1,
      );
      _streamController.add(_state);
    }
    _checkBotTurn();
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
