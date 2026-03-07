import 'dart:async';
import 'dart:math';

import '../engine/bot_ai.dart';
import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/player.dart';
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

  // 1. Intents (called by the UI when a user taps something)
  Future<void> sendRollIntent();
  Future<void> sendMoveIntent(Token token);

  // 2. Executions (Apply the action to the state with animations/effects)
  Future<void> executeRoll(int value);
  Future<void> executeMove(int tokenId);

  // 3. Status
  void pause();
  void resume();
  Future<void> dispose();
}

class PlayerSetupConfig {
  final String name;
  final PlayerType type;

  PlayerSetupConfig({
    required this.name,
    this.type = PlayerType.localHuman,
  });
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

  bool get isDisposed => _isDisposed;

  final InitialGameState initialState;
  late final AudioControllerListener _audioListener;
  late final MoveExecutor _executor;
  final GameEventProvider _eventProvider;

  LudoController(Map<PlayerSlot, PlayerSetupConfig> config,
      {this.initialState = InitialGameState.normal,
      GameEventProvider? eventProvider})
      : _state = GameState(
            gameId: "",
            players: [],
            turnOrder: [],
            currentTurn: PlayerSlot.slot1),
        _eventProvider = eventProvider ?? LocalEventProvider() {
    _state = _createInitialState(config, initialState);
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

    _eventProvider.events.listen(_handleGameEvent);
    Future.microtask(_checkBotTurn);
  }

  void _handleGameEvent(GameEvent event) async {
    if (_isDisposed || _isPaused || _isActionInProgress || _state.isGameOver) {
      return;
    }

    if (event is RollEvent) {
      await executeRoll(event.diceValue);
    } else if (event is MoveEvent) {
      await executeMove(event.tokenId);
    }
  }

  void _checkBotTurn() async {
    if (_isDisposed || _isPaused || _isActionInProgress || _state.isGameOver) {
      return;
    }
    final currentPlayer =
        _state.players.firstWhere((p) => p.slot == _state.currentTurn);
    if (currentPlayer.type != PlayerType.localBot) return;

    _isActionInProgress = true;
    await Future.delayed(const Duration(milliseconds: 1200));
    _isActionInProgress = false;

    if (_isDisposed ||
        _isPaused ||
        _state.currentTurn != currentPlayer.slot ||
        _state.isGameOver) {
      return;
    }

    if (!_state.isDiceRolled) {
      _state = _state.copyWith(isRolling: true);
      if (!_isDisposed) _streamController.add(_state);
      await Future.delayed(const Duration(milliseconds: 600));
      _state = _state.copyWith(isRolling: false);
      await sendRollIntent();
    } else {
      final bestToken = BotAI.getBestMove(currentPlayer, _state);
      if (bestToken != null) {
        await executeMove(bestToken.id);
      }
    }
  }

  @override
  Stream<GameState> watchGame() async* {
    yield _state;
    yield* _streamController.stream;
  }

  @override
  PlayerSlot? get localPlayerSlot => null; // Local games are hotseat by default

  @override
  bool get isActionInProgress => _isActionInProgress;

  static int generateDiceValue() => Random.secure().nextInt(6) + 1;

  @override
  Future<void> sendRollIntent() async {
    _eventProvider.onRollRequested();
  }

  @override
  Future<void> sendMoveIntent(Token token) async {
    _eventProvider.onMoveRequested(token.id);
  }

  @override
  Future<void> executeRoll(int value) async {
    if (_state.isDiceRolled || _isActionInProgress) return;
    _isActionInProgress = true;

    final result = _engine.rollDice(_state, value);
    _state = result.state.copyWith(lastAction: GameAction.roll);

    _audioListener.handleEngineEvents(result.events);

    if (!_isDisposed) _streamController.add(_state);

    int? autoMoveId;

    // Auto move if only 1 valid token or all valid token at same place
    if (_state.isDiceRolled) {
      final player =
          _state.players.firstWhere((p) => p.slot == _state.currentTurn);

      final validTokens = player.tokens
          .where((t) => _engine.isValidMove(t, _state.diceValue))
          .toList();

      if (validTokens.isNotEmpty) {
        bool allSamePosition = validTokens.every((t) =>
            t.state == validTokens.first.state &&
            t.position == validTokens.first.position);

        bool allInHome = validTokens.every((t) => t.state == TokenState.home);

        if (validTokens.length == 1 || (allSamePosition && !allInHome)) {
          autoMoveId = validTokens.first.id;
        }
      }
    }

    _isActionInProgress = false;

    if (autoMoveId != null) {
      await Future.delayed(const Duration(milliseconds: 250));
      await executeMove(autoMoveId);
    } else {
      _checkBotTurn();
    }
  }

  @override
  Future<void> executeMove(int tokenId) async {
    if (_isActionInProgress) return;
    _isActionInProgress = true;
    await _executor.execute(_state, tokenId, _state.diceValue);
    _isActionInProgress = false;
    _checkBotTurn();
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
    _isDisposed = true;
    _audioListener.stop();
    _eventProvider.dispose();
    await _streamController.close();
  }

  GameState _createInitialState(Map<PlayerSlot, PlayerSetupConfig> config,
      InitialGameState initialState) {
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
      lastAction: GameAction.none,
      winners: const [],
    );
  }
}
