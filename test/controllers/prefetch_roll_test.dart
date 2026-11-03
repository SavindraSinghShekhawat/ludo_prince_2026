import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/controller/src/game_event_provider.dart';

class MockEventProvider extends GameEventProvider {
  final _controller = StreamController<GameEvent>.broadcast();
  bool rollRequested = false;
  int? rollValueRequested;
  int? moveRequestedTokenId;
  bool quitRequested = false;

  @override
  Stream<GameEvent> get events => _controller.stream;

  @override
  void onRollRequested({int? diceValue}) {
    rollRequested = true;
    rollValueRequested = diceValue;
  }

  @override
  void onMoveRequested(int tokenId) {
    moveRequestedTokenId = tokenId;
  }

  @override
  void onSkipRequested() {}

  @override
  void onQuitRequested(PlayerSlot slot) {
    quitRequested = true;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prefetch Roll and Online Smoothness Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Optimistic prefetched roll lands locally after 650ms with isRolling=false', () async {
      final mockProvider = MockEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Local Player", type: PlayerType.localHuman),
          PlayerSlot.slot3: PlayerSetupConfig(name: "Remote Player", type: PlayerType.remoteHuman),
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
        prefetchedSeed: 42,
      );

      final states = <GameState>[];
      final sub = controller.streamController.stream.listen(states.add);

      // Start the optimistic roll intent
      final rollFuture = controller.sendRollIntent();

      // Immediately after triggering, isRolling should be true
      expect(controller.state.isRolling, isTrue);
      expect(controller.state.isWaitingForResult, isTrue);
      expect(mockProvider.rollRequested, isTrue);

      // Wait for the 650ms local landing delay to complete
      await rollFuture;

      // After 650ms, the dice should land locally: isRolling is false, isWaitingForResult is false
      expect(controller.state.isRolling, isFalse, reason: "Local landing must set isRolling to false");
      expect(controller.state.isWaitingForResult, isFalse, reason: "Local landing must clear isWaitingForResult");
      expect(controller.state.diceValue, inInclusiveRange(1, 6));

      final landedValue = controller.state.diceValue;

      // Now simulate server RollEvent arriving with the same dice value
      final stopwatch = Stopwatch()..start();
      await controller.executeRoll(landedValue, fastForward: false);
      stopwatch.stop();

      // Because alreadyLanded evaluated to true, executeRoll must NOT wait for the 300+450ms animation
      expect(stopwatch.elapsedMilliseconds, lessThan(400),
          reason: "Roll should recognize alreadyLanded and not re-run full roll animation");

      await sub.cancel();
      await controller.dispose();
    });

    test('Remote player roll does not trigger local auto-move intent even if only 1 move is valid', () async {
      final mockProvider = MockEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Local Player", type: PlayerType.localHuman),
          PlayerSlot.slot3: PlayerSetupConfig(name: "Remote Player", type: PlayerType.remoteHuman),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: mockProvider,
      );

      // It is slot3's (remote player's) turn
      controller.state = controller.state.copyWith(
        gameType: GameType.online,
        currentTurn: PlayerSlot.slot3,
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot3],
        isDiceRolled: false,
        isRolling: false,
        isWaitingForResult: false,
      );

      // Give PlayerSlot.slot3 exactly one active token on board so it would qualify for auto-move
      final updatedPlayers = controller.state.players.map((p) {
        if (p.slot == PlayerSlot.slot3) {
          return p.copyWith(
            tokens: [
              Token(id: 0, slot: PlayerSlot.slot3, state: TokenState.board, position: 5),
              Token(id: 1, slot: PlayerSlot.slot3, state: TokenState.home, position: 0),
              Token(id: 2, slot: PlayerSlot.slot3, state: TokenState.home, position: 0),
              Token(id: 3, slot: PlayerSlot.slot3, state: TokenState.home, position: 0),
            ],
          );
        }
        return p;
      }).toList();

      controller.state = controller.state.copyWith(players: updatedPlayers);

      // Execute a roll of 3 for slot3 in fastForward mode
      await controller.executeRoll(3, fastForward: true);

      // Local client must NOT send onMoveRequested for the remote player's token!
      expect(mockProvider.moveRequestedTokenId, isNull,
          reason: "Local client must never execute auto-move for remote player");

      await controller.dispose();
    });

    test('Controller dispose does not send onQuitRequested (prevents accidental forfeit)', () async {
      final mockProvider = MockEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Local Player", type: PlayerType.localHuman),
          PlayerSlot.slot3: PlayerSetupConfig(name: "Remote Player", type: PlayerType.remoteHuman),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: mockProvider,
      );

      await controller.dispose();
      expect(mockProvider.quitRequested, isFalse, reason: "Normal dispose must never forfeit");

      // Only explicit quitGame() should trigger onQuitRequested
      final controller2 = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Local Player", type: PlayerType.localHuman),
          PlayerSlot.slot3: PlayerSetupConfig(name: "Remote Player", type: PlayerType.remoteHuman),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: mockProvider,
      );

      controller2.quitGame();
      expect(mockProvider.quitRequested, isTrue, reason: "Explicit quitGame must request quit");
    });
  });
}
