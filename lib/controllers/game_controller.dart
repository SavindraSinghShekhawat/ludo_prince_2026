import '../models/game_state.dart';
import '../models/token.dart';

abstract class GameController {
  Stream<GameState> watchGame();
  Future<void> rollDice();
  Future<void> moveToken(Token token);
  Future<void> dispose();
}