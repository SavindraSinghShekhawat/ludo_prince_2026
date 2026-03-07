import 'dart:async';
import '../../engine/game_engine.dart';
import '../../models/game_state.dart';
import '../../services/audio_service.dart';
import '../ludo_controller.dart';

class AudioControllerListener {
  final GameController controller;
  StreamSubscription<GameState>? _subscription;

  AudioControllerListener(this.controller);

  void start() {
    _subscription = controller.watchGame().listen(_handleStateUpdate);
  }

  void stop() {
    _subscription?.cancel();
  }

  void _handleStateUpdate(GameState state) {
    // If the action hasn't changed, we might still want to play sounds
    // for specific events if they are marked in the state, but usually
    // EngineResult events are better.

    // For now, we rely on the controller notifying us of specific events
    // or we infer from state changes.

    // NOTE: In a more robust system, the GameController could emit
    // a separate stream of EngineEvents.
  }

  /// This can be called by the controller when specific engine events occur
  Future<void> handleEngineEvents(List<EngineEvent> events,
      {int? diceValue}) async {
    for (final event in events) {
      switch (event) {
        case EngineEvent.diceRoll:
          await audioService.playRoll();
          break;
        case EngineEvent.rolledSix:
          await audioService.playSix();
          break;
        case EngineEvent.capture:
          await audioService.playDie();
          break;
        case EngineEvent.finish:
          await audioService.playHome();
          break;
        case EngineEvent.safeSpot:
          await audioService.playSafe();
          break;
        case EngineEvent.tokenExitedBase:
          // We don't play move sound here anymore because performMoveExecution
          // calls onMoveStart(1) for home exit.
          break;
        default:
          break;
      }
    }

    // We removed the generic playMoveSound(1) from here because the controller
    // now explicitly calls playMoveSound(steps) at the start of a move via
    // the onMoveStart hook. This prevents overlapping sounds.
  }

  Future<void> playMoveSound(int steps) async {
    await audioService.playMove(steps);
  }
}
