import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/games/ludo/domain/engine/game_engine.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/controller/src/game_event_provider.dart';

class MockEventProvider extends GameEventProvider {
  final _controller = StreamController<GameEvent>.broadcast();
  bool skipRequested = false;

  @override
  Stream<GameEvent> get events => _controller.stream;

  @override
  void onRollRequested({int? diceValue}) {}

  @override
  void onMoveRequested(int tokenId) {}

  @override
  void onSkipRequested() {
    skipRequested = true;
  }

  @override
  void onQuitRequested(PlayerSlot slot) {}

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Online Turn Skip & Resilience Tests', () {
    late GameEngine engine;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      engine = GameEngine();
    });

    test('GameEngine.passTurn() advances turn without incrementing skipCount', () {
      final slots = [PlayerSlot.slot1, PlayerSlot.slot3];
      var state = GameState(
        gameId: "test_pass_turn",
        gameMode: GameMode.classic,
        turnOrder: slots,
        currentTurn: PlayerSlot.slot1,
        winners: const [],
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: "Player 1",
            skipCount: 0,
            tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot1, state: TokenState.home, position: 0)),
          ),
          Player(
            slot: PlayerSlot.slot3,
            name: "Player 2",
            skipCount: 0,
            tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot3, state: TokenState.home, position: 0)),
          ),
        ],
      );

      final result = engine.passTurn(state, "No valid moves. Turn passed.");
      expect(result.state.currentTurn, PlayerSlot.slot3);
      final p1 = result.state.players.firstWhere((p) => p.slot == PlayerSlot.slot1);
      expect(p1.skipCount, 0, reason: "passTurn should not increment skipCount");
    });

    test('GameEngine.skipTurn() advances turn and increments skipCount', () {
      final slots = [PlayerSlot.slot1, PlayerSlot.slot3];
      var state = GameState(
        gameId: "test_skip_turn",
        gameMode: GameMode.classic,
        turnOrder: slots,
        currentTurn: PlayerSlot.slot1,
        winners: const [],
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: "Player 1",
            skipCount: 1,
            tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot1, state: TokenState.home, position: 0)),
          ),
          Player(
            slot: PlayerSlot.slot3,
            name: "Player 2",
            skipCount: 0,
            tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot3, state: TokenState.home, position: 0)),
          ),
        ],
      );

      final result = engine.skipTurn(state);
      expect(result.state.currentTurn, PlayerSlot.slot3);
      final p1 = result.state.players.firstWhere((p) => p.slot == PlayerSlot.slot1);
      expect(p1.skipCount, 2, reason: "skipTurn should increment skipCount");
    });

    test('In online mode, a roll with no valid moves does NOT advance currentTurn eagerly', () async {
      final mockProvider = MockEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Player 1", type: PlayerType.localHuman),
          PlayerSlot.slot3: PlayerSetupConfig(name: "Player 2", type: PlayerType.remoteHuman),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: mockProvider,
      );

      controller.state = controller.state.copyWith(
        gameType: GameType.online,
        currentTurn: PlayerSlot.slot1,
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot3],
      );

      // Roll a 2 with all tokens in base -> No valid moves
      await controller.executeRoll(2, fastForward: true);

      // Verify that currentTurn is STILL PlayerSlot.slot1 locally!
      // This prevents PlayerSlot.slot3 from eagerly rolling before server accepts the skip!
      expect(controller.state.currentTurn, PlayerSlot.slot1);
      expect(mockProvider.skipRequested, isTrue);

      await controller.dispose();
    });

    test('Roll safety timer resets isWaitingForResult if server does not respond within 3s', () async {
      final mockProvider = MockEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Player 1", type: PlayerType.localHuman),
          PlayerSlot.slot3: PlayerSetupConfig(name: "Player 2", type: PlayerType.remoteHuman),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: mockProvider,
      );

      controller.state = controller.state.copyWith(
        gameType: GameType.online,
        currentTurn: PlayerSlot.slot1,
        isDiceRolled: false,
        isRolling: false,
        isWaitingForResult: false,
      );

      // Trigger roll intent (classic flow with no prefetchedSeed)
      await controller.sendRollIntent();

      expect(controller.state.isWaitingForResult, isTrue);
      expect(controller.state.isRolling, isTrue);

      // Wait 3.2 seconds for the safety timer to fire
      await Future.delayed(const Duration(milliseconds: 3200));

      expect(controller.state.isWaitingForResult, isFalse, reason: "Safety timer should unlock waiting state");
      expect(controller.state.isRolling, isFalse, reason: "Safety timer should unlock rolling state");

      await controller.dispose();
    });
  });
}
