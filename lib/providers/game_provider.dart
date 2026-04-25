import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';

final gameControllerProvider = Provider<GameController>((ref) {
  throw UnimplementedError("GameController must be overridden");
});

final gameStreamProvider = StreamProvider.autoDispose<GameState>(
  (ref) {
    final controller = ref.watch(gameControllerProvider);
    return controller.watchGame();
  },
  dependencies: [gameControllerProvider], // 🔥 THIS LINE FIXES IT
);
