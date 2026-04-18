import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import '../../models/token.dart';
import '../../models/board_path.dart';
import '../../utils/colors.dart';

class TokenWidget extends StatelessWidget {
  final Token token;
  final double cellSize;
  final bool isMovable;
  final Offset overlapOffset;
  final double scaleAdjustment;

  const TokenWidget({
    super.key,
    required this.token,
    required this.cellSize,
    required this.isMovable,
    this.overlapOffset = Offset.zero,
    this.scaleAdjustment = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    Offset gridPos = BoardPath.getTokenOffset(token);

    double tokenSize = cellSize *
        0.85 *
        scaleAdjustment; // Applied scale adjustment for stacking
    double offsetXY = (cellSize - tokenSize) / 2;

    final double targetX = gridPos.dx * cellSize + offsetXY + overlapOffset.dx;
    final double targetY = gridPos.dy * cellSize + offsetXY + overlapOffset.dy;

    return Positioned(
      left: 0,
      top: 0,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(
            begin: Offset(targetX, targetY), end: Offset(targetX, targetY)),
        duration: const Duration(milliseconds: 150),
        curve: Curves.linear,
        builder: (context, value, child) {
          return Transform.translate(
            offset: value,
            child: SizedBox(
              width: tokenSize,
              height: tokenSize,
              child: child,
            ),
          );
        },
        child: RepaintBoundary(
          child: IgnorePointer(
            ignoring: !isMovable,
            child: Consumer(
              builder: (context, ref, child) {
                return GestureDetector(
                  onTap: () {
                    ref.read(gameControllerProvider).sendMoveIntent(token);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _getGlowColor(token.slot),
                          _getColor(token.slot),
                        ],
                        center: Alignment.center,
                        radius: 1.0,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: AppColors.tokenBorderOpacity,
                        ),
                        width: isMovable ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 3,
                          offset: const Offset(0, 1.5),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.35),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                        if (isMovable)
                          BoxShadow(
                            color: _getGlowColor(
                              token.slot,
                            ).withValues(alpha: 0.6),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Gloss/Reflection layer
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: AppColors.tokenReflectionAlpha,
                                  ),
                                  Colors.white.withValues(alpha: 0.05),
                                  Colors.black.withValues(alpha: 0.05),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Inner ring for premium look
                        Center(
                          child: Container(
                            width: tokenSize * 0.76,
                            height: tokenSize * 0.76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                        // Center dot
                        Center(
                          child: Container(
                            width: tokenSize * 0.15,
                            height: tokenSize * 0.15,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _getGlowColor(PlayerSlot pSlot) {
    switch (pSlot) {
      case PlayerSlot.slot1:
        return AppColors.player1BlueGlow;
      case PlayerSlot.slot2:
        return AppColors.player2YellowGlow;
      case PlayerSlot.slot3:
        return AppColors.player3GreenGlow;
      case PlayerSlot.slot4:
        return AppColors.player4RedGlow;
    }
  }

  Color _getColor(PlayerSlot pSlot) {
    switch (pSlot) {
      case PlayerSlot.slot1:
        return AppColors.player1Blue;
      case PlayerSlot.slot2:
        return AppColors.player2Yellow;
      case PlayerSlot.slot3:
        return AppColors.player3Green;
      case PlayerSlot.slot4:
        return AppColors.player4Red;
    }
  }
}
