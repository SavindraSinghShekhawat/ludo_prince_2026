import 'dart:async';
import '../models/game_state.dart';
import '../models/token.dart';
import '../engine/game_engine.dart';

/// A mixin that provides shared execution logic for game moves and rolls.
/// This includes the step-by-step animation logic which is shared between
/// local and online controllers.
mixin GameExecutionMixin {
  GameEngine get engine;
  GameState get state;
  set state(GameState newState);

  bool get isDisposed;
  StreamController<GameState> get streamController;

  void onEngineEvents(List<EngineEvent> events);
  void onMoveStart(int steps);

  Future<void> performMoveExecution(int tokenId) async {
    if (!state.isDiceRolled) return;

    final player = state.players.firstWhere((p) => p.slot == state.currentTurn);
    final token = player.tokens.firstWhere((t) => t.id == tokenId);

    if (token.slot != state.currentTurn) return;
    if (!engine.isValidMove(token, state.diceValue)) return;

    try {
      int steps = state.diceValue;
      List<EngineEvent> accumulatedEvents = [];

      // 1. Home exit case
      if (token.state == TokenState.home && steps == 6) {
        onMoveStart(1); // Home exit is always 1 step highlight

        Token updated = token.copyWith(
          state: TokenState.board,
          position: 0,
        );

        final result = engine.applyStep(state, updated);
        state = result.state;
        accumulatedEvents.addAll(result.events);
        onEngineEvents(result.events);

        if (!isDisposed) streamController.add(state);

        _finalizeAfterMove(updated.id, accumulatedEvents);
        return;
      }

      onMoveStart(steps);
      Token currentToken = token;

      // 2. Intermediate steps
      for (int i = 0; i < steps - 1; i++) {
        currentToken = engine.advanceOneStep(currentToken);

        final result = engine.applyStep(
          state,
          currentToken,
          allowCapture: false,
        );
        state = result.state;
        accumulatedEvents.addAll(result.events);
        onEngineEvents(result.events);

        if (!isDisposed) streamController.add(state);

        await Future.delayed(const Duration(milliseconds: 150));
      }

      // 3. Final step
      currentToken = engine.advanceOneStep(currentToken);

      final result = engine.applyStep(
        state,
        currentToken,
        allowCapture: true,
      );
      state = result.state;
      accumulatedEvents.addAll(result.events);
      onEngineEvents(result.events);

      if (!isDisposed) streamController.add(state);

      _finalizeAfterMove(currentToken.id, accumulatedEvents);
    } catch (e) {
      // Log or handle error
    }
  }

  void _finalizeAfterMove(int tokenId, List<EngineEvent> events) {
    final result = engine.moveToken(state, tokenId,
        captured: events.contains(EngineEvent.capture));
    state = result.state;

    GameAction action = GameAction.move;

    if (events.contains(EngineEvent.capture)) {
      action = GameAction.capture;
    } else {
      final currentPlayer =
          state.players.firstWhere((p) => p.slot == state.currentTurn);
      final token = currentPlayer.tokens.firstWhere((t) => t.id == tokenId);

      if (token.state == TokenState.finished) {
        action = GameAction.finish;
      }
    }

    state = state.copyWith(lastAction: action);
    if (!isDisposed) streamController.add(state);
  }
}
