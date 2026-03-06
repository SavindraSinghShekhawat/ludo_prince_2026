import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/controllers/local_game_controller.dart';

void main() {
  group('Dice Randomness Tests (via Controller)', () {
    test(
        'LocalGameController.generateDiceValue() distribution should be statistically fair',
        () {
      const iterations = 10000000;
      final results = List.filled(7, 0);

      for (var i = 0; i < iterations; i++) {
        final roll = LocalGameController.generateDiceValue();
        results[roll]++;
      }

      const expected = iterations / 6;
      final chiSquared = results.skip(1).fold(0.0, (sum, count) {
        return sum + (count - expected) * (count - expected) / expected;
      });

      // The critical value for Chi-Square at 5 degrees of freedom and alpha=0.01 is 15.086
      expect(chiSquared, lessThan(15.086),
          reason:
              'Controller dice distribution is not statistically fair (Chi-Squared: $chiSquared)');

      for (var i = 1; i <= 6; i++) {
        expect(results[i], greaterThan(0),
            reason: 'Value $i was never rolled by controller');
      }
    });

    test('Values should always be between 1 and 6', () {
      for (var i = 0; i < 1000; i++) {
        final roll = LocalGameController.generateDiceValue();
        expect(roll, isIn([1, 2, 3, 4, 5, 6]));
      }
    });
  });
}
