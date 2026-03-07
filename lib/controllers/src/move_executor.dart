import 'dart:async';
import '../../engine/game_engine.dart';
import '../../models/game_state.dart';
import '../../models/token.dart';

class MoveExecutor {
  final GameEngine engine;
  final Function(GameState) onStateUpdate;
  final Function(int) onMoveStart;
  final Function(List<EngineEvent>) onEngineEvents;
  final bool Function() isDisposed;

  MoveExecutor({
    required this.engine,
    required this.onStateUpdate,
    required this.onMoveStart,
    required this.onEngineEvents,
    required this.isDisposed,
  });

  Future<void> execute(GameState state, int tokenId, int diceValue) async {
    final player = state.players.firstWhere((p) => p.slot == state.currentTurn);
    final token = player.tokens.firstWhere((t) => t.id == tokenId);

    try {
      int steps = diceValue;
      List<EngineEvent> accumulatedEvents = [];
      GameState currentState = state;

      // 1. Home exit case
      if (token.state == TokenState.home && steps == 6) {
        onMoveStart(1);

        Token updated = token.copyWith(
          state: TokenState.board,
          position: 0,
        );

        final result = engine.applyStep(currentState, updated);
        currentState = result.state;
        accumulatedEvents.addAll(result.events);
        onEngineEvents(result.events);

        onStateUpdate(currentState);

        _finalizeAfterMove(currentState, updated.id, accumulatedEvents);
        return;
      }

      onMoveStart(steps);
      Token currentToken = token;

      // 2. Intermediate steps
      for (int i = 0; i < steps - 1; i++) {
        currentToken = engine.advanceOneStep(currentToken);

        final result = engine.applyStep(
          currentState,
          currentToken,
          allowCapture: false,
        );
        currentState = result.state;
        accumulatedEvents.addAll(result.events);
        onEngineEvents(result.events);

        onStateUpdate(currentState);

        if (isDisposed()) return;
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // 3. Final step
      currentToken = engine.advanceOneStep(currentToken);

      final result = engine.applyStep(
        currentState,
        currentToken,
        allowCapture: true,
      );
      currentState = result.state;
      accumulatedEvents.addAll(result.events);
      onEngineEvents(result.events);

      onStateUpdate(currentState);

      _finalizeAfterMove(currentState, currentToken.id, accumulatedEvents);
    } catch (e) {
      // Log or handle error
    }
  }

  void _finalizeAfterMove(
      GameState state, int tokenId, List<EngineEvent> events) {
    final result = engine.moveToken(state, tokenId,
        captured: events.contains(EngineEvent.capture));
    GameState finalState = result.state;

    GameAction action = GameAction.move;

    if (events.contains(EngineEvent.capture)) {
      action = GameAction.capture;
    } else {
      final currentPlayer = finalState.players
          .firstWhere((p) => p.slot == finalState.currentTurn);
      final token = currentPlayer.tokens.firstWhere((t) => t.id == tokenId);

      if (token.state == TokenState.finished) {
        action = GameAction.finish;
      }
    }

    finalState = finalState.copyWith(lastAction: action);
    onStateUpdate(finalState);
  }
}
