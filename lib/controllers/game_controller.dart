import '../models/game_state.dart';
import '../models/token.dart';

abstract class GameController {
  Stream<GameState> watchGame();

  // 1. Intents (called by the UI when a user taps something)
  Future<void> sendRollIntent();
  Future<void> sendMoveIntent(Token token);

  // 2. Executions (called internally or by Firestore listeners)
  Future<void> executeRoll(int value);
  Future<void> executeMove(int tokenId);

  void pause();
  void resume();

  Future<void> dispose();
}
