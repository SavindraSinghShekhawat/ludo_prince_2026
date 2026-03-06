import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/engine/game_engine.dart';
import 'package:ludo_prince/models/token.dart';
import 'test_utils.dart';

void main() {
  late GameEngine engine;

  setUp(() {
    engine = GameEngine();
  });

  group("Move Validations", () {
    test("Home token only valid on 6", () {
      final token = Token(id: 0, slot: PlayerSlot.slot1);

      expect(engine.isValidMove(token, 6), true);
      expect(engine.isValidMove(token, 3), false);
    });

    test("Finished token cannot move", () {
      final token = Token(
        id: 0,
        slot: PlayerSlot.slot1,
        state: TokenState.finished,
        position: 56,
      );

      expect(engine.isValidMove(token, 1), false);
    });

    test("Home stretch cannot overflow", () {
      final token = Token(
        id: 0,
        slot: PlayerSlot.slot1,
        state: TokenState.homeStretch,
        position: 55,
      );

      expect(engine.isValidMove(token, 2), false);
      expect(engine.isValidMove(token, 1), true);
    });

    test("Cannot move if dice not rolled", () {
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 0);
      state = state.copyWith(isDiceRolled: false); // Ensure dice NOT rolled

      final result = engine.moveToken(state, 0);

      expect(identical(result, state),
          true); // Should return unchanged state instance
    });

    test("Board to homeStretch transition", () {
      final token = Token(
        id: 0,
        slot: PlayerSlot.slot1,
        state: TokenState.board,
        position: 50,
      );

      final advanced = engine.advanceOneStep(token);

      expect(advanced.state, TokenState.homeStretch);
      expect(advanced.position, 51);
    });

    test("HomeStretch to finished", () {
      final token = Token(
        id: 0,
        slot: PlayerSlot.slot1,
        state: TokenState.homeStretch,
        position: 55,
      );

      final advanced = engine.advanceOneStep(token);

      expect(advanced.state, TokenState.finished);
      expect(advanced.position, 56);
    });
  });
}
