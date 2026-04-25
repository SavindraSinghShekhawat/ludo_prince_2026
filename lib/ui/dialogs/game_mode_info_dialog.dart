import 'package:ludo_prince/ui/widgets/shared_ui.dart';

import 'package:flutter/material.dart';

class GameModeInfoItem {
  final IconData icon;
  final Color color;
  final String title;
  final String content;

  GameModeInfoItem(this.icon, this.color, this.title, this.content);
}

class GameModeInfoDialog extends StatelessWidget {
  final String title;
  final List<GameModeInfoItem> items;
  final IconData headerIcon;

  const GameModeInfoDialog({
    super.key,
    required this.title,
    required this.items,
    required this.headerIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialogLayout(
      header: Row(
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
      body: items.map((item) => _buildRule(item)).toList(),
      footer: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE5E4E2),
          foregroundColor: const Color(0xFF1E1E2C),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(
          'Got it!',
          style: TextStyle(
            color: Color(0xFF1E1E2C),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRule(GameModeInfoItem item) {
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
