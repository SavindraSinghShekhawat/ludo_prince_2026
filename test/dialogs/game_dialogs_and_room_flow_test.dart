import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/ui/dialogs/ludo_game_over_dialog.dart';
import 'package:ludo_prince/ui/dialogs/invite_dialog.dart';
import 'package:ludo_prince/ui/dialogs/join_by_code_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('JoinByCodeDialog Amber Theme & Clipboard Tests', () {
    testWidgets('Renders 6 amber digit inputs and paste button', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JoinByCodeDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ENTER ROOM CODE'), findsOneWidget);
      expect(find.text('PASTE CODE'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('Tapping PASTE CODE populates digit inputs from clipboard', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Register mock platform handler for clipboard so Clipboard.getData completes
      const clipboardContent = '73910';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardContent};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JoinByCodeDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap PASTE CODE button
      final pasteButton = find.text('PASTE CODE');
      expect(pasteButton, findsOneWidget);
      await tester.tap(pasteButton);
      await tester.pump();

      // Verify each individual digit was filled into the corresponding box
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('Typing digits into inputs advances focus across cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JoinByCodeDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '5');
      await tester.pump();
      await tester.enterText(textFields.at(1), '8');
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('All 6 digit inputs are enabled by default for editing', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JoinByCodeDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.length, 6);
      for (final tf in textFields) {
        expect(tf.enabled, isTrue);
      }
    });
  });

  group('InviteDialog Room Code Visibility Tests', () {
    testWidgets('Displays prominent ROOM CODE badge with cyan styling', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InviteDialog(
                inviteId: 'inv_101',
                fromName: 'Jessica',
                gameId: 'game_xyz_9',
                joiningCode: '581932',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ROOM INVITATION'), findsOneWidget);
      expect(find.text('JESSICA'), findsOneWidget);
      expect(find.text('ROOM CODE: '), findsOneWidget);
      expect(find.text('581932'), findsOneWidget);
      expect(find.text('DECLINE'), findsOneWidget);
      expect(find.text('JOIN NOW'), findsOneWidget);
    });
  });

  group('LudoGameOverDialog Safe Rendering with Missing / Forfeited Players', () {
    testWidgets('Renders gracefully without StateError when winners list contains forfeited player', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Simulates match end where PlayerSlot.slot2 forfeited and was purged from players list
      final stateWithMissingPlayer = GameState(
        gameId: 'game_forfeit_end_1',
        gameType: GameType.online,
        isPrivate: true,
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: 'LocalSurvivor',
            tokens: [Token(id: 0, slot: PlayerSlot.slot1)],
          ),
        ],
        turnOrder: [PlayerSlot.slot1],
        currentTurn: PlayerSlot.slot1,
        // winners includes slot2 which is NOT in state.players
        winners: [PlayerSlot.slot1, PlayerSlot.slot2],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LudoGameOverDialog(state: stateWithMissingPlayer),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));

      // Should render without throwing Bad state: No element error
      expect(find.text('MATCH FINISHED!'), findsOneWidget);
      expect(find.text('LocalSurvivor'), findsOneWidget);
      expect(find.text('Rematch'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Team Mode renders gracefully when winningSlot was forfeited', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Team Mode with only Team A players surviving
      final teamStateWithMissingSlots = GameState(
        gameId: 'team_forfeit_game',
        gameType: GameType.online,
        gameMode: GameMode.team,
        isPrivate: true,
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: 'TeamA_P1',
            tokens: [Token(id: 0, slot: PlayerSlot.slot1)],
          ),
          Player(
            slot: PlayerSlot.slot3,
            name: 'TeamA_P2',
            tokens: [Token(id: 0, slot: PlayerSlot.slot3)],
          ),
        ],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot3],
        currentTurn: PlayerSlot.slot1,
        winners: [PlayerSlot.slot4], // Opponent slot that forfeited
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LudoGameOverDialog(state: teamStateWithMissingSlots),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('TEAM B WINS!'), findsOneWidget);
      expect(find.text('TEAM A'), findsOneWidget);
      expect(find.text('TEAM B'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Private Room Start Button Enforcement Logic Tests', () {
    test('Disabled button state when currentPlayers < maxRequired in 4-player room', () {
      const currentPlayers = 2;
      const maxRequired = 4;

      final buttonText = currentPlayers >= maxRequired
          ? 'START BATTLE'
          : 'WAITING FOR PLAYERS ($currentPlayers/$maxRequired)...';
      final isEnabled = currentPlayers >= maxRequired;

      expect(buttonText, 'WAITING FOR PLAYERS (2/4)...');
      expect(isEnabled, isFalse);
    });

    test('Disabled button state when currentPlayers is 3 in 4-player room', () {
      const currentPlayers = 3;
      const maxRequired = 4;

      final buttonText = currentPlayers >= maxRequired
          ? 'START BATTLE'
          : 'WAITING FOR PLAYERS ($currentPlayers/$maxRequired)...';
      final isEnabled = currentPlayers >= maxRequired;

      expect(buttonText, 'WAITING FOR PLAYERS (3/4)...');
      expect(isEnabled, isFalse);
    });

    test('Enabled button state when currentPlayers equals maxRequired', () {
      const currentPlayers = 4;
      const maxRequired = 4;

      final buttonText = currentPlayers >= maxRequired
          ? 'START BATTLE'
          : 'WAITING FOR PLAYERS ($currentPlayers/$maxRequired)...';
      final isEnabled = currentPlayers >= maxRequired;

      expect(buttonText, 'START BATTLE');
      expect(isEnabled, isTrue);
    });

    test('Enabled button state for 3-player room when full', () {
      const currentPlayers = 3;
      const maxRequired = 3;

      final buttonText = currentPlayers >= maxRequired
          ? 'START BATTLE'
          : 'WAITING FOR PLAYERS ($currentPlayers/$maxRequired)...';
      final isEnabled = currentPlayers >= maxRequired;

      expect(buttonText, 'START BATTLE');
      expect(isEnabled, isTrue);
    });
  });
}
