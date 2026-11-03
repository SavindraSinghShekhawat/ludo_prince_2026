import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/ui/dialogs/ludo_game_over_dialog.dart';
import 'package:ludo_prince/ui/dialogs/friend_game_setup_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameState isPrivate Property & Serialization Tests', () {
    test('GameState defaults isPrivate to false', () {
      final state = GameState(
        gameId: 'game_1',
        players: [],
        turnOrder: [],
        currentTurn: PlayerSlot.slot1,
      );
      expect(state.isPrivate, isFalse);
    });

    test('GameState preserves isPrivate through copyWith', () {
      final state = GameState(
        gameId: 'game_1',
        players: [],
        turnOrder: [],
        currentTurn: PlayerSlot.slot1,
        isPrivate: true,
      );
      expect(state.isPrivate, isTrue);

      final copied = state.copyWith(diceValue: 6);
      expect(copied.isPrivate, isTrue);
      expect(copied.diceValue, 6);

      final toggled = state.copyWith(isPrivate: false);
      expect(toggled.isPrivate, isFalse);
    });

    test('GameState serialization and deserialization retains isPrivate', () {
      final original = GameState(
        gameId: 'private_room_99',
        players: [
          Player(
            slot: PlayerSlot.slot1,
            uid: 'uid_1',
            name: 'Player 1',
            tokens: [Token(id: 0, slot: PlayerSlot.slot1)],
          ),
        ],
        turnOrder: [PlayerSlot.slot1],
        currentTurn: PlayerSlot.slot1,
        gameType: GameType.online,
        isPrivate: true,
      );

      final json = original.toJson();
      expect(json['isPrivate'], isTrue);

      final deserialized = GameState.fromJson(json);
      expect(deserialized.isPrivate, isTrue);
      expect(deserialized.gameId, 'private_room_99');
    });
  });

  group('FriendGameSetupDialog Widget Tests', () {
    testWidgets('Renders header, friends chips, and selectors with 2 players default', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FriendGameSetupDialog(
                title: 'CHALLENGE FRIEND',
                subtitle: 'Challenging Alex',
                targetUids: ['uid_alex'],
                targetNames: ['Alex'],
                initialMaxPlayers: 2,
                initialGameMode: GameMode.classic,
                actionButtonLabel: 'SEND CHALLENGE',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHALLENGE FRIEND'), findsOneWidget);
      expect(find.text('Challenging Alex'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('SELECT NUMBER OF PLAYERS'), findsOneWidget);
      expect(find.text('SELECT GAME MODE'), findsOneWidget);
      expect(find.text('SEND CHALLENGE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets('Toggling player count to 4 players enables Team Mode', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FriendGameSetupDialog(
                title: 'NEW GAME WITH FRIENDS',
                subtitle: 'Re-inviting: Emma, Noah',
                targetUids: ['uid_emma', 'uid_noah'],
                targetNames: ['Emma', 'Noah'],
                initialMaxPlayers: 3,
                initialGameMode: GameMode.classic,
                actionButtonLabel: 'CREATE & INVITE',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find '4 Players' choice chip and tap it
      final fourPlayersChip = find.text('4 Players');
      expect(fourPlayersChip, findsOneWidget);
      await tester.tap(fourPlayersChip);
      await tester.pumpAndSettle();

      // In 4 players, 2vs2 Team mode chip can be tapped
      final teamModeChip = find.text('2vs2 Team');
      expect(teamModeChip, findsOneWidget);
      await tester.tap(teamModeChip);
      await tester.pumpAndSettle();

      // Switching back to '2 Players' resets mode to classic
      final twoPlayersChip = find.text('2 Players');
      await tester.tap(twoPlayersChip);
      await tester.pumpAndSettle();

      expect(find.text('Classic'), findsOneWidget);
    });

    testWidgets('Displays open slots helper notice when maxPlayers exceeds targets + 1', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FriendGameSetupDialog(
                title: 'CHALLENGE FRIEND',
                subtitle: 'Challenging Alex',
                targetUids: ['uid_alex'],
                targetNames: ['Alex'],
                initialMaxPlayers: 4,
                initialGameMode: GameMode.classic,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Room will open with 4 slots. You can invite more friends from the lobby.'),
        findsOneWidget,
      );
    });
  });

  group('LudoGameOverDialog Context-Aware Button Tests', () {
    testWidgets('Displays "Rematch" when game was online and private', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final privateGameState = GameState(
        gameId: 'game_private_1',
        gameType: GameType.online,
        isPrivate: true,
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: 'LocalPlayer',
            tokens: [Token(id: 0, slot: PlayerSlot.slot1)],
          ),
          Player(
            slot: PlayerSlot.slot3,
            uid: 'uid_friend',
            name: 'FriendPlayer',
            tokens: [Token(id: 0, slot: PlayerSlot.slot3)],
          ),
        ],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot3],
        currentTurn: PlayerSlot.slot1,
        winners: [PlayerSlot.slot1, PlayerSlot.slot3],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LudoGameOverDialog(state: privateGameState),
            ),
          ),
        ),
      );
      // Wait for delayed animations (up to 1200ms) to trigger and settle
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('Rematch'), findsOneWidget);
      expect(find.text('New Game'), findsNothing);

      // Settle confetti controller timer (5s)
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Displays "New Game" when game was local or public online', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final localGameState = GameState(
        gameId: 'game_local_1',
        gameType: GameType.local,
        isPrivate: false,
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: 'Local1',
            tokens: [Token(id: 0, slot: PlayerSlot.slot1)],
          ),
          Player(
            slot: PlayerSlot.slot3,
            name: 'Local2',
            tokens: [Token(id: 0, slot: PlayerSlot.slot3)],
          ),
        ],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot3],
        currentTurn: PlayerSlot.slot1,
        winners: [PlayerSlot.slot1, PlayerSlot.slot3],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LudoGameOverDialog(state: localGameState),
            ),
          ),
        ),
      );
      // Wait for delayed animations (up to 1200ms) to trigger and settle
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('New Game'), findsOneWidget);
      expect(find.text('Rematch'), findsNothing);

      // Settle confetti controller timer (5s)
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
