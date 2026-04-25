import 'package:flutter/material.dart';
import 'package:ludo_prince/core/game_definition.dart';

import 'package:ludo_prince/games/ludo/ui/screens/ludo_screen.dart';

/// Ludo game module — the first (and currently only) registered game.
class LudoGameDefinition extends GameDefinition {
  @override
  String get gameId => 'ludo';

  @override
  String get displayName => 'Ludo Prince';

  @override
  String get description => 'The Classic Board Game';

  @override
  IconData get icon => Icons.casino_outlined;

  @override
  Color get accentColor => const Color(0xFF00D1FF);

  @override
  List<int> get supportedPlayerCounts => [2, 3, 4];

  @override
  List<String> get supportedModes => ['classic', 'team'];

  @override
  bool get isAvailable => true;

  @override
  Widget buildGameScreen({
    required String sessionId,
    required bool isOnline,
  }) {
    return const LudoScreen();
  }

  @override
  Widget buildBoardPreview() {
    return const Icon(Icons.grid_4x4, size: 48);
  }
}
