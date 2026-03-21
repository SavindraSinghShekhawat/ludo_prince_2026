import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import '../../models/token.dart';
import '../../models/board_path.dart';

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
                  color: _getColor(token.slot),
                  border: Border.all(
                      color: isMovable ? Colors.white : Colors.white70,
                      width: isMovable ? 2.5 : 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                    if (isMovable)
                      BoxShadow(
                        color: _getColor(token.slot).withValues(alpha: 0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: tokenSize * 0.55,
                    height: tokenSize * 0.55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: tokenSize * 0.15,
                        height: tokenSize * 0.15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Color _getColor(PlayerSlot pSlot) {
    switch (pSlot) {
      case PlayerSlot.slot1:
        return Colors.blue;
      case PlayerSlot.slot2:
        return Colors.amber;
      case PlayerSlot.slot3:
        return Colors.green;
      case PlayerSlot.slot4:
        return Colors.red;
    }
  }
}
