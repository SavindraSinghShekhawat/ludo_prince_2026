import 'dart:math';
import '../models/board_path.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';
import 'game_engine.dart';

class BotAI {
  static final GameEngine _engine = GameEngine();
  static final Random _random = Random();

  static Token? getBestMove(Player player, GameState state) {
    if (!state.isDiceRolled) return null;

    final dice = state.diceValue;

    final validTokens =
        player.tokens.where((t) => _engine.isValidMove(t, dice)).toList();

    if (validTokens.isEmpty) return null;
    if (validTokens.length == 1) return validTokens.first;

    Token bestToken = validTokens.first;
    int highestScore = _evaluateMove(player, validTokens.first, state, dice);
    List<Token> ties = [validTokens.first];

    for (int i = 1; i < validTokens.length; i++) {
      final token = validTokens[i];
      int score = _evaluateMove(player, token, state, dice);

      if (score > highestScore) {
        highestScore = score;
        bestToken = token;
        ties = [token];
      } else if (score == highestScore) {
        ties.add(token);
      }
    }

    if (ties.length > 1) {
      ties.sort((a, b) => _tokenProgress(b).compareTo(_tokenProgress(a)));
      return ties.first;
    }

    return bestToken;
  }

  static int _evaluateMove(
      Player player, Token token, GameState state, int dice) {
    int score = 0;

    int steps = dice;
    Token simulatedToken = token;

    // Opening strategy
    bool anyOnBoard = player.tokens.any((t) => t.state == TokenState.board);
    if (!anyOnBoard && dice == 6) {
      score += 1000;
    }

    // Escape base
    if (simulatedToken.state == TokenState.home && steps == 6) {
      score += 600;
      simulatedToken = simulatedToken.copyWith(
        state: TokenState.board,
        position: 0,
      );
    } else {
      for (int i = 0; i < steps; i++) {
        simulatedToken = _engine.advanceOneStep(simulatedToken);
      }
    }

    // Finish token
    if (simulatedToken.state == TokenState.finished) {
      score += 4000;
      return score;
    }

    // Home stretch bonus
    if (simulatedToken.state == TokenState.homeStretch) {
      score += 500;
    }

    if (simulatedToken.state == TokenState.board) {
      int targetAbsPos = BoardPath.getAbsolutePosition(
          simulatedToken.slot, simulatedToken.position);

      // Capture evaluation
      int capturedPos = -1;
      for (var opp in state.players) {
        if (opp.slot == player.slot) continue;

        for (var oppToken in opp.tokens) {
          if (oppToken.state == TokenState.board) {
            int oppAbsPos =
                BoardPath.getAbsolutePosition(oppToken.slot, oppToken.position);

            if (oppAbsPos == targetAbsPos &&
                !BoardPath.isSafeSpot(simulatedToken.position)) {
              capturedPos = max(capturedPos, oppToken.position);
            }
          }
        }
      }

      if (capturedPos != -1) {
        score += 5000 + (capturedPos * 15);
      }

      // Safe spot bonus
      if (BoardPath.isSafeSpot(simulatedToken.position)) {
        score += 350;
      }

      // Don't leave safe spot unnecessarily
      if (BoardPath.isSafeSpot(token.position) &&
          !BoardPath.isSafeSpot(simulatedToken.position)) {
        score -= 250;
      }

      // Block formation
      bool formsBlock = false;
      for (var myToken in player.tokens) {
        if (myToken == token) continue;
        if (myToken.state == TokenState.board) {
          int abs =
              BoardPath.getAbsolutePosition(myToken.slot, myToken.position);

          if (abs == targetAbsPos) {
            formsBlock = true;
            break;
          }
        }
      }

      if (formsBlock) {
        score += 900;

        if (simulatedToken.position >= 20 && simulatedToken.position <= 35) {
          score += 300;
        }
      }

      // Danger evaluation
      int attackersBefore = _countAttackersInRange(token, state);
      int attackersAfter = _countAttackersInRange(simulatedToken, state);

      if (attackersBefore > 0) {
        score += 3800;

        if (attackersAfter == 0) {
          score += 500;
        }
      } else if (attackersAfter > attackersBefore) {
        score -= 160 * (attackersAfter - attackersBefore);
      }

      // Offensive evaluation
      int targets = _countTargetsInRange(simulatedToken, state);
      score += 140 * targets;

      // Avoid token clumping
      int nearbyFriends = 0;

      for (var t in player.tokens) {
        if (t == token) continue;

        if (t.state == TokenState.board) {
          if ((t.position - simulatedToken.position).abs() <= 3) {
            nearbyFriends++;
          }
        }
      }

      score -= nearbyFriends * 120;

      // Late game push
      if (simulatedToken.position >= 45) {
        score += 800;
      }

      // Forward progress
      score += simulatedToken.position * 3;
    }

    // Avoid moving home stretch token unnecessarily
    if (token.state == TokenState.homeStretch) {
      score -= 300;
    }

    // Aggressive mode when winning
    int finishedCount =
        player.tokens.where((t) => t.state == TokenState.finished).length;

    if (finishedCount >= 2) {
      score += 200;
    }

    return score;
  }

  static int _countAttackersInRange(Token t, GameState state, {int range = 6}) {
    if (t.state != TokenState.board) return 0;
    if (BoardPath.isSafeSpot(t.position)) return 0;

    int absPos = BoardPath.getAbsolutePosition(t.slot, t.position);
    int attackers = 0;

    for (var opp in state.players) {
      if (opp.slot == t.slot) continue;

      for (var oppToken in opp.tokens) {
        if (oppToken.state == TokenState.board) {
          int oppAbsPos =
              BoardPath.getAbsolutePosition(oppToken.slot, oppToken.position);

          int dist = (absPos - oppAbsPos + 52) % 52;

          if (dist >= 1 && dist <= range) {
            if (oppToken.position + dist <= 50) {
              attackers++;
            }
          }
        }
      }
    }

    return attackers;
  }

  static int _countTargetsInRange(Token t, GameState state) {
    if (t.state != TokenState.board) return 0;

    int absPos = BoardPath.getAbsolutePosition(t.slot, t.position);
    int targets = 0;

    for (var opp in state.players) {
      if (opp.slot == t.slot) continue;

      for (var oppToken in opp.tokens) {
        if (oppToken.state == TokenState.board) {
          int oppAbsPos =
              BoardPath.getAbsolutePosition(oppToken.slot, oppToken.position);

          int dist = (oppAbsPos - absPos + 52) % 52;

          if (dist >= 1 && dist <= 6) {
            if (t.position + dist <= 50 &&
                !BoardPath.isSafeSpot(oppToken.position)) {
              targets++;
            }
          }
        }
      }
    }

    return targets;
  }

  static int _tokenProgress(Token t) {
    if (t.state == TokenState.finished) return 10000;
    if (t.state == TokenState.homeStretch) return 800 + t.position;
    if (t.state == TokenState.board) return 500 + t.position;
    return 0;
  }
}
