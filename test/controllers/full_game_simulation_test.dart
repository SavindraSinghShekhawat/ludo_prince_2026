import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/games/ludo/domain/engine/game_engine.dart';
import 'package:ludo_prince/games/ludo/domain/engine/bot_ai.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';

void main() {
  group('Full Game Simulation Tests', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine();
    });

    test('Simulates a complete 2-player game from start to finish until Game Over', () {
      // 1. Setup 2-player initial game state
      final slots = [PlayerSlot.slot1, PlayerSlot.slot3];
      var state = GameState(
        gameId: "full_sim_game_2p",
        gameMode: GameMode.classic,
        turnOrder: slots,
        currentTurn: PlayerSlot.slot1,
        winners: const [],
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: "Player 1",
            type: PlayerType.localBot,
            sixPity: 0,
            tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot1, state: TokenState.home, position: 0)),
          ),
          Player(
            slot: PlayerSlot.slot3,
            name: "Player 2",
            type: PlayerType.localBot,
            sixPity: 0,
            tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot3, state: TokenState.home, position: 0)),
          ),
        ],
      );

      expect(state.isGameOver, isFalse);
      expect(state.winners, isEmpty);

      int turnCount = 0;
      const maxTurns = 1200; // Cap to prevent infinite loops
      int totalRolls = 0;
      int totalMoves = 0;
      int totalCaptures = 0;

      while (!state.isGameOver && turnCount < maxTurns) {
        turnCount++;
        final currentPlayer = state.players.firstWhere((p) => p.slot == state.currentTurn);

        // A. Roll the dice
        final seed = LudoController.generateRandomSeed();
        final isBonus = state.consecutiveSixes > 0 || state.lastAction == GameAction.capture;
        final needsPity = LudoController.playerNeedsBasePity(currentPlayer);
        final diceValue = LudoController.generatePRDDice(
          seed,
          currentPlayer.sixPity,
          isBonusRoll: isBonus,
          needsBasePity: needsPity,
        );
        totalRolls++;

        final rollResult = engine.rollDice(state, diceValue);
        state = rollResult.state;

        // B. Check if turn was skipped (no valid moves)
        if (rollResult.events.contains(EngineEvent.turnSkipped)) {
          continue;
        }

        // C. Find best move using BotAI
        final bestToken = BotAI.getBestMove(currentPlayer, state);
        if (bestToken != null) {
          totalMoves++;
          // Simulate stepping the token
          Token currentToken = bestToken;
          int steps = state.diceValue;

          if (currentToken.state == TokenState.home && steps == 6) {
            currentToken = currentToken.copyWith(state: TokenState.board, position: 0);
            final stepResult = engine.applyStep(state, currentToken);
            state = stepResult.state;
          } else {
            for (int s = 0; s < steps; s++) {
              currentToken = engine.advanceOneStep(currentToken);
              final isLastStep = (s == steps - 1);
              final stepResult = engine.applyStep(state, currentToken, allowCapture: isLastStep);
              state = stepResult.state;
              if (stepResult.events.contains(EngineEvent.capture)) {
                totalCaptures++;
              }
            }
          }

          // Finalize turn
          final moveResult = engine.moveToken(state, bestToken.id);
          state = moveResult.state;
        }
      }

      print('2-Player Game finished in $turnCount turns:');
      print('- Total Rolls: $totalRolls');
      print('- Total Moves: $totalMoves');
      print('- Total Captures: $totalCaptures');
      print('- Winners: ${state.winners.map((s) => s.name).toList()}');
      print('- Is Game Over: ${state.isGameOver}');

      expect(state.isGameOver, isTrue, reason: 'Game must reach Game Over state');
      expect(state.winners, isNotEmpty, reason: 'Winners list must be populated');
      expect(state.winners.length, 2, reason: 'In a 2-player game, both 1st and 2nd place should be determined');
    });

    test('Simulates a complete 4-player game until all ranks are determined', () {
      final slots = [
        PlayerSlot.slot1,
        PlayerSlot.slot4,
        PlayerSlot.slot3,
        PlayerSlot.slot2,
      ];

      var state = GameState(
        gameId: "full_sim_game_4p",
        gameMode: GameMode.classic,
        turnOrder: slots,
        currentTurn: PlayerSlot.slot1,
        winners: const [],
        players: slots.map((slot) => Player(
          slot: slot,
          name: slot.name.toUpperCase(),
          type: PlayerType.localBot,
          sixPity: 0,
          tokens: List.generate(4, (i) => Token(id: i, slot: slot, state: TokenState.home, position: 0)),
        )).toList(),
      );

      int turnCount = 0;
      const maxTurns = 2000;
      int totalRolls = 0;
      int totalMoves = 0;

      while (!state.isGameOver && turnCount < maxTurns) {
        turnCount++;
        final currentPlayer = state.players.firstWhere((p) => p.slot == state.currentTurn);

        final seed = LudoController.generateRandomSeed();
        final isBonus = state.consecutiveSixes > 0 || state.lastAction == GameAction.capture;
        final needsPity = LudoController.playerNeedsBasePity(currentPlayer);
        final diceValue = LudoController.generatePRDDice(
          seed,
          currentPlayer.sixPity,
          isBonusRoll: isBonus,
          needsBasePity: needsPity,
        );
        totalRolls++;

        final rollResult = engine.rollDice(state, diceValue);
        state = rollResult.state;

        if (rollResult.events.contains(EngineEvent.turnSkipped)) {
          continue;
        }

        final bestToken = BotAI.getBestMove(currentPlayer, state);
        if (bestToken != null) {
          totalMoves++;
          Token currentToken = bestToken;
          int steps = state.diceValue;

          if (currentToken.state == TokenState.home && steps == 6) {
            currentToken = currentToken.copyWith(state: TokenState.board, position: 0);
            final stepResult = engine.applyStep(state, currentToken);
            state = stepResult.state;
          } else {
            for (int s = 0; s < steps; s++) {
              currentToken = engine.advanceOneStep(currentToken);
              final isLastStep = (s == steps - 1);
              final stepResult = engine.applyStep(state, currentToken, allowCapture: isLastStep);
              state = stepResult.state;
            }
          }

          final moveResult = engine.moveToken(state, bestToken.id);
          state = moveResult.state;
        }
      }

      print('4-Player Game finished in $turnCount turns:');
      print('- Total Rolls: $totalRolls');
      print('- Total Moves: $totalMoves');
      print('- Winners: ${state.winners.map((s) => s.name).toList()}');
      print('- Is Game Over: ${state.isGameOver}');

      expect(state.isGameOver, isTrue, reason: '4-Player game must conclude with Game Over');
      expect(state.winners.length, 4, reason: 'All 4 positions should be assigned');
    });
  });
}
