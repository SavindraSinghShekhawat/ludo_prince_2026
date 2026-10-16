import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';

void main() {
  group('Dice Randomness Tests (via Controller)', () {
    test(
      'LudoController.generateDiceValue() distribution should be statistically fair',
      () {
        const iterations = 10000000;
        final results = List.filled(7, 0);

        int currentPity = 0;
        for (var i = 0; i < iterations; i++) {
          final seed = LudoController.generateRandomSeed();
          final roll = LudoController.generatePRDDice(seed, currentPity);
          if (roll == 6) {
            currentPity = 0;
          } else {
            currentPity++;
          }
          results[roll]++;
        }

        const expected = iterations / 6;
        final chiSquared = results.skip(1).fold(0.0, (sum, count) {
          return sum + (count - expected) * (count - expected) / expected;
        });

        // The critical value for Chi-Square at 5 degrees of freedom and alpha=0.001 is 20.515
        expect(
          chiSquared,
          lessThan(20.515),
          reason:
              'Controller dice distribution is not statistically fair (Chi-Squared: $chiSquared)',
        );

        for (var i = 1; i <= 6; i++) {
          expect(
            results[i],
            greaterThan(0),
            reason: 'Value $i was never rolled by controller',
          );
        }
      },
    );

    test('Values should always be between 1 and 6', () {
      for (var i = 0; i < 1000; i++) {
        final roll = LudoController.generateDiceValue();
        expect(roll, isIn([1, 2, 3, 4, 5, 6]));
      }
    });

    test(
      'Bonus rolls (following a 6) should be statistically fair across all 6 faces',
      () {
        const iterations = 5000000;
        final results = List.filled(7, 0);

        for (var i = 0; i < iterations; i++) {
          final seed = LudoController.generateRandomSeed();
          final roll = LudoController.generatePRDDice(
            seed,
            0,
            isBonusRoll: true,
          );
          results[roll]++;
        }

        const expected = iterations / 6;
        final chiSquared = results.skip(1).fold(0.0, (sum, count) {
          return sum + (count - expected) * (count - expected) / expected;
        });

        // The critical value for Chi-Square at 5 degrees of freedom and alpha=0.001 is 20.515
        expect(
          chiSquared,
          lessThan(20.515),
          reason:
              'Bonus roll distribution is not statistically fair (Chi-Squared: $chiSquared)',
        );

        for (var i = 1; i <= 6; i++) {
          expect(
            results[i],
            greaterThan(0),
            reason: 'Value $i was never rolled on bonus roll',
          );
        }
      },
    );

    test('Double sixes must be naturally possible on bonus rolls', () {
      int bonusSixes = 0;
      const trials = 10000;
      for (var i = 0; i < trials; i++) {
        final seed = LudoController.generateRandomSeed();
        final roll = LudoController.generatePRDDice(
          seed,
          0,
          isBonusRoll: true,
        );
        if (roll == 6) bonusSixes++;
      }
      // With fair 1/6 probability, expected is ~1667 in 10000 trials
      expect(
        bonusSixes,
        greaterThan(1200),
        reason: 'Consecutive sixes should naturally occur ~16.7% of the time',
      );
    });

    test(
      'Active field play (needsBasePity: false) should be strictly uniform across all 6 faces',
      () {
        const iterations = 5000000;
        final results = List.filled(7, 0);

        for (var i = 0; i < iterations; i++) {
          final seed = LudoController.generateRandomSeed();
          final roll = LudoController.generatePRDDice(
            seed,
            3,
            needsBasePity: false,
          );
          results[roll]++;
        }

        const expected = iterations / 6;
        final chiSquared = results.skip(1).fold(0.0, (sum, count) {
          return sum + (count - expected) * (count - expected) / expected;
        });

        expect(
          chiSquared,
          lessThan(20.515),
          reason:
              'Field play dice distribution is not statistically fair (Chi-Squared: $chiSquared)',
        );
      },
    );

    test('LudoController.playerNeedsBasePity correctly identifies all edge cases', () {
      // Edge Case 1: Start of game (all 4 in base) -> needs pity
      final p1 = Player(
        slot: PlayerSlot.slot1,
        name: "P1",
        tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot1, state: TokenState.home, position: 0)),
      );
      expect(LudoController.playerNeedsBasePity(p1), true);

      // Edge Case 2: 1 on board, 3 in base -> active play (does NOT need pity)
      final p2 = Player(
        slot: PlayerSlot.slot1,
        name: "P1",
        tokens: [
          Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 10),
          Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
          Token(id: 2, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
          Token(id: 3, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
        ],
      );
      expect(LudoController.playerNeedsBasePity(p2), false);

      // Edge Case 3: 2 finished, 2 in base, 0 on board -> stranded (needs pity)
      final p3 = Player(
        slot: PlayerSlot.slot1,
        name: "P1",
        tokens: [
          Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.finished, position: 56),
          Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.finished, position: 56),
          Token(id: 2, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
          Token(id: 3, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
        ],
      );
      expect(LudoController.playerNeedsBasePity(p3), true);

      // Edge Case 4: 1 blocked at 55 in homeStretch, 3 in base -> stranded (needs pity)
      final p4 = Player(
        slot: PlayerSlot.slot1,
        name: "P1",
        tokens: [
          Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.homeStretch, position: 55),
          Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
          Token(id: 2, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
          Token(id: 3, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
        ],
      );
      expect(LudoController.playerNeedsBasePity(p4), true);

      // Edge Case 5: 1 at 52 in homeStretch (can advance), 3 in base -> movable (does NOT need pity)
      final p5 = Player(
        slot: PlayerSlot.slot1,
        name: "P1",
        tokens: [
          Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.homeStretch, position: 52),
          Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
          Token(id: 2, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
          Token(id: 3, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
        ],
      );
      expect(LudoController.playerNeedsBasePity(p5), false);

      // Edge Case 6: All out of base (0 in base) -> does NOT need pity
      final p6 = Player(
        slot: PlayerSlot.slot1,
        name: "P1",
        tokens: [
          Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.finished, position: 56),
          Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.board, position: 20),
          Token(id: 2, slot: PlayerSlot.slot1, state: TokenState.board, position: 30),
          Token(id: 3, slot: PlayerSlot.slot1, state: TokenState.homeStretch, position: 54),
        ],
      );
      expect(LudoController.playerNeedsBasePity(p6), false);
    });

    test('Base-exit pity curve matches design (natural turns 1-6, assist turns 7-8, ceiling turn 9+)', () {
      const trials = 100000;

      // Pity 0..5 (Turns 1..6): Natural 1/6 (~16.67%)
      for (int p = 0; p < 6; p++) {
        int sixes = 0;
        for (int i = 0; i < trials; i++) {
          final seed = LudoController.generateRandomSeed();
          if (LudoController.generatePRDDice(seed, p, needsBasePity: true) == 6) {
            sixes++;
          }
        }
        final rate = sixes / trials;
        expect(rate, closeTo(0.1667, 0.01), reason: 'Turn ${p + 1} should have natural 1/6 luck');
      }

      // Pity 6 (Turn 7): 25% assist
      int sixesPity6 = 0;
      for (int i = 0; i < trials; i++) {
        final seed = LudoController.generateRandomSeed();
        if (LudoController.generatePRDDice(seed, 6, needsBasePity: true) == 6) {
          sixesPity6++;
        }
      }
      expect(sixesPity6 / trials, closeTo(0.25, 0.015), reason: 'Turn 7 should have 25% assist');

      // Pity 7 (Turn 8): 50% assist
      int sixesPity7 = 0;
      for (int i = 0; i < trials; i++) {
        final seed = LudoController.generateRandomSeed();
        if (LudoController.generatePRDDice(seed, 7, needsBasePity: true) == 6) {
          sixesPity7++;
        }
      }
      expect(sixesPity7 / trials, closeTo(0.50, 0.015), reason: 'Turn 8 should have 50% assist');

      // Pity 8+ (Turn 9+): 100% safety airbag
      for (int p = 8; p <= 12; p++) {
        for (int i = 0; i < 1000; i++) {
          final seed = LudoController.generateRandomSeed();
          expect(
            LudoController.generatePRDDice(seed, p, needsBasePity: true),
            6,
            reason: 'Turn ${p + 1} must guarantee a 6 as safety airbag',
          );
        }
      }
    });

    test('Base-exit simulation guarantees all players exit by turn 9, with majority exiting naturally', () {
      const playersCount = 20000;
      int naturalExits = 0; // Exited on turns 1-6
      int maxTurnsObserved = 0;

      for (int i = 0; i < playersCount; i++) {
        int pity = 0;
        int turns = 0;
        while (true) {
          turns++;
          final seed = LudoController.generateRandomSeed();
          final roll = LudoController.generatePRDDice(seed, pity, needsBasePity: true);
          if (roll == 6) {
            if (turns <= 6) naturalExits++;
            if (turns > maxTurnsObserved) maxTurnsObserved = turns;
            break;
          } else {
            pity++;
          }
        }
      }

      // 1. Absolutely NO player ever takes more than 9 turns
      expect(maxTurnsObserved, lessThanOrEqualTo(9));

      // 2. ~66.5% of players exit naturally during turns 1-6
      final naturalRate = naturalExits / playersCount;
      expect(naturalRate, closeTo(0.665, 0.03), reason: 'Majority of players must exit naturally without pity');
    });
  });
}
