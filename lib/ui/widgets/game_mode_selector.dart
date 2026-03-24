import 'package:flutter/material.dart';
import '../../models/game_state.dart';
import '../dialogs/game_mode_info_dialog.dart';

class GameModeSelector extends StatelessWidget {
  final GameMode currentMode;
  final bool isTeamModeEnabled;
  final ValueChanged<GameMode> onModeChanged;

  const GameModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.isTeamModeEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _buildGameModeChip(
            context: context,
            mode: GameMode.classic,
            label: 'Classic',
            description: 'Standard',
            icon: Icons.person,
            isEnabled: true,
            infoTitle: 'Classic Mode',
            infoItems: [
              GameModeInfoItem(Icons.person, Colors.blueAccent, 'Solo Play',
                  'Standard Ludo. Every player for themselves.'),
              GameModeInfoItem(Icons.flag, Colors.greenAccent, 'Winning',
                  'First to get all tokens home wins!'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGameModeChip(
            context: context,
            mode: GameMode.team,
            label: '2vs2 Team',
            description: '4 Players Only',
            icon: Icons.group,
            isEnabled: isTeamModeEnabled,
            infoTitle: 'Team Mode (2vs2)',
            infoItems: [
              GameModeInfoItem(Icons.group, Colors.orangeAccent, 'Partnership',
                  'Team up with the player opposite to you.'),
              GameModeInfoItem(Icons.shield, Colors.blueAccent, 'No Capture',
                  "Partners don't capture each other!"),
              GameModeInfoItem(
                  Icons.hourglass_empty,
                  Colors.redAccent,
                  'Wait Rule',
                  'If you finish early, you wait for your partner (no helping with rolls).'),
              GameModeInfoItem(Icons.exit_to_app, Colors.deepOrangeAccent,
                  'Abandonment', 'If a teammate leaves, the whole team loses!'),
              GameModeInfoItem(Icons.stars, Colors.amberAccent, 'Victory',
                  'Your team wins when both are home.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameModeChip({
    required BuildContext context,
    required GameMode mode,
    required String label,
    required String description,
    required IconData icon,
    required bool isEnabled,
    required String infoTitle,
    required List<GameModeInfoItem> infoItems,
  }) {
    final isSelected = currentMode == mode;
    final color = isSelected ? const Color(0xFFE5E4E2) : Colors.white70;

    return Tooltip(
      message: isEnabled ? '' : '2vs2 mode requires exactly 4 players',
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                onModeChanged(mode);
              }
            : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE5E4E2)
                  : const Color(0xFF2A2A3D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.blueAccent.withValues(alpha: 0.5)
                    : Colors.white10,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? const Color(0xFF1E1E2C) : color,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF1E1E2C) : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEnabled ? description : 'Locked',
                      style: TextStyle(
                        color: (isSelected ? const Color(0xFF1E1E2C) : color)
                            .withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Positioned(
                  top: -12,
                  right: -10,
                  child: IconButton(
                    icon: Icon(
                      Icons.help_outline,
                      size: 22,
                      color: isSelected
                          ? const Color(0xFF1E1E2C).withValues(alpha: 0.6)
                          : Colors.white38,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => GameModeInfoDialog(
                          title: infoTitle,
                          items: infoItems,
                          headerIcon: icon,
                        ),
                      );
                    },
                    tooltip: 'Help',
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
