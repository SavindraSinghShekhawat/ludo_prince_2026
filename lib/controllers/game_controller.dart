import '../models/game_state.dart';
import '../models/token.dart';

abstract class GameController {
  Stream<GameState> watchGame();

  PlayerSlot? get localPlayerSlot;
  bool get isActionInProgress;

  // 1. Intents (called by the UI when a user taps something)
  // These represent the user's desire to act.
  Future<void> sendRollIntent();
  Future<void> sendMoveIntent(Token token);

  // 2. Executions (Apply the action to the state with animations/effects)
  // These are called after an intent is validated or received from a server.
  Future<void> executeRoll(int value);
  Future<void> executeMove(int tokenId);

  // 3. Status
  void pause();
  void resume();
  Future<void> dispose();
}
