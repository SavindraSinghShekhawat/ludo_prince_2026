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
                      color: isMovable ? Colors.white : Colors.white60,
                      width: isMovable ? 3 : 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 2),
                    ),
                    if (isMovable)
                      BoxShadow(
                        color: _getColor(token.slot).withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
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
