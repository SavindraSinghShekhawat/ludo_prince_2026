import 'package:flutter/material.dart';

class PlayerCountSelector extends StatelessWidget {
  final int currentCount;
  final List<int> options;
  final ValueChanged<int> onCountChanged;

  const PlayerCountSelector({
    super.key,
    required this.currentCount,
    required this.onCountChanged,
    this.options = const [2, 3, 4],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: options.map((n) {
        final isSelected = currentCount == n;
        return ChoiceChip(
          label: Text('$n Players'),
          selected: isSelected,
          onSelected: (val) {
            if (val && currentCount != n) {
              onCountChanged(n);
            }
          },
          selectedColor: const Color(0xFFE5E4E2),
          checkmarkColor: const Color(0xFF0F1117),
          backgroundColor: const Color(0xFF16181F),
          side: BorderSide(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.12),
          ),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF0F1117) : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList(),
    );
  }
}
