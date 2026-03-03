import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../models/token.dart';
import '../models/board_path.dart';
import '../services/audio_service.dart';

class GameState {
  final List<Player> players;
  final PlayerColor currentTurn;
  final int diceValue;
  final bool isDiceRolled;
  final int consecutiveSixes;
  final String message;

  GameState({
    required this.players,
    required this.currentTurn,
    this.diceValue = 1,
    this.isDiceRolled = false,
    this.consecutiveSixes = 0,
    this.message = "Game Started!",
  });

  GameState copyWith({
    List<Player>? players,
    PlayerColor? currentTurn,
    int? diceValue,
    bool? isDiceRolled,
    int? consecutiveSixes,
    String? message,
  }) {
    return GameState(
      players: players ?? this.players,
      currentTurn: currentTurn ?? this.currentTurn,
      diceValue: diceValue ?? this.diceValue,
      isDiceRolled: isDiceRolled ?? this.isDiceRolled,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      message: message ?? this.message,
    );
  }

  bool get isTwoPlayer => players.length == 2;
}

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return GameState(
      players: [],
      currentTurn: PlayerColor.blue,
    );
  }

  GameState _createInitialState(Map<PlayerColor, String>? playerConfig) {
    playerConfig ??= {
      PlayerColor.blue: "Player 1",
      PlayerColor.yellow: "Player 2",
      PlayerColor.green: "Player 3",
      PlayerColor.red: "Player 4",
    };

    List<Player> players = [];

    for (var entry in playerConfig.entries) {
      players.add(
        Player(
          color: entry.key,
          name: entry.value,
          tokens: List.generate(4, (i) => Token(id: i, color: entry.key)),
        ),
      );
    }

    return GameState(
      players: players,
      currentTurn: playerConfig.keys.first,
    );
  }

  Future<void> initializeGame({Map<PlayerColor, String>? playerConfig}) async {
    await audioService.playStart();
    state = _createInitialState(playerConfig);
  }

  Future<void> rollDice() async {
    if (state.isDiceRolled) return;

    final random = Random();
    final newDiceValue = random.nextInt(6) + 1;

    int newConsecutiveSixes = state.consecutiveSixes;

    if (newDiceValue == 6) {
      await audioService.playRoll(); // Always roll first
      await audioService.playSix(); // Then special six sound
      newConsecutiveSixes++;
    } else {
      await audioService.playRoll();
      newConsecutiveSixes = 0;
    }

    if (newConsecutiveSixes == 3) {
      _nextTurn("Rolled three 6s! Turn skipped.");
      return;
    }

    final currentPlayer = state.players.firstWhere((p) => p.color == state.currentTurn);

    final validTokens = currentPlayer.tokens.where((token) => _isValidMove(token, newDiceValue)).toList();

    state = state.copyWith(
      diceValue: newDiceValue,
      isDiceRolled: true,
      consecutiveSixes: newConsecutiveSixes,
      message: "${_getPlayerName(state.currentTurn)} rolled a $newDiceValue",
    );

    if (validTokens.isEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        _nextTurn("No valid moves. Next turn.");
      });
      return;
    }

    bool canAutoPlay = false;
    Token? tokenToAutoPlay;

    if (validTokens.length == 1) {
      canAutoPlay = true;
      tokenToAutoPlay = validTokens.first;
    } else {
      bool allIdentical = validTokens.every((t) => t.state == validTokens.first.state && t.position == validTokens.first.position);

      if (allIdentical && validTokens.first.state != TokenState.home) {
        canAutoPlay = true;
        tokenToAutoPlay = validTokens.first;
      }
    }

    if (canAutoPlay && tokenToAutoPlay != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        moveToken(tokenToAutoPlay!);
      });
    }
  }

  bool _isValidMove(Token token, int diceValue) {
    if (token.state == TokenState.home) return diceValue == 6;
    if (token.state == TokenState.finished) return false;
    if (token.state == TokenState.homeStretch) {
      return token.position + diceValue <= 57;
    }
    return true;
  }

  Future<void> moveToken(Token token) async {
    if (!state.isDiceRolled || token.color != state.currentTurn) return;

    if (!_isValidMove(token, state.diceValue)) return;

    int steps = state.diceValue;

    // 🔥 Home exit case
    if (token.state == TokenState.home && steps == 6) {
      await audioService.playMove(1);

      Token updatedToken = token.copyWith(state: TokenState.board, position: 0);

      _updateTokenOnly(updatedToken);

      _checkCapture(updatedToken);

      _finalizeMove(extraTurn: true);
      return;
    }

    // 🔥 Play dynamic move sound ONCE based on steps
    await audioService.playMove(steps);

    Token currentToken = token;

    for (int i = 1; i <= steps; i++) {
      currentToken = _calculateNewTokenPosition(currentToken, 1);

      _updateTokenOnly(currentToken);

      await Future.delayed(const Duration(milliseconds: 150));

      if (currentToken.state == TokenState.finished) {
        await audioService.playHome();
        break;
      }
    }

    bool captured = _checkCapture(currentToken);

    bool extraTurn = state.diceValue == 6 || captured || currentToken.state == TokenState.finished;

    if (currentToken.state == TokenState.board && BoardPath.isSafeSpot(currentToken.position) && !captured) {
      await audioService.playSafe();
    }

    _finalizeMove(extraTurn: extraTurn);
  }

  void _updateTokenOnly(Token updatedToken) {
    List<Player> updatedPlayers = List.of(state.players);
    int playerIndex = updatedPlayers.indexWhere((p) => p.color == updatedToken.color);
    var player = updatedPlayers[playerIndex];

    List<Token> newTokens = List.of(player.tokens);
    int tokenIndex = newTokens.indexWhere((t) => t.id == updatedToken.id);

    newTokens[tokenIndex] = updatedToken;

    updatedPlayers[playerIndex] = player.copyWith(tokens: newTokens);

    state = state.copyWith(players: updatedPlayers);
  }

  bool _checkCapture(Token updatedToken) {
    if (updatedToken.state != TokenState.board || BoardPath.isSafeSpot(updatedToken.position)) {
      return false;
    }

    bool captured = false;
    List<Player> updatedPlayers = List.of(state.players);

    int absPos = BoardPath.getAbsolutePosition(updatedToken.color, updatedToken.position);

    for (int i = 0; i < updatedPlayers.length; i++) {
      var p = updatedPlayers[i];
      if (p.color == updatedToken.color) continue;

      List<Token> newTokens = List.of(p.tokens);

      for (int j = 0; j < newTokens.length; j++) {
        var t = newTokens[j];

        if (t.state == TokenState.board) {
          int oppAbsPos = BoardPath.getAbsolutePosition(t.color, t.position);

          if (absPos == oppAbsPos) {
            audioService.playDie();
            newTokens[j] = t.copyWith(state: TokenState.home, position: -1);
            captured = true;
          }
        }
      }

      updatedPlayers[i] = p.copyWith(tokens: newTokens);
    }

    if (captured) {
      state = state.copyWith(players: updatedPlayers);
    }

    return captured;
  }

  void _finalizeMove({required bool extraTurn}) {
    state = state.copyWith(isDiceRolled: false);

    if (extraTurn) {
      state = state.copyWith(message: "${_getPlayerName(state.currentTurn)} gets an extra turn!");
    } else {
      _nextTurn("${_getPlayerName(state.currentTurn)}'s turn ended.");
    }
  }

  Token _calculateNewTokenPosition(Token token, int diceValue) {
    int newPos = token.position + diceValue;

    if (token.state == TokenState.board) {
      if (newPos > 51) {
        return token.copyWith(state: TokenState.homeStretch, position: newPos);
      }
      return token.copyWith(position: newPos);
    }

    if (token.state == TokenState.homeStretch) {
      if (newPos == 57) {
        return token.copyWith(state: TokenState.finished, position: newPos);
      }
      return token.copyWith(position: newPos);
    }

    return token;
  }

  void _nextTurn(String msg) {
    List<PlayerColor> order = state.players.map((p) => p.color).toList();

    int currentIdx = order.indexOf(state.currentTurn);
    currentIdx = (currentIdx + 1) % order.length;

    state = state.copyWith(
      currentTurn: order[currentIdx],
      isDiceRolled: false,
      consecutiveSixes: 0,
      message: msg,
    );
  }

  String _getPlayerName(PlayerColor color) {
    return state.players.firstWhere((p) => p.color == color).name;
  }
}

final gameStateProvider = NotifierProvider<GameStateNotifier, GameState>(() => GameStateNotifier());
