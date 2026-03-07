import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/engine/bot_ai.dart';
import 'package:ludo_prince/models/game_state.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/models/token.dart';
import 'package:ludo_prince/models/board_path.dart';

void main() {
  group('BotAI Move Selection', () {
    test('AI prefers taking out a new piece over forming an unsafe block', () {
      // Scenario: Player rolls a 6.
      // One token is already on the board at position 10 (unsafe).
      // Another token is in the home base.
      // Moving the first token by 6 steps would put it at position 16 (unsafe).
      // Taking out the new piece would put it at position 0 (safe).

      final player = Player(
        slot: PlayerSlot.slot4, // Red
        name: "Bot",
        tokens: [
          Token(
              id: 0,
              slot: PlayerSlot.slot4,
              state: TokenState.board,
              position: 10),
          Token(
              id: 1,
              slot: PlayerSlot.slot4,
              state: TokenState.home,
              position: -1),
          Token(
              id: 2,
              slot: PlayerSlot.slot4,
              state: TokenState.home,
              position: -1),
          Token(
              id: 3,
              slot: PlayerSlot.slot4,
              state: TokenState.home,
              position: -1),
        ],
      );

      // We need to setup a situation where moving token 0 to pos 10 + 6 = 16 forms a block.
      // So let's put another token at pos 16.
      final playerWithBuddy = player.copyWith(
        tokens: [
          Token(
              id: 0,
              slot: PlayerSlot.slot4,
              state: TokenState.board,
              position: 10),
          Token(
              id: 1,
              slot: PlayerSlot.slot4,
              state: TokenState.board,
              position: 16),
          Token(
              id: 2,
              slot: PlayerSlot.slot4,
              state: TokenState.home,
              position: -1),
          Token(
              id: 3,
              slot: PlayerSlot.slot4,
              state: TokenState.home,
              position: -1),
        ],
      );

      final state = GameState(
        gameId: "test",
        players: [playerWithBuddy],
        turnOrder: [PlayerSlot.slot4],
        currentTurn: PlayerSlot.slot4,
        isDiceRolled: true,
        diceValue: 6,
        winners: [],
      );

      // Target pos 16 is NOT a safe spot.
      expect(BoardPath.isSafeSpot(16), false);

      final bestToken = BotAI.getBestMove(playerWithBuddy, state);

      // Currently, it might choose token 0 because of the +900 block bonus.
      // We want it to prefer token 2 (taking out a new piece) which gets +1000 or at least move token 1 out.
      // Wait, if token 1 is at 16, and token 0 moves to 16, that's a block.
      // If token 2 (in home) moves to 0 with dice 6, that's "Opening strategy" or "Escape base".

      // Let's re-read evaluation:
      // Opening strategy (no tokens on board and dice 6): +1000
      // Escape base (token in home and dice 6): +600
      // Block formation: +900

      // In this case, anyOnBoard is true (tokens 0 and 1 are on board).
      // So token 2 or 3 getting out of base gets +600.
      // Token 0 moving to 16 gets +900 (block).
      // This is exactly the problem! 900 > 600.

      expect(bestToken?.id, isNot(0),
          reason:
              "AI should not prefer forming an unsafe block over taking out a new piece");
    });

    test('AI prefers forming a block on a safe spot over an unsafe spot', () {
      // Scenario: Choice between two moves that both form blocks.
      // Move A: Token 0 to position 8 (Safe spot, forms block with Token 1).
      // Move B: Token 2 to position 16 (Unsafe spot, forms block with Token 3).

      final player = Player(
        slot: PlayerSlot.slot4,
        name: "Bot",
        tokens: [
          Token(
              id: 0,
              slot: PlayerSlot.slot4,
              state: TokenState.board,
              position: 2), // Move to 8 (Dice 6)
          Token(
              id: 1,
              slot: PlayerSlot.slot4,
              state: TokenState.board,
              position: 8),
          Token(
              id: 2,
              slot: PlayerSlot.slot4,
              state: TokenState.board,
              position: 10), // Move to 16 (Dice 6)
          Token(
              id: 3,
              slot: PlayerSlot.slot4,
              state: TokenState.board,
              position: 16),
        ],
      );

      final state = GameState(
        gameId: "test",
        players: [player],
        turnOrder: [PlayerSlot.slot4],
        currentTurn: PlayerSlot.slot4,
        isDiceRolled: true,
        diceValue: 6,
        winners: [],
      );

      expect(BoardPath.isSafeSpot(8), true);
      expect(BoardPath.isSafeSpot(16), false);

      final bestToken = BotAI.getBestMove(player, state);

      expect(bestToken?.id, 0,
          reason: "AI should prefer forming a block on a safe spot");
    });
  });
}
