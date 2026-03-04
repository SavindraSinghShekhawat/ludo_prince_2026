import 'dart:math';
import '../models/board_path.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';
import 'game_engine.dart';

class BotAI {
  static final GameEngine _engine = GameEngine();

  static Token? getBestMove(Player player, GameState state) {
    if (!state.isDiceRolled) return null;

    final dice = state.diceValue;
    final validTokens =
        player.tokens.where((t) => _engine.isValidMove(t, dice)).toList();

    if (validTokens.isEmpty) return null;
    if (validTokens.length == 1) return validTokens.first;

    Token? bestToken;
    int highestScore = -1;
    List<Token> ties = [];

    for (var token in validTokens) {
      int score = _evaluateMove(player, token, state, dice);
      if (score > highestScore) {
        highestScore = score;
        bestToken = token;
        ties = [token];
      } else if (score == highestScore) {
        ties.add(token);
      }
    }

    if (ties.isNotEmpty) {
      return ties[Random().nextInt(ties.length)];
    }

    return bestToken;
  }

  static int _evaluateMove(
      Player player, Token token, GameState state, int dice) {
    int score = 0;

    // Simulate move to evaluate tactical advantages
    int steps = dice;
    Token simulatedToken = token;

    if (simulatedToken.state == TokenState.home && steps == 6) {
      // Escaping base
      score += 300;
      simulatedToken = simulatedToken.copyWith(
        state: TokenState.board,
        position: 0,
      );
    } else {
      for (int i = 0; i < steps; i++) {
        simulatedToken = _engine.advanceOneStep(simulatedToken);
      }
    }

    if (simulatedToken.state == TokenState.finished) {
      score += 1000; // Priority 1: Win the token
    } else if (simulatedToken.state == TokenState.homeStretch) {
      score += 200; // Entering home stretch is good
    } else if (simulatedToken.state == TokenState.board) {
      // Check for capture
      if (!BoardPath.isSafeSpot(simulatedToken.position)) {
        int targetAbsPos = BoardPath.getAbsolutePosition(
            simulatedToken.slot, simulatedToken.position);

        bool wouldCapture = false;
        for (var opp in state.players) {
          if (opp.slot == player.slot) continue;
          for (var oppToken in opp.tokens) {
            if (oppToken.state == TokenState.board) {
              int oppAbsPos = BoardPath.getAbsolutePosition(
                  oppToken.slot, oppToken.position);
              if (oppAbsPos == targetAbsPos) {
                wouldCapture = true;
                break;
              }
            }
          }
          if (wouldCapture) break;
        }

        if (wouldCapture) {
          score += 500; // Capturing is highly prioritized
        }

        // Danger evaluation
        bool wasInDanger = _isTokenInDanger(token, state);
        bool willBeInDanger = _isTokenInDanger(simulatedToken, state);

        if (wasInDanger && !willBeInDanger) {
          score += 400; // Saved a piece!
        } else if (!wasInDanger && willBeInDanger && !wouldCapture) {
          score -= 200; // Moved into danger for no reason
        }
      } else {
        score += 100; // Landing on a safe spot
        bool wasInDanger = _isTokenInDanger(token, state);
        if (wasInDanger) score += 400; // Reached safety
      }
    } else if (simulatedToken.state == TokenState.homeStretch ||
        simulatedToken.state == TokenState.finished) {
      bool wasInDanger = _isTokenInDanger(token, state);
      if (wasInDanger) score += 400; // Escaped to home stretch
    }

    // Tie breaker: prefer moving tokens that are further ahead
    if (simulatedToken.state == TokenState.board ||
        simulatedToken.state == TokenState.homeStretch) {
      score += simulatedToken.position;
    }

    // Secondary tie breaker for 6s: if we can move a piece further instead of just escaping
    // when we already have pieces on the board, keep it balanced but let's stick to the current.

    return score;
  }

  static bool _isTokenInDanger(Token t, GameState state) {
    if (t.state != TokenState.board) return false;
    if (BoardPath.isSafeSpot(t.position)) return false;

    int absPos = BoardPath.getAbsolutePosition(t.slot, t.position);

    for (var opp in state.players) {
      if (opp.slot == t.slot) continue;
      for (var oppToken in opp.tokens) {
        if (oppToken.state == TokenState.board) {
          int oppAbsPos =
              BoardPath.getAbsolutePosition(oppToken.slot, oppToken.position);
          int dist = (absPos - oppAbsPos + 52) % 52;

          if (dist >= 1 && dist <= 6) {
            // Is the opponent actually able to reach us before they turn into home stretch?
            if (oppToken.position + dist <= 50) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }
}
