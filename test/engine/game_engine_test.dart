import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/engine/game_engine.dart';
import 'package:ludo_prince/models/game_state.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/models/token.dart';
import 'package:ludo_prince/models/board_path.dart';

GameState baseState() {
  return GameState(
    gameId: "test",
    players: [
      Player(
        color: PlayerColor.red,
        name: "Red",
        tokens: List.generate(4, (i) => Token(id: i, color: PlayerColor.red)),
      ),
      Player(
        color: PlayerColor.blue,
        name: "Blue",
        tokens: List.generate(4, (i) => Token(id: i, color: PlayerColor.blue)),
      ),
    ],
    turnOrder: [PlayerColor.red, PlayerColor.blue],
    currentTurn: PlayerColor.red,
  );
}

void main() {
  late GameEngine engine;

  setUp(() {
    engine = GameEngine();
  });

  group("Dice Rules", () {
    test("Dice sets state when move possible", () {
      var state = baseState();

      state = state.copyWith(
        players: [
          state.players[0].copyWith(
            tokens: [
              state.players[0].tokens[0]
                  .copyWith(state: TokenState.board, position: 0),
              ...state.players[0].tokens.sublist(1),
            ],
          ),
          state.players[1],
        ],
      );

      final result = engine.rollDice(state, 3);

      expect(result.diceValue, 3);
      expect(result.isDiceRolled, true);
    });

    test("No valid moves skips turn", () {
      final state = baseState();

      final result = engine.rollDice(state, 2);

      expect(result.currentTurn, PlayerColor.blue);
      expect(result.isDiceRolled, false);
    });

    test("Three sixes skips turn", () {
      var state = baseState();

      state = state.copyWith(
        players: [
          state.players[0].copyWith(
            tokens: [
              state.players[0].tokens[0]
                  .copyWith(state: TokenState.board, position: 0),
              ...state.players[0].tokens.sublist(1),
            ],
          ),
          state.players[1],
        ],
      );

      state = engine.rollDice(state, 6);
      state = state.copyWith(isDiceRolled: false);

      state = engine.rollDice(state, 6);
      state = state.copyWith(isDiceRolled: false);

      state = engine.rollDice(state, 6);

      expect(state.currentTurn, PlayerColor.blue);
      expect(state.consecutiveSixes, 0);
    });
  });

  group("Move Validations", () {
    test("Home token only valid on 6", () {
      final token = Token(id: 0, color: PlayerColor.red);

      expect(engine.isValidMove(token, 6), true);
      expect(engine.isValidMove(token, 3), false);
    });

    test("Finished token cannot move", () {
      final token = Token(
        id: 0,
        color: PlayerColor.red,
        state: TokenState.finished,
        position: 57,
      );

      expect(engine.isValidMove(token, 1), false);
    });

    test("Home stretch cannot overflow", () {
      final token = Token(
        id: 0,
        color: PlayerColor.red,
        state: TokenState.homeStretch,
        position: 56,
      );

      expect(engine.isValidMove(token, 2), false);
    });
  });

  group("Capture Logic", () {
    test("Capture happens on same absolute position", () {
      final red = Token(
        id: 0,
        color: PlayerColor.red,
        state: TokenState.board,
        position: 1,
      );

      final blue = Token(
        id: 0,
        color: PlayerColor.blue,
        state: TokenState.board,
        position: 14,
      );

      final state = GameState(
        gameId: "x",
        players: [
          Player(color: PlayerColor.red, name: "R", tokens: [red]),
          Player(color: PlayerColor.blue, name: "B", tokens: [blue]),
        ],
        turnOrder: [PlayerColor.red, PlayerColor.blue],
        currentTurn: PlayerColor.red,
      );

      bool captured = false;

      final result = engine.applyStep(
        state,
        red,
        onCapture: (c) => captured = c,
        allowCapture: true,
      );

      expect(captured, true);
      expect(result.players[1].tokens[0].state, TokenState.home);
    });

    test("No capture on safe spot", () {
      final red = Token(
        id: 0,
        color: PlayerColor.red,
        state: TokenState.board,
        position: 0,
      );

      final blue = Token(
        id: 0,
        color: PlayerColor.blue,
        state: TokenState.board,
        position: 13,
      );

      expect(BoardPath.isSafeSpot(0), true);

      final state = GameState(
        gameId: "x",
        players: [
          Player(color: PlayerColor.red, name: "R", tokens: [red]),
          Player(color: PlayerColor.blue, name: "B", tokens: [blue]),
        ],
        turnOrder: [PlayerColor.red, PlayerColor.blue],
        currentTurn: PlayerColor.red,
      );

      bool captured = false;

      engine.applyStep(
        state,
        red,
        onCapture: (c) => captured = c,
        allowCapture: true,
      );

      expect(captured, false);
    });
  });

  group("Advance Logic", () {
    test("Board to homeStretch transition", () {
      final token = Token(
        id: 0,
        color: PlayerColor.red,
        state: TokenState.board,
        position: 51,
      );

      final advanced = engine.advanceOneStep(token);

      expect(advanced.state, TokenState.homeStretch);
      expect(advanced.position, 52);
    });

    test("HomeStretch to finished", () {
      final token = Token(
        id: 0,
        color: PlayerColor.red,
        state: TokenState.homeStretch,
        position: 56,
      );

      final advanced = engine.advanceOneStep(token);

      expect(advanced.state, TokenState.finished);
      expect(advanced.position, 57);
    });
  });

  group("Turn System", () {
    test("Extra turn on 6", () {
      var state = baseState();

      state = state.copyWith(
        players: [
          state.players[0].copyWith(
            tokens: [
              state.players[0].tokens[0]
                  .copyWith(state: TokenState.board, position: 0),
              ...state.players[0].tokens.sublist(1),
            ],
          ),
          state.players[1],
        ],
        diceValue: 6,
        isDiceRolled: true,
      );

      final result = engine.moveToken(state, 0);

      expect(result.currentTurn, PlayerColor.red);
    });

    test("Normal move switches turn", () {
      var state = baseState();

      state = state.copyWith(
        players: [
          state.players[0].copyWith(
            tokens: [
              state.players[0].tokens[0]
                  .copyWith(state: TokenState.board, position: 0),
              ...state.players[0].tokens.sublist(1),
            ],
          ),
          state.players[1],
        ],
        diceValue: 3,
        isDiceRolled: true,
      );

      final result = engine.moveToken(state, 0);

      expect(result.currentTurn, PlayerColor.blue);
    });
  });

  group("State Integrity", () {
    test("Total token count remains constant", () {
      var state = baseState();

      state = state.copyWith(
        players: [
          state.players[0].copyWith(
            tokens: [
              state.players[0].tokens[0]
                  .copyWith(state: TokenState.board, position: 0),
              ...state.players[0].tokens.sublist(1),
            ],
          ),
          state.players[1],
        ],
      );

      final totalBefore = state.players
          .expand((p) => p.tokens)
          .length;

      final result = engine.rollDice(state, 3);

      final totalAfter = result.players
          .expand((p) => p.tokens)
          .length;

      expect(totalBefore, totalAfter);
    });
  });
}