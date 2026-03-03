import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/token.dart';
import '../providers/game_provider.dart';
import '../controllers/local_game_controller.dart';
import 'home_screen.dart';
import 'ludo_screen.dart';

class GameOverDialog extends StatelessWidget {
  final GameState state;

  const GameOverDialog({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Game Over!",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  shadows: [
                    Shadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(2, 2))
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(state.winners.length, (index) {
                final playerSlot = state.winners[index];
                final player =
                    state.players.firstWhere((p) => p.slot == playerSlot);
                final place = index + 1;
                final isLast = place == state.winners.length;

                Color placeColor = Colors.white;
                String placeText = "#$place";
                IconData? placeIcon;

                if (place == 1) {
                  placeColor = Colors.amber;
                  placeText = "1st";
                  placeIcon = Icons.emoji_events;
                } else if (place == 2) {
                  placeColor = Colors.grey.shade300;
                  placeText = "2nd";
                  placeIcon = Icons.military_tech;
                } else if (place == 3) {
                  placeColor = Colors.brown.shade400;
                  placeText = "3rd";
                  placeIcon = Icons.military_tech;
                }

                if (isLast) {
                  placeColor = Colors.redAccent.shade200;
                  placeText = "Last";
                  placeIcon = Icons.sentiment_very_dissatisfied;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: place == 1
                        ? Colors.amber.withOpacity(0.1)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: placeColor.withOpacity(0.5),
                        width: place == 1 ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          placeText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: placeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          player.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                                place == 1 ? FontWeight.bold : FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (placeIcon != null) ...[
                        Icon(placeIcon, color: placeColor, size: 28),
                      ]
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home, color: Colors.white),
                      label: const Text('Home',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Exact same specs
                        Map<PlayerSlot, PlayerSetupConfig> config = {};
                        for (var player in state.players) {
                          config[player.slot] = PlayerSetupConfig(
                            name: player.name,
                            isBot: player.isBot,
                          );
                        }

                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => ProviderScope(
                              overrides: [
                                gameControllerProvider.overrideWithValue(
                                    LocalGameController(config)),
                              ],
                              child: const LudoScreen(),
                            ),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.replay, color: Colors.white),
                      label: const Text('Replay',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
