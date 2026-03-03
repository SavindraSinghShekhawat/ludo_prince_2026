import 'dart:async';
import 'dart:math';

import '../engine/game_engine.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';
import '../services/audio_service.dart';
import 'game_controller.dart';

class LocalGameController implements GameController {
  final _streamController = StreamController<GameState>.broadcast();
  final GameEngine _engine = GameEngine();
  late GameState _state;

  LocalGameController(Map<PlayerColor, String> config) {
    _state = _createInitialState(config);
  }

  @override
  Stream<GameState> watchGame() async* {
    yield _state;
    yield* _streamController.stream;
  }

  // Multiplayer-ready roll
  @override
  Future<void> rollDice({int? forcedValue}) async {
    if (_state.isDiceRolled) return;

    final dice = forcedValue ?? (Random.secure().nextInt(6) + 1);

    await audioService.playRoll();
    if (dice == 6) {
      await audioService.playSix();
    }

    _state = _engine.rollDice(_state, dice).copyWith(
          lastAction: GameAction.roll,
        );

    _streamController.add(_state);

    // Auto move if only 1 valid token or all valid token at same place
    if (_state.isDiceRolled) {
      final player = _state.players.firstWhere((p) => p.color == _state.currentTurn);

      final validTokens = player.tokens.where((t) => _engine.isValidMove(t, _state.diceValue)).toList();

      if (validTokens.isNotEmpty) {
        bool allSamePosition = validTokens.every((t) => t.state == validTokens.first.state && t.position == validTokens.first.position);

        bool allInHome = validTokens.every((t) => t.state == TokenState.home);

        // Auto move only if:
        // - Only 1 valid token
        // OR
        // - All share same position AND not all in home
        if (validTokens.length == 1 || (allSamePosition && !allInHome)) {
          await Future.delayed(const Duration(milliseconds: 300));
          await moveToken(validTokens.first);
        }
      }
    }
  }

  void _finalizeAfterMove(int tokenId, bool captured) {
    _state = _engine.moveToken(_state, tokenId);

    GameAction action = GameAction.move;

    if (captured) {
      action = GameAction.capture;
    } else {
      final currentPlayer = _state.players.firstWhere((p) => p.color == _state.currentTurn);

      final token = currentPlayer.tokens.firstWhere((t) => t.id == tokenId);

      if (token.state == TokenState.finished) {
        action = GameAction.finish;
      }
    }

    _state = _state.copyWith(lastAction: action);

    _streamController.add(_state);
  }

  @override
  Future<void> moveToken(Token token) async {
    if (!_state.isDiceRolled || token.color != _state.currentTurn) return;

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
  }

  @override
  Future<void> dispose() async {
    await _streamController.close();
  }

  GameState _createInitialState(Map<PlayerColor, String> config) {
    List<Player> players = config.entries.map((e) {
      return Player(
        color: e.key,
        name: e.value,
        tokens: List.generate(4, (i) => Token(id: i, color: e.key)),
      );
    }).toList();

    return GameState(
      gameId: "local_${DateTime.now().millisecondsSinceEpoch}",
      players: players,
      turnOrder: config.keys.toList(),
      currentTurn: config.keys.first,
      lastAction: GameAction.none,
    );
  }
}
