import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/domain/engine/game_engine.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_rules.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';

void main() {
  late GameEngine engine;

  setUp(() {
    engine = GameEngine();
  });

  group('House Rule: Open on 1 or 6', () {
    final homeToken = Token(id: 0, slot: PlayerSlot.slot1);

    test('Default classic rule requires exactly 6 to exit base', () {
      const defaultRules = GameRules();
      expect(
        engine.isValidMove(homeToken, 6, rules: defaultRules),
        isTrue,
      );
      expect(
        engine.isValidMove(homeToken, 1, rules: defaultRules),
        isFalse,
      );
      expect(
        engine.isValidMove(homeToken, 3, rules: defaultRules),
        isFalse,
      );
    });

    test('Open on 1 or 6 allows both 1 and 6 to exit base', () {
      const customRules = GameRules(openOnOneAndSix: true);
      expect(
        engine.isValidMove(homeToken, 6, rules: customRules),
        isTrue,
      );
      expect(
        engine.isValidMove(homeToken, 1, rules: customRules),
        isTrue,
      );
      expect(
        engine.isValidMove(homeToken, 2, rules: customRules),
        isFalse,
      );
    });

    test('Rolling 6 gives extra turn, but rolling 1 to exit does not give extra turn', () {
      final player = Player(
        slot: PlayerSlot.slot1,
        name: 'Player 1',
        tokens: [
          Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 0),
        ],
      );

      final stateRoll6 = GameState(
        gameId: 'test_roll_6',
        players: [player],
        turnOrder: [PlayerSlot.slot1],
        currentTurn: PlayerSlot.slot1,
        diceValue: 6,
        isDiceRolled: true,
      );

      final resultRoll6 = engine.moveToken(stateRoll6, 0);
      expect(
        resultRoll6.events.contains(EngineEvent.extraTurn),
        isTrue,
      );

      final stateRoll1 = GameState(
        gameId: 'test_roll_1',
        players: [player],
        turnOrder: [PlayerSlot.slot1],
        currentTurn: PlayerSlot.slot1,
        diceValue: 1,
        isDiceRolled: true,
        rules: const GameRules(openOnOneAndSix: true),
      );

      final resultRoll1 = engine.moveToken(stateRoll1, 0);
      expect(
        resultRoll1.events.contains(EngineEvent.extraTurn),
        isFalse,
      );
    });
  });

  group('House Rule: Tokens Per Player (Quick Match)', () {
    test('LudoController initializes 2 tokens per player when configured', () {
      final config = {
        PlayerSlot.slot1: PlayerSetupConfig(name: 'Alice', type: PlayerType.localHuman),
        PlayerSlot.slot4: PlayerSetupConfig(name: 'Bob', type: PlayerType.localHuman),
      };

      final controller = LudoController(
        config,
        rules: const GameRules(tokensPerPlayer: 2),
      );

      for (var player in controller.state.players) {
        expect(player.tokens.length, equals(2));
      }

      controller.dispose();
    });

    test('LudoController initializes 4 tokens per player on classic rules', () {
      final config = {
        PlayerSlot.slot1: PlayerSetupConfig(name: 'Alice', type: PlayerType.localHuman),
        PlayerSlot.slot4: PlayerSetupConfig(name: 'Bob', type: PlayerType.localHuman),
      };

      final controller = LudoController(
        config,
        rules: const GameRules(tokensPerPlayer: 4),
      );

      for (var player in controller.state.players) {
        expect(player.tokens.length, equals(4));
      }

      controller.dispose();
    });
  });

  group('House Rule: Three 6s Penalty Toggle', () {
    test('Penalizes three consecutive 6s when enabled (default)', () {
      final player = Player(
        slot: PlayerSlot.slot1,
        name: 'Player 1',
        tokens: [
          Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 0),
        ],
      );

      final state = GameState(
        gameId: 'three_six_test',
        players: [player],
        turnOrder: [PlayerSlot.slot1],
        currentTurn: PlayerSlot.slot1,
        consecutiveSixes: 2,
        rules: const GameRules(penalizeThreeSixes: true),
      );

      final result = engine.rollDice(state, 6);
      expect(result.events.contains(EngineEvent.turnSkipped), isTrue);
    });

    test('Does not penalize three consecutive 6s when disabled', () {
      final player = Player(
        slot: PlayerSlot.slot1,
        name: 'Player 1',
        tokens: [
          Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 0),
        ],
      );

      final state = GameState(
        gameId: 'three_six_test',
        players: [player],
        turnOrder: [PlayerSlot.slot1],
        currentTurn: PlayerSlot.slot1,
        consecutiveSixes: 2,
        rules: const GameRules(penalizeThreeSixes: false),
      );

      final result = engine.rollDice(state, 6);
      expect(result.events.contains(EngineEvent.turnSkipped), isFalse);
      expect(result.state.isDiceRolled, isTrue);
    });
  });

  group('GameRules serialization and equality', () {
    test('toJson and fromJson preserves all settings', () {
      const original = GameRules(
        openOnOneAndSix: true,
        tokensPerPlayer: 2,
        penalizeThreeSixes: false,
      );

      final json = original.toJson();
      final restored = GameRules.fromJson(json);

      expect(restored, equals(original));
      expect(restored.isCustom, isTrue);
    });

    test('isCustom is false for default rules', () {
      const defaultRules = GameRules();
      expect(defaultRules.isCustom, isFalse);
    });
  });

  group('Replay and Online Multiplayer Rules Safety', () {
    test('Replaying a local match retains the same rules and game mode', () {
      const customRules = GameRules(
        openOnOneAndSix: true,
        tokensPerPlayer: 2,
        penalizeThreeSixes: false,
      );

      final config = {
        PlayerSlot.slot1: PlayerSetupConfig(name: 'Player 1', type: PlayerType.localHuman),
        PlayerSlot.slot2: PlayerSetupConfig(name: 'Player 2', type: PlayerType.localHuman),
      };

      final initialController = LudoController(
        config,
        gameMode: GameMode.team,
        rules: customRules,
      );

      final finishedState = initialController.state.copyWith(
        winners: [PlayerSlot.slot1],
      );

      // Simulate replaying the game as done in LudoGameOverDialog:
      final replayedController = LudoController(
        config,
        gameMode: finishedState.gameMode,
        rules: finishedState.rules,
      );

      expect(replayedController.rules, equals(customRules));
      expect(replayedController.gameMode, equals(GameMode.team));
      expect(replayedController.state.rules, equals(customRules));
      expect(replayedController.state.gameMode, equals(GameMode.team));
      expect(replayedController.state.players.first.tokens.length, equals(2));

      initialController.dispose();
      replayedController.dispose();
    });

    test('Online games strictly enforce classic rules with no house rules contamination', () {
      const defaultRules = GameRules();
      expect(defaultRules.openOnOneAndSix, isFalse);
      expect(defaultRules.tokensPerPlayer, equals(4));
      expect(defaultRules.penalizeThreeSixes, isTrue);
      expect(defaultRules.isCustom, isFalse);

      final onlineState = GameState(
        gameId: 'online_match_123',
        players: [],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot2],
        currentTurn: PlayerSlot.slot1,
        gameType: GameType.online,
        rules: const GameRules(),
      );

      expect(onlineState.gameType, equals(GameType.online));
      expect(onlineState.rules.isCustom, isFalse);
      expect(onlineState.rules.openOnOneAndSix, isFalse);
      expect(onlineState.rules.tokensPerPlayer, equals(4));
      expect(onlineState.rules.penalizeThreeSixes, isTrue);
    });
  });
}
