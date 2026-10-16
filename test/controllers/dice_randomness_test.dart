import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';

void main() {
  group('Dice Randomness Tests (via Controller)', () {
    test(
      'LudoController.generateDiceValue() distribution should be statistically fair',
      () {
        const iterations = 10000000;
        final results = List.filled(7, 0);

        int currentPity = 2;
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

        // The critical value for Chi-Square at 5 degrees of freedom and alpha=0.01 is 15.086
        expect(
          chiSquared,
          lessThan(15.086),
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

        // The critical value for Chi-Square at 5 degrees of freedom and alpha=0.01 is 15.086
        expect(
          chiSquared,
          lessThan(15.086),
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
  });
}
