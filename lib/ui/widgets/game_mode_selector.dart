import 'package:flutter/material.dart';
import '../../models/game_state.dart';

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
            mode: GameMode.classic,
            label: 'Classic',
            description: 'Standard',
            icon: Icons.person,
            isEnabled: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGameModeChip(
            mode: GameMode.team,
            label: '2vs2 Team',
            description: '4 Players Only',
            icon: Icons.group,
            isEnabled: isTeamModeEnabled,
          ),
        ),
      ],
    );
  }

  Widget _buildGameModeChip({
    required GameMode mode,
    required String label,
    required String description,
    required IconData icon,
    required bool isEnabled,
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
            child: Column(
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
          ),
        ),
      ),
    );
  }
}
