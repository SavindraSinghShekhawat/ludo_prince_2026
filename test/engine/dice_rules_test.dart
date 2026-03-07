import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/engine/game_engine.dart';
import 'package:ludo_prince/models/token.dart';
import 'test_utils.dart';

void main() {
  late GameEngine engine;

  setUp(() {
    engine = GameEngine();
  });

  group("Dice Rules", () {
    test("Dice sets state when move possible", () {
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 0);

      final result = engine.rollDice(state, 3).state;

      expect(result.diceValue, 3);
      expect(result.isDiceRolled, true);
    });

    test("No valid moves skips turn", () {
      final state = baseState();

      final result = engine.rollDice(state, 2).state;

      expect(result.currentTurn, PlayerSlot.slot4);
      expect(result.isDiceRolled, false);
      expect(result.message.contains("No valid moves"), true);
    });

    test("Three sixes skips turn", () {
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 0);

      // Roll 1st six
      state = engine.rollDice(state, 6).state;
      expect(state.consecutiveSixes, 1);
      state = state.copyWith(isDiceRolled: false);

      // Roll 2nd six
      state = engine.rollDice(state, 6).state;
      expect(state.consecutiveSixes, 2);
      state = state.copyWith(isDiceRolled: false);

      // Roll 3rd six
      final result = engine.rollDice(state, 6);
      state = result.state;

      expect(state.currentTurn, PlayerSlot.slot4);
      expect(state.consecutiveSixes, 0);
      expect(state.message.contains("three 6s"), true);
      expect(result.events.contains(EngineEvent.turnSkipped), true);
    });

    test("Two sixes and then a three does not skip turn", () {
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 0);

      // Roll 1st six
      state = engine.rollDice(state, 6).state;
      state = state.copyWith(isDiceRolled: false);

      // Roll 2nd six
      state = engine.rollDice(state, 6).state;
      state = state.copyWith(isDiceRolled: false);

      // Roll a three
      state = engine.rollDice(state, 3).state;

      expect(state.currentTurn, PlayerSlot.slot1);
      expect(state.consecutiveSixes, 0);
      expect(state.isDiceRolled, true);
    });

    test("Extra turn on 6 after moving", () {
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 0);
      state = state.copyWith(diceValue: 6, isDiceRolled: true);

      final result = engine.moveToken(state, 0);

      expect(result.state.currentTurn, PlayerSlot.slot1);
      expect(result.state.message.contains("extra turn"), true);
      expect(result.events.contains(EngineEvent.extraTurn), true);
    });
  });
}
