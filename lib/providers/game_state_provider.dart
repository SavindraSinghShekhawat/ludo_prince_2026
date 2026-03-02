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
  final int consecutiveSixes; // After 3 sixes, turn skips
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
    return _createInitialState(null); // Default 4 players
  }

  GameState _createInitialState(Map<PlayerColor, String>? playerConfig) {
    if (playerConfig == null || playerConfig.isEmpty) {
      playerConfig = {
        PlayerColor.blue: "Player 1",
        PlayerColor.yellow: "Player 2",
        PlayerColor.green: "Player 3",
        PlayerColor.red: "Player 4",
      };
    }
    
    List<Player> players = [];
    PlayerColor startTurn = playerConfig.containsKey(PlayerColor.blue) 
        ? PlayerColor.blue 
        : playerConfig.keys.first;

    for (var entry in playerConfig.entries) {
      players.add(
        Player(
          color: entry.key,
          name: entry.value,
          tokens: List.generate(4, (i) => Token(id: i, color: entry.key)),
        )
      );
    }

    return GameState(
      players: players,
      currentTurn: startTurn,
    );
  }

  void initializeGame({Map<PlayerColor, String>? playerConfig}) {
    audioService.playStart();
    state = _createInitialState(playerConfig);
  }

  void rollDice() {
    if (state.isDiceRolled) return;

    final random = Random();
    final newDiceValue = random.nextInt(6) + 1;
    
    int newConsecutiveSixes = state.consecutiveSixes;
    if (newDiceValue == 6) {
      audioService.playSix();
      newConsecutiveSixes++;
    } else {
      audioService.playRoll();
      newConsecutiveSixes = 0;
    }

    if (newConsecutiveSixes == 3) {
      // Rule: 3 consecutive sixes skips the turn
      _nextTurn("Rolled three 6s! Turn skipped.");
      return;
    }

    // Check if player has any valid moves
    final currentPlayer = state.players.firstWhere((p) => p.color == state.currentTurn);
    final validTokens = currentPlayer.tokens.where((token) => _isValidMove(token, newDiceValue)).toList();

    if (validTokens.isEmpty) {
      // Auto skip turn if no valid moves exist
      state = state.copyWith(
        diceValue: newDiceValue,
        isDiceRolled: true,
        consecutiveSixes: newConsecutiveSixes,
      );
      Future.delayed(const Duration(milliseconds: 400), () {
        _nextTurn("No valid moves. Next turn.");
      });
      return;
    }

    state = state.copyWith(
      diceValue: newDiceValue,
      isDiceRolled: true,
      consecutiveSixes: newConsecutiveSixes,
      message: "${_getPlayerName(state.currentTurn)} rolled a $newDiceValue",
    );

    // === AUTO-PLAY RULES ===
    // We automatically play a token for the user ONLY if:
    // Rule 1. There is EXACTLY 1 legally valid token that can move with this dice roll.
    // Rule 2. There are multiple valid tokens that are identical (stacked on the same cell), AND they are NOT in the home base.
    // This gives the player the satisfaction of manually picking a token to deploy from base on a 6.

    bool canAutoPlay = false;
    Token? tokenToAutoPlay;

    if (validTokens.length == 1) {
      canAutoPlay = true;
      tokenToAutoPlay = validTokens.first;
    } else if (validTokens.length > 1) {
      bool allIdentical = validTokens.every((t) => 
        t.state == validTokens.first.state && 
        t.position == validTokens.first.position
      );
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
    if (token.state == TokenState.home) {
      return diceValue == 6; // Needs a 6 to come out
    }
    if (token.state == TokenState.finished) {
      return false;
    }
    if (token.state == TokenState.homeStretch) {
      return token.position + diceValue <= 57; // Exact roll needed to finish
    }
    return true; // Can move on board
  }

  Future<void> moveToken(Token token) async {
    if (!state.isDiceRolled || token.color != state.currentTurn) return;
    if (!_isValidMove(token, state.diceValue)) return;

    int steps = state.diceValue;
    
    if (token.state == TokenState.home && steps == 6) {
      audioService.playMove(1);
      Token updatedToken = token.copyWith(state: TokenState.board, position: 0);
      _updateTokenOnly(updatedToken);
      _checkCapture(updatedToken); // We don't need its return value here since extraTurn is true anyway
      _finalizeMove(extraTurn: true);
      return;
    }

    Token currentToken = token;

    // Trigger the dynamic move sound once based on steps
    audioService.playMove(steps);

    for (int i = 1; i <= steps; i++) {
      currentToken = _calculateNewTokenPosition(currentToken, 1);
      
      if (currentToken.state == TokenState.finished) {
        audioService.playHome();
      }

      _updateTokenOnly(currentToken);
      await Future.delayed(const Duration(milliseconds: 150));
      if (currentToken.state == TokenState.finished) break;
    }

    bool captured = _checkCapture(currentToken);
    bool extraTurn = state.diceValue == 6 || captured || currentToken.state == TokenState.finished;

    // Check if we arrived at a safe spot, but didn't finish or capture
    if (currentToken.state == TokenState.board && BoardPath.isSafeSpot(currentToken.position) && !captured) {
      // Overwrite the generic move sound with the safe spot sound
      audioService.playSafe();
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
      bool playerCaptured = false;
      
      for (int j = 0; j < newTokens.length; j++) {
        var t = newTokens[j];
        if (t.state == TokenState.board) {
          int oppAbsPos = BoardPath.getAbsolutePosition(t.color, t.position);
          if (absPos == oppAbsPos) {
            audioService.playDie();
            newTokens[j] = t.copyWith(state: TokenState.home, position: -1);
            captured = true;
            playerCaptured = true;
          }
        }
      }
      
      if (playerCaptured) {
        updatedPlayers[i] = p.copyWith(tokens: newTokens);
      }
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
    if (token.state == TokenState.home && diceValue == 6) {
      return token.copyWith(state: TokenState.board, position: 0); // Out on start square
    }

    int newPos = token.position + diceValue;
    
    if (token.state == TokenState.board) {
      if (newPos > 51) {
        // Entering home stretch
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
    if (order.isEmpty) return;
    
    int currentIdx = order.indexOf(state.currentTurn);
    PlayerColor nextColor;
    
    // Find next active player who hasn't finished
    int checkedCount = 0;
    do {
      currentIdx = (currentIdx + 1) % order.length;
      nextColor = order[currentIdx];
      checkedCount++;
    } while (state.players.firstWhere((p) => p.color == nextColor).hasFinished && checkedCount < order.length);

    state = state.copyWith(
      currentTurn: nextColor,
      isDiceRolled: false,
      consecutiveSixes: 0,
      message: msg,
    );
  }

  String _getPlayerName(PlayerColor color) {
    return state.players.firstWhere((p) => p.color == color).name;
  }
}

final gameStateProvider = NotifierProvider<GameStateNotifier, GameState>(() {
  return GameStateNotifier();
});
