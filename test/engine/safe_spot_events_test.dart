import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/engine/game_engine.dart';
import 'package:ludo_prince/models/game_state.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/models/token.dart';

void main() {
  late GameEngine engine;

  setUp(() {
    engine = GameEngine();
  });

  group("Safe Spot Event Logic", () {
    test("Landing on safe spot emits safeSpot event", () {
      final token = Token(
        id: 0,
        slot: PlayerSlot.slot4,
        state: TokenState.board,
        position: 8, // position 8 is a safe spot
      );

      final state = GameState(
        gameId: "test",
        players: [
          Player(slot: PlayerSlot.slot4, name: "Red", tokens: [token])
        ],
        turnOrder: [PlayerSlot.slot4],
        currentTurn: PlayerSlot.slot4,
        winners: [],
      );

      // landing step (allowCapture = true)
      final result = engine.applyStep(state, token, allowCapture: true);
      expect(result.events.contains(EngineEvent.safeSpot), true);
    });

    test("Passing through safe spot does NOT emit safeSpot event", () {
      final token = Token(
        id: 0,
        slot: PlayerSlot.slot4,
        state: TokenState.board,
        position: 8, // position 8 is a safe spot
      );

      final state = GameState(
        gameId: "test",
        players: [
          Player(slot: PlayerSlot.slot4, name: "Red", tokens: [token])
        ],
        turnOrder: [PlayerSlot.slot4],
        currentTurn: PlayerSlot.slot4,
        winners: [],
      );

      // intermediate step (allowCapture = false)
      final result = engine.applyStep(state, token, allowCapture: false);
      expect(result.events.contains(EngineEvent.safeSpot), false);
    });

    test("Home exit (which lands on position 0) emits safeSpot event", () {
      // Position 0 is Red's start and a safe spot
      final token = Token(
        id: 0,
        slot: PlayerSlot.slot4,
        state: TokenState.board,
        position: 0,
      );

      final state = GameState(
        gameId: "test",
        players: [
          Player(slot: PlayerSlot.slot4, name: "Red", tokens: [token])
        ],
        turnOrder: [PlayerSlot.slot4],
        currentTurn: PlayerSlot.slot4,
        winners: [],
      );

      // Landing from home
      final result = engine.applyStep(state, token, allowCapture: true);
      expect(result.events.contains(EngineEvent.safeSpot), true);
    });
  });
}
