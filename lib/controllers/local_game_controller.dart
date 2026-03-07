import 'dart:async';
import 'dart:math';

import '../engine/bot_ai.dart';
import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';
import '../utils/test_initialization.dart';
import 'audio_controller_listener.dart';
import 'game_controller.dart';
import 'game_execution_mixin.dart';

class PlayerSetupConfig {
  final String name;
  final bool isBot;

  PlayerSetupConfig({
    required this.name,
    this.isBot = false,
  });
}

class LocalGameController with GameExecutionMixin implements GameController {
  final _streamController = StreamController<GameState>.broadcast();
  final GameEngine _engine = GameEngine();

  @override
  GameEngine get engine => _engine;

  GameState _state;

  @override
  GameState get state => _state;

  @override
  set state(GameState newState) => _state = newState;

  @override
  StreamController<GameState> get streamController => _streamController;

  bool _isActionInProgress = false;
  bool _isPaused = false;

  bool _isDisposed = false;

  @override
  bool get isDisposed => _isDisposed;

  final InitialGameState initialState;
  late final AudioControllerListener _audioListener;

  LocalGameController(Map<PlayerSlot, PlayerSetupConfig> config,
      {this.initialState = InitialGameState.normal})
      : _state = GameState(
            gameId: "",
            players: [],
            turnOrder: [],
            currentTurn: PlayerSlot.slot1) {
    _state = _createInitialState(config, initialState);
    _audioListener = AudioControllerListener(this);
    _audioListener.start();
    Future.microtask(_checkBotTurn);
  }

  void _checkBotTurn() async {
    if (_isDisposed || _isPaused || _isActionInProgress || _state.isGameOver) {
      return;
    }
    final currentPlayer =
        _state.players.firstWhere((p) => p.slot == _state.currentTurn);
    if (!currentPlayer.isBot) return;

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
    if (_isActionInProgress) return;
    final dice = generateDiceValue();
    await executeRoll(dice);
  }

  @override
  Future<void> sendMoveIntent(Token token) async {
    if (_isActionInProgress) return;
    await executeMove(token.id);
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
  void onEngineEvents(List<EngineEvent> events) {
    _audioListener.handleEngineEvents(events);
  }

  @override
  void onMoveStart(int steps) {
    _audioListener.playMoveSound(steps);
  }

  @override
  Future<void> executeMove(int tokenId) async {
    if (!_state.isDiceRolled || _isActionInProgress) return;

    _isActionInProgress = true;

    try {
      await performMoveExecution(tokenId);
    } finally {
      _isActionInProgress = false;
      _checkBotTurn();
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
    _isDisposed = true;
    _audioListener.stop();
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
        isBot: e.value.isBot,
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
