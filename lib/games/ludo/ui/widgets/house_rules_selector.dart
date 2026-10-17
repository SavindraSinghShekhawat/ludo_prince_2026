import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/core/widgets/app_toggle.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_rules.dart';

class HouseRulesSelector extends StatefulWidget {
  final GameRules rules;
  final ValueChanged<GameRules> onRulesChanged;

  const HouseRulesSelector({
    super.key,
    required this.rules,
    required this.onRulesChanged,
  });

  @override
  State<HouseRulesSelector> createState() => _HouseRulesSelectorState();
}

class _HouseRulesSelectorState extends State<HouseRulesSelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    final isCustom = rules.isCustom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (Always visible & tap to expand/collapse)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCustom
                          ? AppColors.primaryCyan.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCustom
                            ? AppColors.primaryCyan.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: isCustom ? AppColors.primaryCyan : Colors.white70,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + Badge row & Summary subtitle with full available width
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'HOUSE RULES',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isCustom
                                    ? AppColors.primaryCyan.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isCustom
                                      ? AppColors.primaryCyan.withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isCustom ? 'CUSTOM' : 'CLASSIC',
                                style: TextStyle(
                                  color: isCustom
                                      ? AppColors.primaryCyan
                                      : const Color(0xFFE5E4E2),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (isCustom)
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 13,
                                color: AppColors.primaryCyan,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _getSummary(rules),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'Standard rules (Tap to customize)',
                            style: TextStyle(
                              color: Color(0xFFCBD0E0),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: 250.ms,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isCustom ? AppColors.primaryCyan : Colors.white70,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable settings body
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(color: Colors.white12, height: 20),

                  // Rule 1: Open on 1 or 6
                  _buildRuleToggle(
                    icon: Icons.casino_outlined,
                    iconColor: AppColors.imperialAmber,
                    title: 'Open on 1 or 6',
                    subtitle: 'Pieces can exit home base on a roll of 1 or 6',
                    value: rules.openOnOneAndSix,
                    accentColor: AppColors.imperialAmber,
                    onChanged: (val) {
                      widget.onRulesChanged(
                        rules.copyWith(openOnOneAndSix: val),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Rule 2: Tokens per Player (4 vs 2)
                  _buildTokenCountSelector(
                    currentCount: rules.tokensPerPlayer,
                    onChanged: (count) {
                      widget.onRulesChanged(
                        rules.copyWith(tokensPerPlayer: count),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Rule 3: Three consecutive 6s penalty
                  _buildRuleToggle(
                    icon: Icons.block_flipped,
                    iconColor: const Color(0xFFD47AFF), // Amethyst
                    title: 'Three 6s Penalty',
                    subtitle: 'Skips turn after rolling three consecutive 6s',
                    value: rules.penalizeThreeSixes,
                    accentColor: const Color(0xFFD47AFF),
                    onChanged: (val) {
                      widget.onRulesChanged(
                        rules.copyWith(penalizeThreeSixes: val),
                      );
                    },
                  ),

                  if (isCustom) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        widget.onRulesChanged(const GameRules());
                      },
                      icon: const Icon(
                        Icons.restore_rounded,
                        size: 18,
                        color: AppColors.primaryCyan,
                      ),
                      label: const Text(
                        'Reset to Classic Rules',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: 250.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleToggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Color accentColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: value
                  ? accentColor.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? accentColor : Colors.white60,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: value ? Colors.white : Colors.white70,
                          fontSize: 14.5,
                          fontWeight: value ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (value) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          'ON',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: value
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white54,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: value ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppToggle(
            value: value,
            accentColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCountSelector({
    required int currentCount,
    required ValueChanged<int> onChanged,
  }) {
    final bool isQuick = currentCount == 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isQuick
                      ? AppColors.primaryCyan.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  color: isQuick ? AppColors.primaryCyan : Colors.white60,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Tokens per Player',
                          style: TextStyle(
                            color: isQuick ? Colors.white : Colors.white70,
                            fontSize: 14.5,
                            fontWeight: isQuick ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        if (isQuick) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryCyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.primaryCyan.withValues(alpha: 0.4),
                                width: 1.0,
                              ),
                            ),
                            child: const Text(
                              'QUICK',
                              style: TextStyle(
                                color: AppColors.primaryCyan,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Standard 4-token or faster 2-token match',
                      style: TextStyle(
                        color: isQuick
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white54,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: isQuick ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTokenPill(
                  title: '4 Tokens',
                  subtitle: 'Classic',
                  isSelected: currentCount == 4,
                  onTap: () => onChanged(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTokenPill(
                  title: '2 Tokens',
                  subtitle: 'Quick Match',
                  isSelected: currentCount == 2,
                  onTap: () => onChanged(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenPill({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryCyan.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryCyan.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.10),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.primaryCyan,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? const Color(0xFFBAE6FD) : Colors.white38,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSummary(GameRules rules) {
    List<String> active = [];
    if (rules.openOnOneAndSix) active.add('Open on 1 & 6');
    if (rules.tokensPerPlayer == 2) active.add('2 Tokens (Quick)');
    if (!rules.penalizeThreeSixes) active.add('No 3x6 Penalty');
    return active.join(' • ');
  }
}
