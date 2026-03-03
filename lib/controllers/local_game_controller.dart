import 'dart:async';
import 'dart:math';
import 'package:ludo_prince/models/board_path.dart';

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

  @override
  Future<void> rollDice() async {
    final dice = Random().nextInt(6) + 1;

    await audioService.playRoll();
    if (dice == 6) {
      await audioService.playSix();
    }

    _state = _engine.rollDice(_state, dice);
    _streamController.add(_state);

    if (_state.isDiceRolled) {
      final player = _state.players.firstWhere((p) => p.color == _state.currentTurn);

      final validTokens = player.tokens.where((t) => _engine.isValidMove(t, _state.diceValue)).toList();

      if (validTokens.length == 1) {
        await Future.delayed(const Duration(milliseconds: 300));
        await moveToken(validTokens.first);
      }
    }
  }

  void _finalizeAfterMove(Token token, bool captured) {
    bool extraTurn = _state.diceValue == 6 || captured || token.state == TokenState.finished;

    _state = _engine.moveToken(_state, token.id);

    if (extraTurn) {
      _state = _state.copyWith(message: "${_state.players.firstWhere((p) => p.color == _state.currentTurn).name} gets an extra turn!");
    }

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

      Token updated = token.copyWith(state: TokenState.board, position: 0);

      _state = _engine.applyStep(
        _state,
        updated,
        onCapture: (c) => captured = c,
      );

      _streamController.add(_state);

      if (captured) {
        await audioService.playDie();
      } else {
        await audioService.playSafe();
      }

      _finalizeAfterMove(token, captured);
      return;
    }

    await audioService.playMove(steps);

    Token currentToken = token;

    for (int i = 0; i < steps; i++) {
      currentToken = _engine.advanceOneStep(currentToken);

      _state = _engine.applyStep(
        _state,
        currentToken,
        onCapture: (c) {
          if (c) captured = true;
        },
      );

      _streamController.add(_state);

      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (currentToken.state == TokenState.finished) {
      await audioService.playHome();
    }

    if (captured) {
      await audioService.playDie();
    } else if (currentToken.state == TokenState.board && BoardPath.isSafeSpot(currentToken.position)) {
      await audioService.playSafe();
    }

    _finalizeAfterMove(currentToken, captured);
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
      players: players,
      currentTurn: config.keys.first,
    );
  }
}
