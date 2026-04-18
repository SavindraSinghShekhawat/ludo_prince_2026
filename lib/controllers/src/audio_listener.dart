import 'dart:async';
import '../../engine/game_engine.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../services/audio_service.dart';
import '../ludo_controller.dart';

class AudioControllerListener {
  final GameController controller;
  StreamSubscription<GameState>? _subscription;
  bool _wasWaitingForResult = false;

  AudioControllerListener(this.controller);

  void start() {
    _subscription = controller.watchGame().listen(_handleStateUpdate);
  }

  void stop() {
    _subscription?.cancel();
  }

  void _handleStateUpdate(GameState state) {
    if (state.isWaitingForResult && !_wasWaitingForResult) {
      // Trigger the crisp roll sound immediately at the start of the animation
      audioService.playRoll();
    }
    _wasWaitingForResult = state.isWaitingForResult;
  }

  /// This can be called by the controller when specific engine events occur
  Future<void> handleEngineEvents(
    List<EngineEvent> events, {
    int? diceValue,
  }) async {
    if (controller.isDisposed) return;

    // Safety: don't play sounds if the current player has already left
    // or game is over, unless it's a specific game-over sound.
    final state = controller.state;
    final currentPlayer = state.players
        .where((p) => p.slot == state.currentTurn)
        .firstOrNull;

    if (currentPlayer?.status == PlayerStatus.left &&
        !events.contains(EngineEvent.quit)) {
      return;
    }

    for (final event in events) {
      switch (event) {
        case EngineEvent.diceRoll:
          // Dice roll sound is now handled explicitly at the start of animation
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
    if (controller.isDisposed) return;
    await audioService.playMove(steps);
  }

  Future<void> playRollSound() async {
    if (controller.isDisposed) return;
    await audioService.playRoll();
  }
}
