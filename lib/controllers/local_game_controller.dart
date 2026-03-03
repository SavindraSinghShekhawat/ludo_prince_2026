import 'dart:async';
import 'dart:math';

import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';
import '../services/audio_service.dart';
import 'game_controller.dart';

class PlayerSetupConfig {
  final String name;
  final bool isBot;

  PlayerSetupConfig({
    required this.name,
    this.isBot = false,
  });
}

class LocalGameController implements GameController {
  final _streamController = StreamController<GameState>.broadcast();
  final GameEngine _engine = GameEngine();
  late GameState _state;
  bool _isActionInProgress = false;

  LocalGameController(Map<PlayerSlot, PlayerSetupConfig> config) {
    _state = _createInitialState(config);
    Future.microtask(_checkBotTurn);
  }

  void _checkBotTurn() async {
    if (_isActionInProgress || _state.isGameOver) return;
    final currentPlayer =
        _state.players.firstWhere((p) => p.slot == _state.currentTurn);
    if (!currentPlayer.isBot) return;

    _isActionInProgress = true;
    await Future.delayed(const Duration(milliseconds: 600));
    _isActionInProgress = false;

    if (_state.currentTurn != currentPlayer.slot || _state.isGameOver) return;

    if (!_state.isDiceRolled) {
      await sendRollIntent();
    } else {
      final validTokens = currentPlayer.tokens
          .where((t) => _engine.isValidMove(t, _state.diceValue))
          .toList();

      if (validTokens.isNotEmpty) {
        final token = validTokens[Random().nextInt(validTokens.length)];
        await executeMove(token.id);
      }
    }
  }

  @override
  Stream<GameState> watchGame() async* {
    yield _state;
    yield* _streamController.stream;
  }

  @override
  Future<void> sendRollIntent() async {
    if (_isActionInProgress) return;
    final dice = Random.secure().nextInt(6) + 1;
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

    await audioService.playRoll();
    if (value == 6) {
      await audioService.playSix();
    }

    _state = _engine.rollDice(_state, value).copyWith(
          lastAction: GameAction.roll,
        );

    _streamController.add(_state);

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
      await Future.delayed(const Duration(milliseconds: 300));
      await executeMove(autoMoveId);
    } else {
      _checkBotTurn();
    }
  }

  void _finalizeAfterMove(int tokenId, bool captured) {
    _state = _engine.moveToken(_state, tokenId, captured: captured);

    GameAction action = GameAction.move;

    if (captured) {
      action = GameAction.capture;
    } else {
      final currentPlayer =
          _state.players.firstWhere((p) => p.slot == _state.currentTurn);

      final token = currentPlayer.tokens.firstWhere((t) => t.id == tokenId);

      if (token.state == TokenState.finished) {
        action = GameAction.finish;
      }
    }

    _state = _state.copyWith(lastAction: action);

    _streamController.add(_state);
  }

  @override
  Future<void> executeMove(int tokenId) async {
    if (!_state.isDiceRolled || _isActionInProgress) return;

    final player =
        _state.players.firstWhere((p) => p.slot == _state.currentTurn);
    final token = player.tokens.firstWhere((t) => t.id == tokenId);

    if (token.slot != _state.currentTurn) return;

    _isActionInProgress = true;

    try {
      int steps = _state.diceValue;
      bool captured = false;

      // 🔥 Home exit case
      if (token.state == TokenState.home && steps == 6) {
        await audioService.playMove(1);

        Token updated = token.copyWith(
          state: TokenState.board,
          position: 0,
        );

        // Capture allowed here (this is final landing)
        _state = _engine.applyStep(
          _state,
          updated,
          onCapture: (c) => captured = c,
        );

        _streamController.add(_state);

        if (captured) {
          await audioService.playDie();
        }

        _finalizeAfterMove(updated.id, captured);
        return;
      }

      await audioService.playMove(steps);

      Token currentToken = token;

      // Intermediate steps — NO capture
      for (int i = 0; i < steps - 1; i++) {
        currentToken = _engine.advanceOneStep(currentToken);

        _state = _engine.applyStep(
          _state,
          currentToken,
          onCapture: (_) {},
          allowCapture: false,
        );

        _streamController.add(_state);

        await Future.delayed(const Duration(milliseconds: 150));
      }

      // Final step — capture allowed
      currentToken = _engine.advanceOneStep(currentToken);

      _state = _engine.applyStep(
        _state,
        currentToken,
        onCapture: (c) => captured = c,
        allowCapture: true,
      );

      _streamController.add(_state);

      if (currentToken.state == TokenState.finished) {
        await audioService.playHome();
      }

      if (captured) {
        await audioService.playDie();
      }

      _finalizeAfterMove(currentToken.id, captured);
    } finally {
      _isActionInProgress = false;
      _checkBotTurn();
    }
  }

  @override
  Future<void> dispose() async {
    await _streamController.close();
  }

  GameState _createInitialState(Map<PlayerSlot, PlayerSetupConfig> config) {
    List<Player> players = config.entries.map((e) {
      return Player(
        slot: e.key,
        name: e.value.name,
        isBot: e.value.isBot,
        tokens: List.generate(4, (i) => Token(id: i, slot: e.key)),
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
