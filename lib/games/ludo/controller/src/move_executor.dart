import 'dart:async';
import 'package:ludo_prince/games/ludo/domain/engine/game_engine.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/utils/app_logger.dart';

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

  Future<void> execute(GameState state, int tokenId, int diceValue,
      {bool fastForward = false, PlayerSlot? playerSlot}) async {
    try {
      final targetSlot = playerSlot ?? state.currentTurn;
      final player = state.players.firstWhere(
        (p) => p.slot == targetSlot,
        orElse: () => state.players.firstWhere(
          (p) => p.tokens.any((t) => t.id == tokenId),
          orElse: () => state.players.first,
        ),
      );
      final token = player.tokens.firstWhere(
        (t) => t.id == tokenId,
        orElse: () => player.tokens.first,
      );

      int steps = diceValue;
      List<EngineEvent> accumulatedEvents = [];
      GameState currentState = state;

      // 1. Home exit case
      final bool canExitHome = token.state == TokenState.home &&
          (steps == 6 || (state.rules.openOnOneAndSix && steps == 1));
      if (canExitHome) {
        if (!fastForward) onMoveStart(1);

        Token updated = token.copyWith(state: TokenState.board, position: 0);

        final result = engine.applyStep(currentState, updated);
        currentState = result.state;
        accumulatedEvents.addAll(result.events);
        if (!fastForward) onEngineEvents(result.events);

        onStateUpdate(currentState);

        _finalizeAfterMove(currentState, updated.id, accumulatedEvents);
        return;
      }

      if (!fastForward) onMoveStart(steps);
      Token currentToken = token;

      // 2. Intermediate steps (no audio — only accumulate events for final step)
      for (int i = 0; i < steps - 1; i++) {
        currentToken = engine.advanceOneStep(currentToken);

        final result = engine.applyStep(
          currentState,
          currentToken,
          allowCapture: false,
        );
        currentState = result.state;
        accumulatedEvents.addAll(result.events);

        onStateUpdate(currentState);

        if (isDisposed()) return;
        if (!fastForward) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
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
      if (!fastForward) onEngineEvents(result.events);

      onStateUpdate(currentState);

      _finalizeAfterMove(currentState, currentToken.id, accumulatedEvents);
    } catch (e, st) {
      AppLogger.error('[MoveExecutor] Error during move execution: $e', st);
      // Failsafe recovery: unlock state to prevent freezing game loop
      final safeState = state.copyWith(isDiceRolled: false);
      onStateUpdate(safeState);
    }
  }

  void _finalizeAfterMove(
    GameState state,
    int tokenId,
    List<EngineEvent> events,
  ) {
    final result = engine.moveToken(
      state,
      tokenId,
      captured: events.contains(EngineEvent.capture),
    );
    GameState finalState = result.state;

    GameAction action = GameAction.move;

    if (events.contains(EngineEvent.capture)) {
      action = GameAction.capture;
    } else {
      final currentPlayer = finalState.players.firstWhere(
        (p) => p.slot == finalState.currentTurn,
      );
      final token = currentPlayer.tokens.firstWhere((t) => t.id == tokenId);

      if (token.state == TokenState.finished) {
        action = GameAction.finish;
      }
    }

    finalState = finalState.copyWith(lastAction: action);
    onStateUpdate(finalState);
  }
}
