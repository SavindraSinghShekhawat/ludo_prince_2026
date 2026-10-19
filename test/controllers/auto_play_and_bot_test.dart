import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/controller/src/game_event_provider.dart';

class TrackingEventProvider extends GameEventProvider {
  final _controller = StreamController<GameEvent>.broadcast();
  int? lastMovedTokenId;
  int? lastRolledDiceValue;
  int rollRequestCount = 0;
  int moveRequestCount = 0;

  @override
  Stream<GameEvent> get events => _controller.stream;

  @override
  void onRollRequested({int? diceValue}) {
    rollRequestCount++;
    lastRolledDiceValue = diceValue ?? 4;
    _controller.add(
      RollEvent(lastRolledDiceValue!, timestamp: DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  void onMoveRequested(int tokenId) {
    moveRequestCount++;
    lastMovedTokenId = tokenId;
    _controller.add(
      MoveEvent(tokenId, timestamp: DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  void onSkipRequested() {}

  @override
  void onQuitRequested(PlayerSlot slot) {}

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auto Play & Bot Player Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Normal player auto-move triggers when only 1 valid token can move', () async {
      final eventProvider = TrackingEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Human", type: PlayerType.localHuman),
          PlayerSlot.slot2: PlayerSetupConfig(name: "Bot", type: PlayerType.localBot),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: eventProvider,
      );

      // Set up slot1 with 1 token on board at position 5, other tokens in home
      final p1Tokens = [
        Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 5),
        Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
        Token(id: 2, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
        Token(id: 3, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
      ];

      final updatedPlayers = controller.state.players.map((p) {
        if (p.slot == PlayerSlot.slot1) {
          return p.copyWith(tokens: p1Tokens);
        }
        return p;
      }).toList();

      controller.state = controller.state.copyWith(
        currentTurn: PlayerSlot.slot1,
        players: updatedPlayers,
        isDiceRolled: false,
      );

      // Roll a 3 (not a 6, so tokens in home cannot exit; only token 0 can move)
      await controller.executeRoll(3, fastForward: true);

      // Allow event loop and step animations to complete
      await Future.delayed(const Duration(milliseconds: 500));

      expect(eventProvider.moveRequestCount, 1,
          reason: "Auto-move should have requested a move for the single valid token");
      expect(eventProvider.lastMovedTokenId, 0);

      // Verify the token moved to position 8
      final p1 = controller.state.players.firstWhere((p) => p.slot == PlayerSlot.slot1);
      final movedToken = p1.tokens.firstWhere((t) => t.id == 0);
      expect(movedToken.position, 8, reason: "Token 0 should have advanced 3 steps from 5 to 8");

      await controller.dispose();
    });

    test('Normal player does NOT auto-move when multiple tokens can move', () async {
      final eventProvider = TrackingEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Human", type: PlayerType.localHuman),
          PlayerSlot.slot2: PlayerSetupConfig(name: "Bot", type: PlayerType.localBot),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: eventProvider,
      );

      // Set up slot1 with 2 tokens on board at different positions
      final p1Tokens = [
        Token(id: 0, slot: PlayerSlot.slot1, state: TokenState.board, position: 5),
        Token(id: 1, slot: PlayerSlot.slot1, state: TokenState.board, position: 12),
        Token(id: 2, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
        Token(id: 3, slot: PlayerSlot.slot1, state: TokenState.home, position: 0),
      ];

      final updatedPlayers = controller.state.players.map((p) {
        if (p.slot == PlayerSlot.slot1) {
          return p.copyWith(tokens: p1Tokens);
        }
        return p;
      }).toList();

      controller.state = controller.state.copyWith(
        currentTurn: PlayerSlot.slot1,
        players: updatedPlayers,
        isDiceRolled: false,
      );

      // Roll a 3 (both tokens 0 and 1 can move)
      await controller.executeRoll(3, fastForward: true);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(eventProvider.moveRequestCount, 0,
          reason: "Should NOT auto-move when player has a tactical choice");
      expect(controller.state.isDiceRolled, isTrue);

      await controller.dispose();
    });

    test('isMyTurn is true for local bot even when localPlayerSlot is set to human', () async {
      final eventProvider = TrackingEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Human", type: PlayerType.localHuman),
          PlayerSlot.slot2: PlayerSetupConfig(name: "Bot", type: PlayerType.localBot),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: eventProvider,
      );

      // Current turn is human
      expect(controller.isMyTurn, isTrue);

      // Switch turn to Bot (slot2)
      controller.state = controller.state.copyWith(
        currentTurn: PlayerSlot.slot2,
      );

      // isMyTurn must be true for the local bot so bot turn can proceed!
      expect(controller.isMyTurn, isTrue,
          reason: "Local bot turn must be actionable on the local device");

      await controller.dispose();
    });

    test('Bot automatically executes auto-move when only 1 move is possible', () async {
      final eventProvider = TrackingEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Human", type: PlayerType.localHuman),
          PlayerSlot.slot2: PlayerSetupConfig(name: "Bot", type: PlayerType.localBot),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: eventProvider,
      );

      // Set up slot2 (Bot) with 1 token on board at position 10, other 3 in home
      final p2Tokens = [
        Token(id: 0, slot: PlayerSlot.slot2, state: TokenState.board, position: 10),
        Token(id: 1, slot: PlayerSlot.slot2, state: TokenState.home, position: 0),
        Token(id: 2, slot: PlayerSlot.slot2, state: TokenState.home, position: 0),
        Token(id: 3, slot: PlayerSlot.slot2, state: TokenState.home, position: 0),
      ];

      final updatedPlayers = controller.state.players.map((p) {
        if (p.slot == PlayerSlot.slot2) {
          return p.copyWith(tokens: p2Tokens);
        }
        return p;
      }).toList();

      controller.state = controller.state.copyWith(
        currentTurn: PlayerSlot.slot2,
        players: updatedPlayers,
        isDiceRolled: false,
      );

      // Bot rolls a 4 (only token 0 can move)
      await controller.executeRoll(4, fastForward: true);
      await Future.delayed(const Duration(milliseconds: 700));

      expect(eventProvider.moveRequestCount, 1,
          reason: "Bot should automatically execute move without stalling");
      expect(eventProvider.lastMovedTokenId, 0);

      final p2 = controller.state.players.firstWhere((p) => p.slot == PlayerSlot.slot2);
      final movedToken = p2.tokens.firstWhere((t) => t.id == 0);
      expect(movedToken.position, 14, reason: "Bot token 0 should have advanced 4 steps to 14");

      await controller.dispose();
    });

    test('Bot full turn flow: automatically rolls dice and executes move', () async {
      final eventProvider = TrackingEventProvider();
      final controller = LudoController(
        {
          PlayerSlot.slot1: PlayerSetupConfig(name: "Human", type: PlayerType.localHuman),
          PlayerSlot.slot2: PlayerSetupConfig(name: "Bot", type: PlayerType.localBot),
        },
        localPlayerSlot: PlayerSlot.slot1,
        eventProvider: eventProvider,
      );

      // Set up slot2 (Bot) with 1 token on board at position 5
      final p2Tokens = [
        Token(id: 0, slot: PlayerSlot.slot2, state: TokenState.board, position: 5),
        Token(id: 1, slot: PlayerSlot.slot2, state: TokenState.home, position: 0),
        Token(id: 2, slot: PlayerSlot.slot2, state: TokenState.home, position: 0),
        Token(id: 3, slot: PlayerSlot.slot2, state: TokenState.home, position: 0),
      ];

      final updatedPlayers = controller.state.players.map((p) {
        if (p.slot == PlayerSlot.slot2) {
          return p.copyWith(tokens: p2Tokens);
        }
        return p;
      }).toList();

      controller.state = controller.state.copyWith(
        currentTurn: PlayerSlot.slot2,
        players: updatedPlayers,
        isDiceRolled: false,
      );

      // Trigger bot turn via resume()
      controller.resume();

      // Wait for 200ms thinking time + roll + move animation
      await Future.delayed(const Duration(milliseconds: 1500));

      expect(eventProvider.rollRequestCount, greaterThanOrEqualTo(1),
          reason: "Bot should have automatically requested a roll");
      expect(eventProvider.moveRequestCount, greaterThanOrEqualTo(1),
          reason: "Bot should have automatically requested a move");

      await controller.dispose();
    });
  });
}
