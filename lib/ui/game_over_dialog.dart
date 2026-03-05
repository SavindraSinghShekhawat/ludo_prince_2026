import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';

import '../models/game_state.dart';
import '../models/token.dart';
import '../providers/game_provider.dart';
import '../controllers/local_game_controller.dart';
import '../services/audio_service.dart';
import 'home_screen.dart';
import 'ludo_screen.dart';

class GameOverDialog extends ConsumerStatefulWidget {
  final GameState state;

  const GameOverDialog({
    super.key,
    required this.state,
  });

  @override
  ConsumerState<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends ConsumerState<GameOverDialog> {
  late ConfettiController _confettiController;

  Color _getPlayerColor(PlayerSlot pSlot) {
    switch (pSlot) {
      case PlayerSlot.slot1:
        return Colors.red;
      case PlayerSlot.slot2:
        return Colors.green;
      case PlayerSlot.slot3:
        return Colors.amber;
      case PlayerSlot.slot4:
        return Colors.blue;
    }
  }

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));
    _confettiController.play();
    audioService.playVictory();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A3D), Color(0xFF1E1E2C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                    color: const Color(0xFFE5E4E2).withValues(alpha: 0.8),
                    width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE5E4E2).withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Celebration Header
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFE5E4E2),
                    size: 80,
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 2000.ms)
                      .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.1, 1.1),
                          duration: 1000.ms,
                          curve: Curves.easeInOutSine)
                      .then()
                      .scale(
                          begin: const Offset(1.1, 1.1),
                          end: const Offset(0.8, 0.8),
                          duration: 1000.ms,
                          curve: Curves.easeInOutSine),
                  const SizedBox(height: 16),
                  const Text(
                    "VICTORY!",
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE5E4E2),
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 10,
                          offset: Offset(3, 3),
                        )
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.5),
                  const SizedBox(height: 32),

                  // Rankings
                  ...List.generate(widget.state.winners.length, (index) {
                    final playerSlot = widget.state.winners[index];
                    final player = widget.state.players
                        .firstWhere((p) => p.slot == playerSlot);
                    final place = index + 1;
                    final isLast = place == widget.state.winners.length;

                    Color placeColor = Colors.white;
                    String placeText = "#$place";
                    IconData? placeIcon;

                    if (place == 1) {
                      placeColor = const Color(0xFFE5E4E2);
                      placeText = "1st";
                      placeIcon = Icons.star;
                    } else if (place == 2) {
                      placeColor = const Color(0xFFB0B4B8);
                      placeText = "2nd";
                      placeIcon = Icons.military_tech;
                    } else if (place == 3) {
                      placeColor = const Color(0xFF8A8D91);
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: place == 1
                            ? const Color(0xFFE5E4E2).withValues(alpha: 0.15)
                            : Colors.black38,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: placeColor.withValues(alpha: 0.6),
                            width: place == 1 ? 2.5 : 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              placeText,
                              style: TextStyle(
                                fontSize: place == 1 ? 24 : 18,
                                fontWeight: FontWeight.w900,
                                color: placeColor,
                              ),
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getPlayerColor(playerSlot),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _getPlayerColor(playerSlot)
                                      .withValues(alpha: 0.8),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              player.name,
                              style: TextStyle(
                                fontSize: place == 1 ? 20 : 18,
                                fontWeight: place == 1
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (placeIcon != null) ...[
                            const SizedBox(width: 8),
                            Icon(placeIcon,
                                    color: placeColor,
                                    size: place == 1 ? 28 : 24)
                                .animate(target: place == 1 ? 1 : 0)
                                .scale(
                                    duration: 800.ms, curve: Curves.elasticOut)
                                .shimmer(duration: 1500.ms, delay: 800.ms),
                          ]
                        ],
                      ),
                    )
                        .animate(delay: (200 * index).ms)
                        .fadeIn(duration: 500.ms)
                        .slideX(begin: 0.5);
                  }),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const HomeScreen()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.home_filled,
                              color: Color(0xFF1E1E2C)),
                          label: const Text('Home',
                              style: TextStyle(
                                  color: Color(0xFF1E1E2C),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE5E4E2),
                            foregroundColor: const Color(0xFF1E1E2C),
                            elevation: 5,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ).animate().fadeIn(delay: 1000.ms).moveY(begin: 20),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Exact same specs
                            Map<PlayerSlot, PlayerSetupConfig> config = {};
                            for (var player in widget.state.players) {
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
                          icon: const Icon(Icons.replay_circle_filled,
                              color: Colors.white),
                          label: const Text('Replay',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.shade700,
                            elevation: 5,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ).animate().fadeIn(delay: 1200.ms).moveY(begin: 20),
                    ],
                  ),
                ],
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          ),

          // Confetti exactly centered at the top
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // fall straight down
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.2,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.amber
              ],
            ),
          ),
        ],
      ),
    );
  }
}
