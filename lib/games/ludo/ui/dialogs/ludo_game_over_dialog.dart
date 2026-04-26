import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/ui/widgets/shared_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';

import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/ui/screens/home_screen.dart';
import 'package:ludo_prince/games/ludo/ui/screens/ludo_screen.dart';
import 'package:ludo_prince/ui/screens/lobby_screen.dart';

class LudoGameOverDialog extends ConsumerStatefulWidget {
  final GameState state;

  const LudoGameOverDialog({super.key, required this.state});

  @override
  ConsumerState<LudoGameOverDialog> createState() => _LudoGameOverDialogState();
}

class TeamResult {
  final String name;
  final List<PlayerSlot> slots;
  final List<Player> players;
  final bool isWinner;

  TeamResult({
    required this.name,
    required this.slots,
    required this.players,
    required this.isWinner,
  });
}

class _LudoGameOverDialogState extends ConsumerState<LudoGameOverDialog> {
  late ConfettiController _confettiController;

  Color _getPlayerColor(PlayerSlot pSlot) {
    return AppColors.getUiColorForSlot(pSlot);
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );
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
    final bool isTeamMode = widget.state.gameMode == GameMode.team;

    final bool hasBots = widget.state.players.any(
      (p) => p.type == PlayerType.localBot || p.type == PlayerType.remoteBot,
    );
    final bool hasHumans = widget.state.players.any(
      (p) =>
          p.type == PlayerType.localHuman || p.type == PlayerType.remoteHuman,
    );

    final List<PlayerSlot> humanWinners = widget.state.winners.where((slot) {
      final p = widget.state.players.firstWhere((p) => p.slot == slot);
      return p.type == PlayerType.localHuman ||
          p.type == PlayerType.remoteHuman;
    }).toList();

    final bool isAllHuman = hasHumans && !hasBots;
    final bool isAllBots = hasBots && !hasHumans;

    final int bestHumanRank = humanWinners.isNotEmpty
        ? widget.state.winners.indexOf(humanWinners.first) + 1
        : -1;
    final bool noHumanFinished = bestHumanRank == -1;

    // 2. Determine UX State based on logic
    String headerText;
    Color headerColor;
    IconData headerIcon;

    if (isTeamMode) {
      final winningSlot = widget.state.winners.first;
      final bool isTeamAWinner =
          winningSlot == PlayerSlot.slot1 || winningSlot == PlayerSlot.slot3;
      headerText = isTeamAWinner ? "TEAM A WINS!" : "TEAM B WINS!";
      headerColor = const Color(0xFFE5E4E2); // Platinum
      headerIcon = Icons.emoji_events;
    } else if (isAllHuman || isAllBots) {
      headerText = "MATCH FINISHED!";
      headerColor = const Color(0xFFE5E4E2);
      headerIcon = Icons.emoji_events;
    } else {
      // Mixed or AI
      if (bestHumanRank == 1) {
        headerText = "GRAND VICTORY!";
        headerColor = const Color(0xFFE5E4E2); // Platinum
        headerIcon = Icons.emoji_events;
      } else if (bestHumanRank == 2 || bestHumanRank == 3) {
        headerText = "WELL PLAYED!";
        headerColor = const Color(0xFFB0B4B8); // Silver
        headerIcon = Icons.workspace_premium; // Ribbon
      } else {
        headerText = "GAME OVER";
        headerColor = Colors.redAccent.shade200;
        headerIcon = Icons.videogame_asset_off;
      }
    }

    // 3. Control Sound/Confetti
    bool shouldCelebrate =
        isAllHuman || isAllBots || (!noHumanFinished && bestHumanRank <= 3);

    if (isTeamMode) {
      // In team mode, celebrate if a human team won or if it's all bots/humans
      shouldCelebrate = true;
    }

    if (!shouldCelebrate &&
        _confettiController.state == ConfettiControllerState.playing) {
      _confettiController.stop();
    }

    return PopScope(
      canPop: false,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          AppDialogLayout(
            showHeaderDivider: false,
            header: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(headerIcon, color: headerColor, size: 80)
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 2000.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.05, 1.05),
                      duration: 1500.ms,
                      curve: Curves.easeInOutSine,
                    )
                    .then()
                    .scale(
                      begin: const Offset(1.05, 1.05),
                      end: const Offset(0.8, 0.8),
                      duration: 1500.ms,
                      curve: Curves.easeInOutSine,
                    ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: headerColor == const Color(0xFFE5E4E2)
                        ? const [
                            Color(0xFFE5E4E2),
                            Color(0xFFFFFFFF),
                            Color(0xFFA0A0A0),
                            Color(0xFFE5E4E2),
                          ]
                        : [headerColor.withValues(alpha: 0.6), headerColor],
                    stops: const [0.0, 0.4, 0.6, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    headerText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.5),
                const SizedBox(height: 8),
                Text(
                  widget.state.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: headerColor.withValues(alpha: 0.8),
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
            body: isTeamMode ? _buildTeamBody() : _buildClassicBody(),
            scrollFooter: true,
            footer: Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5E4E2),
                    foregroundColor: const Color(0xFF1E1E2C),
                    elevation: 6,
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Icon(Icons.home_filled, size: 28),
                ).animate().fadeIn(delay: 1000.ms).moveY(begin: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.state.gameType == GameType.online) {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                const LobbyScreen(isQuickMatch: true),
                          ),
                        );
                      } else {
                        Map<PlayerSlot, PlayerSetupConfig> config = {};
                        for (var player in widget.state.players) {
                          config[player.slot] = PlayerSetupConfig(
                            name: player.name,
                            type: player.type,
                          );
                        }

                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => ProviderScope(
                              overrides: [
                                gameControllerProvider.overrideWithValue(
                                  LudoController(config),
                                ),
                              ],
                              child: const LudoScreen(),
                            ),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    label: const Text(
                      'New Game',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade700,
                      elevation: 6,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1200.ms).moveY(begin: 20),
                ),
              ],
            ),
          ),

          // Confetti exactly centered at the top (only if human deserved it)
          if (shouldCelebrate)
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
                  Colors.amber,
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildClassicBody() {
    return List.generate(widget.state.winners.length, (index) {
      final playerSlot = widget.state.winners[index];
      final player = widget.state.players.firstWhere(
        (p) => p.slot == playerSlot,
      );
      final place = index + 1;
      final isLast = place == widget.state.winners.length;

      Color placeColor = Colors.white;
      String placeText = "#$place";
      IconData? placeIcon;

      if (place == 1) {
        placeColor = const Color(0xFFE5E4E2);
        placeText = "1st";
        placeIcon = Icons.emoji_events;
      } else if (place == 2) {
        placeColor = const Color(0xFFB0B4B8);
        placeText = "2nd";
        placeIcon = Icons.workspace_premium;
      } else if (place == 3) {
        placeColor = const Color(0xFF8A8D91);
        placeText = "3rd";
        placeIcon = Icons.workspace_premium;
      }

      if (isLast) {
        placeColor = Colors.redAccent.shade200;
        placeText = "Last";
        placeIcon = Icons.sentiment_very_dissatisfied;
      }

      return _buildPlayerRow(
        player: player,
        index: index,
        isWinner: place == 1,
        placeText: placeText,
        placeColor: placeColor,
        placeIcon: placeIcon,
      );
    });
  }

  List<Widget> _buildTeamBody() {
    final teamASlots = [PlayerSlot.slot1, PlayerSlot.slot3];
    final teamBSlots = [PlayerSlot.slot2, PlayerSlot.slot4];

    final winningSlot = widget.state.winners.first;
    final bool isTeamAWinner = teamASlots.contains(winningSlot);

    final List<TeamResult> teams = [
      TeamResult(
        name: "TEAM A",
        slots: teamASlots,
        players: widget.state.players
            .where((p) => teamASlots.contains(p.slot))
            .toList(),
        isWinner: isTeamAWinner,
      ),
      TeamResult(
        name: "TEAM B",
        slots: teamBSlots,
        players: widget.state.players
            .where((p) => teamBSlots.contains(p.slot))
            .toList(),
        isWinner: !isTeamAWinner,
      ),
    ];

    // Sort to put winner first
    teams.sort((a, b) => b.isWinner ? 1 : -1);

    List<Widget> children = [];
    for (int i = 0; i < teams.length; i++) {
      final team = teams[i];
      final Color teamColor =
          team.isWinner ? const Color(0xFFE5E4E2) : Colors.redAccent.shade200;

      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: 12, top: i == 0 ? 0 : 16),
          child: Row(
            children: [
              Text(
                team.name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        teamColor.withValues(alpha: 0.4),
                        teamColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: (300 * i).ms).fadeIn().slideX(begin: -0.1),
      );

      for (int pIdx = 0; pIdx < team.players.length; pIdx++) {
        final player = team.players[pIdx];
        children.add(
          _buildPlayerRow(
            player: player,
            index: (i * 2) + pIdx,
            isWinner: team.isWinner,
            placeText: team.isWinner ? "Won" : "Lost",
            placeColor: teamColor,
            placeIcon: team.isWinner ? Icons.emoji_events : null,
            showTextAtEnd: true,
          ),
        );
      }
    }

    return children;
  }

  Widget _buildPlayerRow({
    required Player player,
    required int index,
    required bool isWinner,
    required String placeText,
    required Color placeColor,
    IconData? placeIcon,
    bool showTextAtEnd = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isWinner
            ? const Color(0xFFE5E4E2).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: placeColor.withValues(alpha: 0.2),
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (!showTextAtEnd)
            Container(
              width: 50,
              alignment: Alignment.center,
              child: Text(
                placeText,
                style: TextStyle(
                  fontSize: isWinner ? 16 : 14,
                  fontWeight: FontWeight.w900,
                  color: placeColor.withValues(alpha: 0.9),
                ),
              ),
            ),
          Container(
            width: 20,
            height: 20,
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getPlayerColor(player.slot),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _getPlayerColor(player.slot).withValues(alpha: 0.8),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              player.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showTextAtEnd)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                placeText,
                style: TextStyle(
                  fontSize: isWinner ? 16 : 14,
                  fontWeight: FontWeight.w900,
                  color: placeColor.withValues(alpha: 0.9),
                ),
              ),
            ),
          if (placeIcon != null) ...[
            const SizedBox(width: 8),
            Icon(
              placeIcon,
              color: placeColor,
              size: 24,
            )
                .animate(target: isWinner ? 1 : 0)
                .scale(duration: 800.ms, curve: Curves.elasticOut)
                .shimmer(duration: 1500.ms, delay: 800.ms),
          ],
        ],
      ),
    ).animate(delay: (150 * index).ms).fadeIn(duration: 400.ms).slideX(
          begin: 0.3,
        );
  }
}
