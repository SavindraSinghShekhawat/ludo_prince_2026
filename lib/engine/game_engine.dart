import '../models/game_state.dart';
import '../models/token.dart';
import '../models/player.dart';
import '../models/board_path.dart';

class GameEngine {
  GameState rollDice(GameState state, int diceValue) {
    if (state.isDiceRolled) return state;

    int newConsecutive = diceValue == 6 ? state.consecutiveSixes + 1 : 0;

    if (newConsecutive == 3) {
      return _nextTurn(
        state.copyWith(consecutiveSixes: 0),
        "Rolled three 6s! Turn skipped.",
      );
    }

    final player = _getPlayer(state, state.currentTurn);

    final validTokens = player.tokens.where((t) => isValidMove(t, diceValue)).toList();

    if (validTokens.isEmpty) {
      return _nextTurn(
        state.copyWith(consecutiveSixes: newConsecutive),
        "No valid moves. Turn skipped.",
      );
    }

    return state.copyWith(
      diceValue: diceValue,
      isDiceRolled: true,
      consecutiveSixes: newConsecutive,
      message: "${player.name} rolled a $diceValue",
    );
  }

  GameState moveToken(GameState state, int tokenId) {
    if (!state.isDiceRolled) return state;

    final player = _getPlayer(state, state.currentTurn);

    final token = player.tokens.firstWhere((t) => t.id == tokenId);

    bool extraTurn = state.diceValue == 6 || token.state == TokenState.finished;

    GameState newState = state.copyWith(
      isDiceRolled: false,
    );

    return extraTurn
        ? newState.copyWith(
            message: "${player.name} gets an extra turn!",
          )
        : _nextTurn(
            newState,
            "${player.name}'s turn ended.",
          );
  }

  bool isValidMove(Token token, int dice) {
    if (token.state == TokenState.home) {
      return dice == 6;
    }
    if (token.state == TokenState.finished) {
      return false;
    }
    if (token.state == TokenState.homeStretch) {
      return token.position + dice <= 57;
    }
    return true;
  }

  Token advanceOneStep(Token token) {
    int newPos = token.position + 1;

    if (token.state == TokenState.board) {
      if (newPos > 51) {
        return token.copyWith(
          state: TokenState.homeStretch,
          position: newPos,
        );
      }
      return token.copyWith(position: newPos);
    }

    if (token.state == TokenState.homeStretch) {
      if (newPos == 57) {
        return token.copyWith(
          state: TokenState.finished,
          position: newPos,
        );
      }
      return token.copyWith(position: newPos);
    }

    return token;
  }

  GameState applyStep(GameState state, Token updatedToken, {required Function(bool captured) onCapture}) {
    List<Player> players = _replaceToken(state.players, updatedToken);

    bool captured = false;

    if (updatedToken.state == TokenState.board && !BoardPath.isSafeSpot(updatedToken.position)) {
      int absPos = BoardPath.getAbsolutePosition(updatedToken.color, updatedToken.position);

      players = players.map((p) {
        if (p.color == updatedToken.color) return p;

        return p.copyWith(
          tokens: p.tokens.map((t) {
            if (t.state != TokenState.board) return t;

            int oppAbs = BoardPath.getAbsolutePosition(t.color, t.position);

            if (oppAbs == absPos) {
              captured = true;
              return t.copyWith(state: TokenState.home, position: -1);
            }

            return t;
          }).toList(),
        );
      }).toList();
    }

    onCapture(captured);

    return state.copyWith(players: players);
  }

  GameState _nextTurn(GameState state, String msg) {
    final order = state.players.map((e) => e.color).toList();

    int idx = order.indexOf(state.currentTurn);
    idx = (idx + 1) % order.length;

    return state.copyWith(
      currentTurn: order[idx],
      isDiceRolled: false,
      consecutiveSixes: 0,
      message: msg,
    );
  }

  Player _getPlayer(GameState state, PlayerColor color) {
    return state.players.firstWhere((p) => p.color == color);
  }

  List<Player> _replaceToken(List<Player> players, Token updated) {
    return players.map((p) {
      if (p.color != updated.color) return p;

      return p.copyWith(
        tokens: p.tokens.map((t) {
          return t.id == updated.id ? updated : t;
        }).toList(),
      );
    }).toList();
  }
}
