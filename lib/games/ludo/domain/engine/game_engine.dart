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
  quit,
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
      return EngineResult(skipResult.state, [
        ...events,
        EngineEvent.turnSkipped,
        ...skipResult.events,
      ]);
    }

    final player = _getPlayer(state, state.currentTurn);

    // Reset skip count and update sixPity on successful roll
    final updatedPlayers = state.players.map((p) {
      if (p.slot == state.currentTurn) {
        return p.copyWith(
          skipCount: 0,
          sixPity: diceValue == 6 ? 0 : p.sixPity + 1,
        );
      }
      return p;
    }).toList();

    final validTokens =
        player.tokens.where((t) => isValidMove(t, diceValue)).toList();

    if (validTokens.isEmpty) {
      final skipResult = _nextTurn(
        state.copyWith(
          players: updatedPlayers,
          consecutiveSixes: newConsecutive,
          diceValue: diceValue,
        ),
        "No valid moves. Turn skipped.",
      );
      return EngineResult(skipResult.state, [
        ...events,
        EngineEvent.turnSkipped,
        ...skipResult.events,
      ]);
    }

    return EngineResult(
      state.copyWith(
        players: updatedPlayers,
        diceValue: diceValue,
        isDiceRolled: true,
        consecutiveSixes: newConsecutive,
        message: "${player.name} rolled a $diceValue",
      ),
      events,
    );
  }

  EngineResult moveToken(
    GameState state,
    int tokenId, {
    bool captured = false,
  }) {
    if (!state.isDiceRolled) return EngineResult(state);

    final player = _getPlayer(state, state.currentTurn);
    final token = player.tokens.firstWhere((t) => t.id == tokenId);

    if (token.slot != state.currentTurn) {
      return EngineResult(state); // ❗ prevent illegal multiplayer move
    }

    // Reset skip count on successful move
    final updatedPlayers = state.players.map((p) {
      if (p.slot == state.currentTurn) {
        return p.copyWith(skipCount: 0);
      }
      return p;
    }).toList();

    List<EngineEvent> events = [];
    bool isSix = state.diceValue == 6;
    bool isFinished = token.state == TokenState.finished;

    bool extraTurn = isSix || isFinished || captured;
    if (extraTurn) events.add(EngineEvent.extraTurn);

    GameState newState = state.copyWith(
      players: updatedPlayers,
      isDiceRolled: false,
    );

    bool hasWon = _checkWinner(newState, player.slot);
    if (hasWon && !newState.winners.contains(player.slot)) {
      var newWinners = [...newState.winners];
      if (newState.gameMode == GameMode.team) {
        // Add both teammates
        PlayerSlot teammate = _getTeammate(player.slot);
        if (!newWinners.contains(player.slot)) newWinners.add(player.slot);
        if (!newWinners.contains(teammate)) newWinners.add(teammate);

        // Add opposing team to trigger isGameOver immediately
        for (var p in newState.players) {
          if (!newWinners.contains(p.slot)) {
            newWinners.add(p.slot);
          }
        }
      } else {
        newWinners.add(player.slot);
      }

      if (newWinners.length == newState.players.length - 1 &&
          newState.gameMode == GameMode.classic) {
        final lastPlayer = newState.players.firstWhere(
          (p) => !newWinners.contains(p.slot),
        );
        newWinners.add(lastPlayer.slot);
      }
      newState = newState.copyWith(winners: newWinners);
    }

    if (extraTurn && !hasWon) {
      return EngineResult(
        newState.copyWith(message: "${player.name} gets an extra turn!"),
        events,
      );
    } else {
      final nextResult = _nextTurn(newState, "${player.name}'s turn ended.");
      return EngineResult(nextResult.state, [...events, ...nextResult.events]);
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
        return token.copyWith(state: TokenState.homeStretch, position: newPos);
      }
      return token.copyWith(position: newPos);
    }

    if (token.state == TokenState.homeStretch) {
      if (newPos == 56) {
        return token.copyWith(state: TokenState.finished, position: newPos);
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
    final oldToken = _getPlayer(
      state,
      updatedToken.slot,
    ).tokens.firstWhere((t) => t.id == updatedToken.id);
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
        updatedToken.slot,
        updatedToken.position,
      );

      players = players.map((p) {
        if (p.slot == updatedToken.slot) return p;

        // Team Mode capture prevention
        if (state.gameMode == GameMode.team) {
          bool isTeammate = (updatedToken.slot == PlayerSlot.slot1 &&
                  p.slot == PlayerSlot.slot3) ||
              (updatedToken.slot == PlayerSlot.slot3 &&
                  p.slot == PlayerSlot.slot1) ||
              (updatedToken.slot == PlayerSlot.slot2 &&
                  p.slot == PlayerSlot.slot4) ||
              (updatedToken.slot == PlayerSlot.slot4 &&
                  p.slot == PlayerSlot.slot2);
          if (isTeammate) return p;
        }

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

  EngineResult skipTurn(GameState state) {
    final player = _getPlayer(state, state.currentTurn);
    final newSkipCount = player.skipCount + 1;

    if (newSkipCount >= 5) {
      return quitPlayer(state, state.currentTurn);
    }

    final updatedPlayers = state.players.map((p) {
      if (p.slot == state.currentTurn) {
        return p.copyWith(skipCount: newSkipCount);
      }
      return p;
    }).toList();

    String msg = "${player.name} skipped turn ($newSkipCount/5)";
    return _nextTurn(state.copyWith(players: updatedPlayers), msg);
  }

  EngineResult _nextTurn(GameState state, String msg) {
    if (state.isGameOver) {
      return EngineResult(state.copyWith(message: "Game Over!"));
    }

    final order = state.turnOrder; // ✅ stable order

    int idx = order.indexOf(state.currentTurn);
    for (int i = 0; i < order.length; i++) {
      idx = (idx + 1) % order.length;
      PlayerSlot nextSlot = order[idx];

      // Skip if winner
      if (state.winners.contains(nextSlot)) continue;

      // Skip if finished all tokens (Team mode rule: finished player is skipped)
      final p = _getPlayer(state, nextSlot);
      if (p.tokens.every((t) => t.state == TokenState.finished)) continue;

      // Skip left players
      if (p.status == PlayerStatus.left) continue;

      break;
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

  EngineResult quitPlayer(GameState state, PlayerSlot slot) {
    if (state.winners.contains(slot)) return EngineResult(state);

    // Mark player as left
    final players = state.players.map((p) {
      if (p.slot == slot) {
        return p.copyWith(status: PlayerStatus.left);
      }
      return p;
    }).toList();

    GameState newState = state.copyWith(players: players);

    // If it was their turn, move to next turn
    if (newState.currentTurn == slot) {
      final nextResult = _nextTurn(newState, "${slot.name} left the game.");
      newState = nextResult.state;
    }

    // Check if game should end because only one team/player remains
    final activePlayers = newState.players
        .where(
          (p) =>
              p.status == PlayerStatus.active &&
              !newState.winners.contains(p.slot),
        )
        .toList();

    if (activePlayers.length == 1 && newState.gameMode == GameMode.classic) {
      // Last person wins
      final winner = activePlayers.first;
      final newWinners = [...newState.winners, winner.slot];

      // Add all quitters/others to winners list to trigger isGameOver
      for (var p in newState.players) {
        if (!newWinners.contains(p.slot)) {
          newWinners.add(p.slot);
        }
      }

      newState = newState.copyWith(
        winners: newWinners,
        message: "${winner.name} wins by forfeit!",
      );
    } else if (newState.gameMode == GameMode.team) {
      // Rule: If any player leaves, their team loses and the other team wins.
      final quitterTeam =
          (slot == PlayerSlot.slot1 || slot == PlayerSlot.slot3) ? "A" : "B";
      final winningTeam = quitterTeam == "A" ? "B" : "A";

      final teamASlots = [PlayerSlot.slot1, PlayerSlot.slot3];
      final teamBSlots = [PlayerSlot.slot2, PlayerSlot.slot4];
      final winningSlots = winningTeam == "A" ? teamASlots : teamBSlots;

      final newWinners = [...newState.winners];
      for (var s in winningSlots) {
        if (!newWinners.contains(s)) newWinners.add(s);
      }
      // Add all other players to winners list to trigger isGameOver
      for (var p in newState.players) {
        if (!newWinners.contains(p.slot)) {
          newWinners.add(p.slot);
        }
      }

      newState = newState.copyWith(
        winners: newWinners,
        message: "Team $quitterTeam members left. Team $winningTeam wins!",
      );
    }

    return EngineResult(newState, [EngineEvent.quit]);
  }

  static bool _checkWinner(GameState state, PlayerSlot slot) {
    if (state.gameMode == GameMode.team) {
      // In team mode, both players in the team must finish
      PlayerSlot teammate = _getTeammate(slot);

      return state.players
              .firstWhere((p) => p.slot == slot)
              .tokens
              .every((t) => t.state == TokenState.finished) &&
          state.players
              .firstWhere((p) => p.slot == teammate)
              .tokens
              .every((t) => t.state == TokenState.finished);
    }
    return state.players
        .firstWhere((p) => p.slot == slot)
        .tokens
        .every((t) => t.state == TokenState.finished);
  }

  static PlayerSlot _getTeammate(PlayerSlot slot) {
    return (slot == PlayerSlot.slot1)
        ? PlayerSlot.slot3
        : (slot == PlayerSlot.slot3)
            ? PlayerSlot.slot1
            : (slot == PlayerSlot.slot2)
                ? PlayerSlot.slot4
                : PlayerSlot.slot2;
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
