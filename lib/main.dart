import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'startup/app_initializer.dart';
import 'core/game_registry.dart';
import 'games/ludo/ludo_game_definition.dart';
import 'app.dart';

void main() async {
  final hasSeenOnboarding = await AppInitializer.init();

  // Register all game modules
  GameRegistry.register(LudoGameDefinition());

  runApp(
    ProviderScope(child: LudoPrinceApp(hasSeenOnboarding: hasSeenOnboarding)),
  );
}
