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
      duration: const Duration(milliseconds: 250),
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
                      Colors.white.withValues(alpha: 0.9), // Specular highlight
                      _getColor(token.slot), // Base color
                      _getColor(token.slot)
                          .withValues(alpha: 0.6), // Dark edge shadow
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    center: const Alignment(-0.35, -0.35),
                    radius: 0.8,
                  ),
                  border: Border.all(
                      color: isMovable ? Colors.white : Colors.white60,
                      width: isMovable ? 2.5 : 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 5,
                      spreadRadius: 1,
                      offset: const Offset(1, 4),
                    ),
                    if (isMovable)
                      BoxShadow(
                        color: _getColor(token.slot).withValues(alpha: 0.9),
                        blurRadius: 12,
                        spreadRadius: 3,
                        offset: const Offset(0, 0),
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
