import 'package:flutter/material.dart';

class RulesDialog extends StatelessWidget {
  const RulesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book, color: Color(0xFFE5E4E2), size: 28),
                SizedBox(width: 12),
                Text(
                  'Game Rules',
                  style: TextStyle(
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
                  children: [
                    _buildRule(
                        Icons.looks_6,
                        const Color(0xFFE5E4E2),
                        'Roll a 6',
                        'You must roll a 6 to move a token out of your base.'),
                    _buildRule(
                        Icons.replay,
                        const Color(0xFFB0B4B8),
                        'Extra Turn',
                        'Rolling a 6 gives you an additional turn.'),
                    _buildRule(
                        Icons.stars,
                        const Color(0xFF8A8D91),
                        'Safe Spots',
                        'Tokens on marked safe spots (stars) cannot be captured.'),
                    _buildRule(
                        Icons.sports_kabaddi,
                        const Color(0xFFD1D1D1),
                        'Capture',
                        'Landing exactly on an opponent\'s token captures it, sending it back to their base. This also grants you an extra turn.'),
                    _buildRule(Icons.flag, const Color(0xFFE5E4E2), 'Winning',
                        'The first player to move all 4 of their tokens to the home area at the center of the board wins.'),
                  ],
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
                'Got it!',
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
    );
  }

  Widget _buildRule(
      IconData icon, Color color, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
