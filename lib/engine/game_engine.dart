import '../models/game_state.dart';
import '../models/token.dart';
import '../models/player.dart';
import '../models/board_path.dart';

enum EngineEvent {
  capture,
  finish,
  safeSpot,
  diceRoll,
  rolledSix,
  tokenExitedBase,
  extraTurn,
  turnSkipped,
}

class EngineResult {
  final GameState state;
  final List<EngineEvent> events;

  EngineResult(this.state, [this.events = const []]);
}

class GameEngine {
  EngineResult rollDice(GameState state, int diceValue) {
    if (state.isDiceRolled) return EngineResult(state);

    List<EngineEvent> events = [EngineEvent.diceRoll];
    if (diceValue == 6) events.add(EngineEvent.rolledSix);

    int newConsecutive = diceValue == 6 ? state.consecutiveSixes + 1 : 0;

    if (newConsecutive == 3) {
      final skipResult = _nextTurn(
        state.copyWith(consecutiveSixes: 0, diceValue: diceValue),
        "Rolled three 6s! Turn skipped.",
      );
      return EngineResult(
        skipResult.state,
        [...events, EngineEvent.turnSkipped, ...skipResult.events],
      );
    }

    final player = _getPlayer(state, state.currentTurn);

    final validTokens =
        player.tokens.where((t) => isValidMove(t, diceValue)).toList();

    if (validTokens.isEmpty) {
      final skipResult = _nextTurn(
        state.copyWith(consecutiveSixes: newConsecutive, diceValue: diceValue),
        "No valid moves. Turn skipped.",
      );
      return EngineResult(
        skipResult.state,
        [...events, EngineEvent.turnSkipped, ...skipResult.events],
      );
    }

    return EngineResult(
      state.copyWith(
        diceValue: diceValue,
        isDiceRolled: true,
        consecutiveSixes: newConsecutive,
        message: "${player.name} rolled a $diceValue",
      ),
      events,
    );
  }

  EngineResult moveToken(GameState state, int tokenId,
      {bool captured = false}) {
    if (!state.isDiceRolled) return EngineResult(state);

    final player = _getPlayer(state, state.currentTurn);
    final token = player.tokens.firstWhere((t) => t.id == tokenId);

    if (token.slot != state.currentTurn) {
      return EngineResult(state); // ❗ prevent illegal multiplayer move
    }

    List<EngineEvent> events = [];
    bool isSix = state.diceValue == 6;
    bool isFinished = token.state == TokenState.finished;

    bool extraTurn = isSix || isFinished || captured;
    if (extraTurn) events.add(EngineEvent.extraTurn);

    GameState newState = state.copyWith(
      isDiceRolled: false,
    );

    bool hasWon = player.tokens.every((t) => t.state == TokenState.finished);
    if (hasWon && !newState.winners.contains(player.slot)) {
      var newWinners = [...newState.winners, player.slot];
      if (newWinners.length == newState.players.length - 1) {
        final lastPlayer =
            newState.players.firstWhere((p) => !newWinners.contains(p.slot));
        newWinners.add(lastPlayer.slot);
      }
      newState = newState.copyWith(winners: newWinners);
    }

    if (extraTurn && !hasWon) {
      return EngineResult(
        newState.copyWith(
          message: "${player.name} gets an extra turn!",
        ),
        events,
      );
    } else {
      final nextResult = _nextTurn(
        newState,
        "${player.name}'s turn ended.",
      );
      return EngineResult(
        nextResult.state,
        [...events, ...nextResult.events],
      );
    }
  }

  bool isValidMove(Token token, int dice) {
    if (token.state == TokenState.home) {
      return dice == 6;
    }
    if (token.state == TokenState.finished) {
      return false;
    }
    return token.position + dice <= 56;
  }

  Token advanceOneStep(Token token) {
    int newPos = token.position + 1;

    if (token.state == TokenState.board) {
      if (newPos > 50) {
        return token.copyWith(
          state: TokenState.homeStretch,
          position: newPos,
        );
      }
      return token.copyWith(position: newPos);
    }

    if (token.state == TokenState.homeStretch) {
      if (newPos == 56) {
        return token.copyWith(
          state: TokenState.finished,
          position: newPos,
        );
      }
      return token.copyWith(position: newPos);
    }

    return token;
  }

  EngineResult applyStep(
    GameState state,
    Token updatedToken, {
    bool allowCapture = true,
  }) {
    List<Player> players = _replaceToken(state.players, updatedToken);
    List<EngineEvent> events = [];

    // Check if token exited base (was home, now board at position 0)
    final oldToken = _getPlayer(state, updatedToken.slot)
        .tokens
        .firstWhere((t) => t.id == updatedToken.id);
    if (oldToken.state == TokenState.home &&
        updatedToken.state == TokenState.board) {
      events.add(EngineEvent.tokenExitedBase);
    }

    if (updatedToken.state == TokenState.finished) {
      events.add(EngineEvent.finish);
    } else if (updatedToken.state == TokenState.board &&
        BoardPath.isSafeSpot(updatedToken.position) &&
        allowCapture) {
      events.add(EngineEvent.safeSpot);
    }

    if (allowCapture &&
        updatedToken.state == TokenState.board &&
        !BoardPath.isSafeSpot(updatedToken.position)) {
      int absPos = BoardPath.getAbsolutePosition(
          updatedToken.slot, updatedToken.position);

      players = players.map((p) {
        if (p.slot == updatedToken.slot) return p;

        return p.copyWith(
          tokens: p.tokens.map((t) {
            if (t.state != TokenState.board) return t;

            int oppAbs = BoardPath.getAbsolutePosition(t.slot, t.position);

            if (oppAbs == absPos) {
              events.add(EngineEvent.capture);
              return t.copyWith(state: TokenState.home, position: -1);
            }

            return t;
          }).toList(),
        );
      }).toList();
    }

    return EngineResult(state.copyWith(players: players), events);
  }

  EngineResult _nextTurn(GameState state, String msg) {
    if (state.isGameOver) {
      return EngineResult(state.copyWith(message: "Game Over!"));
    }

    final order = state.turnOrder; // ✅ stable order

    int idx = order.indexOf(state.currentTurn);
    for (int i = 0; i < order.length; i++) {
      idx = (idx + 1) % order.length;
      if (!state.winners.contains(order[idx])) {
        break;
      }
    }

    return EngineResult(
      state.copyWith(
        currentTurn: order[idx],
        isDiceRolled: false,
        consecutiveSixes: 0,
        message: msg,
      ),
    );
  }

  Player _getPlayer(GameState state, PlayerSlot slot) {
    return state.players.firstWhere((p) => p.slot == slot);
  }

  List<Player> _replaceToken(List<Player> players, Token updated) {
    return players.map((p) {
      if (p.slot != updated.slot) return p;

      return p.copyWith(
        tokens: p.tokens.map((t) {
          return t.id == updated.id ? updated : t;
        }).toList(),
      );
    }).toList();
  }
}
