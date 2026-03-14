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
            context: context,
            mode: GameMode.classic,
            label: 'Classic',
            description: 'Standard',
            icon: Icons.person,
            isEnabled: true,
            infoTitle: 'Classic Mode',
            infoItems: [
              _InfoItem(Icons.person, Colors.blueAccent, 'Solo Play',
                  'Standard Ludo. Every player for themselves.'),
              _InfoItem(Icons.flag, Colors.greenAccent, 'Winning',
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
              _InfoItem(Icons.group, Colors.orangeAccent, 'Partnership',
                  'Team up with the player opposite to you.'),
              _InfoItem(Icons.shield, Colors.blueAccent, 'No Capture',
                  "Partners don't capture each other!"),
              _InfoItem(Icons.hourglass_empty, Colors.redAccent, 'Wait Rule',
                  'If you finish early, you wait for your partner (no helping with rolls).'),
              _InfoItem(Icons.exit_to_app, Colors.deepOrangeAccent,
                  'Abandonment', 'If a teammate leaves, the whole team loses!'),
              _InfoItem(Icons.stars, Colors.amberAccent, 'Victory',
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
    required List<_InfoItem> infoItems,
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
                  top: -8,
                  right: -4,
                  child: GestureDetector(
                    onTap: () {
                      _showInfoDialog(context, infoTitle, infoItems, icon);
                    },
                    child: Icon(
                      Icons.help_outline,
                      size: 18,
                      color: isSelected
                          ? const Color(0xFF1E1E2C).withValues(alpha: 0.6)
                          : Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title,
      List<_InfoItem> items, IconData headerIcon) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2A2A3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(headerIcon, color: const Color(0xFFE5E4E2), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 32),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: items.map((item) => _buildRuleRow(item)).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5E4E2),
                  foregroundColor: const Color(0xFF1E1E2C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'GOT IT',
                  style: TextStyle(
                    color: Color(0xFF1E1E2C),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleRow(_InfoItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.content,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final Color color;
  final String title;
  final String content;

  _InfoItem(this.icon, this.color, this.title, this.content);
}
