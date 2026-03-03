import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/game_controller.dart';
import '../models/game_state.dart';

final gameControllerProvider = Provider<GameController>((ref) {
  throw UnimplementedError("GameController must be overridden");
});

final gameStreamProvider = StreamProvider<GameState>(
  (ref) {
    final controller = ref.watch(gameControllerProvider);
    return controller.watchGame();
  },
  dependencies: [gameControllerProvider], // 🔥 THIS LINE FIXES IT
);
