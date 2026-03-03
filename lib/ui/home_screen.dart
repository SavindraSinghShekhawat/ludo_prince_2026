import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/controllers/local_game_controller.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/services/audio_service.dart';
import '../models/token.dart';
import 'ludo_screen.dart';
import 'about_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Ludo Prince',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Local Multiplayer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 50),
              _buildMenuButton(
                context,
                ref,
                title: '2 Players',
                icon: Icons.people,
                colors: [Colors.greenAccent.shade700, Colors.blueAccent],
                numPlayers: 2,
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                ref,
                title: '3 Players',
                icon: Icons.person_add,
                colors: [Colors.redAccent, Colors.blueAccent],
                numPlayers: 3,
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                ref,
                title: '4 Players',
                icon: Icons.groups,
                colors: [Colors.redAccent, Colors.amber.shade600],
                numPlayers: 4,
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
                icon: const Icon(Icons.info_outline, color: Colors.white70),
                label: const Text(
                  'About & Fairness',
                  style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, WidgetRef ref,
      {required String title, required IconData icon, required List<Color> colors, required int numPlayers}) {
    return InkWell(
      onTap: () => _showPlayerNameSetupDialog(context, ref, numPlayers),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlayerNameSetupDialog(BuildContext context, WidgetRef ref, int numPlayers) {
    List<PlayerColor> activeColors;
    if (numPlayers == 2) {
      activeColors = [PlayerColor.blue, PlayerColor.green];
    } else if (numPlayers == 3) {
      activeColors = [PlayerColor.blue, PlayerColor.green, PlayerColor.red];
    } else {
      activeColors = [PlayerColor.blue, PlayerColor.yellow, PlayerColor.green, PlayerColor.red];
    }

    final controllers = <PlayerColor, TextEditingController>{};
    for (int i = 0; i < activeColors.length; i++) {
      controllers[activeColors[i]] = TextEditingController(text: "Player ${i + 1}");
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3D),
          title: const Text('Enter Player Names', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: activeColors.map((color) {
                Color displayColor = Colors.white;
                switch (color) {
                  case PlayerColor.red:
                    displayColor = Colors.redAccent;
                    break;
                  case PlayerColor.green:
                    displayColor = Colors.greenAccent.shade700;
                    break;
                  case PlayerColor.yellow:
                    displayColor = Colors.amber.shade600;
                    break;
                  case PlayerColor.blue:
                    displayColor = Colors.blueAccent;
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    controller: controllers[color],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Player ${activeColors.indexOf(color) + 1}',
                      labelStyle: TextStyle(color: displayColor),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: displayColor.withOpacity(0.5))),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: displayColor, width: 2)),
                      prefixIcon: Icon(Icons.person, color: displayColor),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                Map<PlayerColor, String> config = {};

                for (var color in activeColors) {
                  config[color] =
                      controllers[color]!.text.trim().isEmpty ? "Player ${activeColors.indexOf(color) + 1}" : controllers[color]!.text.trim();
                }

                await audioService.playStart(); // ✅ FIX 3

                Navigator.pop(context);

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => ProviderScope(
                      overrides: [
                        gameControllerProvider.overrideWithValue(
                          LocalGameController(config),
                        ),
                      ],
                      child: const LudoScreen(),
                    ),
                  ),
                );
              },
              child: const Text(
                'Start Game',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          ],
        );
      },
    );
  }
}
