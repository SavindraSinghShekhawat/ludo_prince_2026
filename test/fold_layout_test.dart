import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/ui/screens/ludo_screen.dart';
import 'package:ludo_prince/games/ludo/ui/widgets/board_widget.dart';
import 'package:ludo_prince/providers/game_provider.dart';

class FakeGameController implements GameController {
  final StreamController<GameState> _controller = StreamController<GameState>.broadcast();
  late GameState _state;

  FakeGameController(GameState initialState) {
    _state = initialState;
  }

  @override
  GameState get state => _state;

  @override
  Stream<GameState> watchGame() => _controller.stream;

  @override
  bool get isActionInProgress => false;

  @override
  bool get isDisposed => false;

  @override
  PlayerSlot? get localPlayerSlot => PlayerSlot.slot1;

  @override
  Future<void> sendRollIntent() async {}

  @override
  Future<void> sendMoveIntent(Token token) async {}

  @override
  void sendRollDiceIntent() {}

  @override
  Future<void> executeRoll(int value, {bool fastForward = false}) async {}

  @override
  Future<void> executeMove(int tokenId, {bool fastForward = false}) async {}

  @override
  void quitGame() {}

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  final testState = GameState(
    gameId: "test_fold_game",
    gameMode: GameMode.classic,
    turnOrder: [PlayerSlot.slot1, PlayerSlot.slot2, PlayerSlot.slot3, PlayerSlot.slot4],
    currentTurn: PlayerSlot.slot1,
    diceValue: 6,
    isDiceRolled: false,
    turnStartedAt: null, // No timer
    winners: const [],
    players: [
      Player(
        slot: PlayerSlot.slot1,
        name: "Alice",
        type: PlayerType.localHuman,
        tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot1, state: TokenState.home, position: 0)),
      ),
      Player(
        slot: PlayerSlot.slot2,
        name: "Bob",
        type: PlayerType.localHuman,
        tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot2, state: TokenState.home, position: 0)),
      ),
      Player(
        slot: PlayerSlot.slot3,
        name: "Charlie",
        type: PlayerType.localHuman,
        tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot3, state: TokenState.home, position: 0)),
      ),
      Player(
        slot: PlayerSlot.slot4,
        name: "Diana",
        type: PlayerType.localHuman,
        tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot4, state: TokenState.home, position: 0)),
      ),
    ],
  );

  testWidgets('Check layout positions on Galaxy Z Fold (768 x 900)', (tester) async {
    final fakeController = FakeGameController(testState);
    tester.view.physicalSize = const Size(768, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      fakeController.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameControllerProvider.overrideWithValue(fakeController),
          gameStreamProvider.overrideWith((ref) => Stream.value(testState)),
        ],
        child: const MaterialApp(
          home: LudoScreen(),
        ),
      ),
    );
    await tester.pump();

    final boardRect = tester.getRect(find.byType(BoardWidget));
    print('Board Rect: $boardRect');

    // Check bottom panel finding
    final textAlice = find.text('Alice');
    expect(textAlice, findsOneWidget);
    final aliceRect = tester.getRect(textAlice);
    print('Alice (Bottom Player) Rect: $aliceRect');

    final textDiana = find.text('Diana');
    expect(textDiana, findsOneWidget);
    final dianaRect = tester.getRect(textDiana);
    print('Diana (Top Player) Rect: $dianaRect');

    print('Screen height: 900, Alice bottom: ${aliceRect.bottom}');

    // Dispose widget tree to stop animations
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Check layout positions on Galaxy Z Fold Landscape (900 x 768)', (tester) async {
    final fakeController = FakeGameController(testState);
    tester.view.physicalSize = const Size(900, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      fakeController.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameControllerProvider.overrideWithValue(fakeController),
          gameStreamProvider.overrideWith((ref) => Stream.value(testState)),
        ],
        child: const MaterialApp(
          home: LudoScreen(),
        ),
      ),
    );
    await tester.pump();

    final textAlice = find.text('Alice');
    expect(textAlice, findsOneWidget);
    final aliceRect = tester.getRect(textAlice);
    print('Alice in Landscape Rect: $aliceRect');

    final boardRect = tester.getRect(find.byType(BoardWidget));
    print('Board in Landscape Rect: $boardRect');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Check layout positions on Folded Cover screen (340 x 800)', (tester) async {
    final fakeController = FakeGameController(testState);
    tester.view.physicalSize = const Size(340, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      fakeController.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameControllerProvider.overrideWithValue(fakeController),
          gameStreamProvider.overrideWith((ref) => Stream.value(testState)),
        ],
        child: const MaterialApp(
          home: LudoScreen(),
        ),
      ),
    );
    await tester.pump();

    final textAlice = find.text('Alice');
    expect(textAlice, findsOneWidget);
    final aliceRect = tester.getRect(textAlice);
    print('Alice on Cover Rect: $aliceRect');

    final boardRect = tester.getRect(find.byType(BoardWidget));
    print('Board on Cover Rect: $boardRect');

    // Ensure everything fits within 800px height
    expect(aliceRect.bottom, lessThan(800.0));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Check layout positions on Standard Phone (393 x 852)', (tester) async {
    final fakeController = FakeGameController(testState);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      fakeController.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameControllerProvider.overrideWithValue(fakeController),
          gameStreamProvider.overrideWith((ref) => Stream.value(testState)),
        ],
        child: const MaterialApp(
          home: LudoScreen(),
        ),
      ),
    );
    await tester.pump();

    final textAlice = find.text('Alice');
    expect(textAlice, findsOneWidget);
    final aliceRect = tester.getRect(textAlice);
    print('Alice on Standard Phone Rect: $aliceRect');

    final boardRect = tester.getRect(find.byType(BoardWidget));
    print('Board on Standard Phone Rect: $boardRect');

    expect(aliceRect.bottom, lessThan(852.0));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Check layout positions on Pixel Fold unfolded (840 x 780)', (tester) async {
    final fakeController = FakeGameController(testState);
    tester.view.physicalSize = const Size(840, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      fakeController.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameControllerProvider.overrideWithValue(fakeController),
          gameStreamProvider.overrideWith((ref) => Stream.value(testState)),
        ],
        child: const MaterialApp(
          home: LudoScreen(),
        ),
      ),
    );
    await tester.pump();

    final textAlice = find.text('Alice');
    expect(textAlice, findsOneWidget);
    final aliceRect = tester.getRect(textAlice);
    print('Alice on Pixel Fold Rect: $aliceRect');

    final boardRect = tester.getRect(find.byType(BoardWidget));
    print('Board on Pixel Fold Rect: $boardRect');

    expect(aliceRect.bottom, lessThan(780.0));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
