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
        0.7 *
        scaleAdjustment; // Applied scale adjustment for stacking
    double offsetXY = (cellSize - tokenSize) / 2;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      curve: Curves.linear,
      left: gridPos.dx * cellSize + offsetXY + overlapOffset.dx,
      top: gridPos.dy * cellSize + offsetXY + overlapOffset.dy,
      width: tokenSize,
      height: tokenSize,
      child: RepaintBoundary(
        child: IgnorePointer(
          ignoring: !isMovable,
          child: Consumer(builder: (context, ref, child) {
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
                    center: const Alignment(-0.3, -0.3),
                    radius: 0.8,
                  ),
                  border: Border.all(
                      color: Colors.white
                          .withValues(alpha: AppColors.tokenBorderOpacity),
                      width: isMovable ? 2.0 : 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                    if (isMovable)
                      BoxShadow(
                        color: _getGlowColor(token.slot).withValues(alpha: 0.6),
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
                                  alpha: AppColors.tokenReflectionAlpha),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.1),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Inner ring for premium look
                    Center(
                      child: Container(
                        width: tokenSize * 0.6,
                        height: tokenSize * 0.6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.2,
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
          }),
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
