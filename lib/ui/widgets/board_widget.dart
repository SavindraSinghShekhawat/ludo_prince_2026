import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/token.dart';
import '../../models/game_state.dart';
import '../../utils/colors.dart';

class FrostNoisePainter extends CustomPainter {
  final double opacity;
  FrostNoisePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1.0;

    final random = math.Random(42); // Seeded for consistency
    for (int i = 0; i < (size.width * size.height * 0.05).toInt(); i++) {
      canvas.drawPoints(
        PointMode.points,
        [
          Offset(random.nextDouble() * size.width,
              random.nextDouble() * size.height)
        ],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BoardWidget extends StatelessWidget {
  final GameMode gameMode;
  const BoardWidget({super.key, this.gameMode = GameMode.classic});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double boardSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final double cellSize = boardSize / 15;

        return SizedBox(
          width: boardSize,
          height: boardSize,
          child: Stack(
            children: [
              // Draw Base Areas
              // Standard layout: Slot1(top-left), Slot2(top-right), Slot3(bottom-right), Slot4(bottom-left)
              _buildBaseArea(
                  0, 0, AppColors.player4Red, cellSize, PlayerSlot.slot4,
                  teamLabel: 'B'),
              _buildBaseArea(
                  9, 0, AppColors.player3Green, cellSize, PlayerSlot.slot3,
                  teamLabel: 'A'),
              _buildBaseArea(
                  9, 9, AppColors.player2Yellow, cellSize, PlayerSlot.slot2,
                  teamLabel: 'B'),
              _buildBaseArea(
                  0, 9, AppColors.player1Blue, cellSize, PlayerSlot.slot1,
                  teamLabel: 'A'),

              // Draw Center Home
              Positioned(
                left: 6 * cellSize,
                top: 6 * cellSize,
                width: 3 * cellSize,
                height: 3 * cellSize,
                child: CustomPaint(
                  painter: CenterHomePainter(),
                ),
              ),

              // Draw Paths (horizontal and vertical strips)
              // Top path (vertical green strip)
              for (int col = 6; col <= 8; col++)
                for (int row = 0; row < 6; row++)
                  _buildCell(col, row, cellSize, _getCellColor(col, row)),

              // Bottom path (vertical blue/yellow strip)
              for (int col = 6; col <= 8; col++)
                for (int row = 9; row < 15; row++)
                  _buildCell(col, row, cellSize, _getCellColor(col, row)),

              // Left path (horizontal red/blue strip)
              for (int row = 6; row <= 8; row++)
                for (int col = 0; col < 6; col++)
                  _buildCell(col, row, cellSize, _getCellColor(col, row)),

              // Right path (horizontal green/yellow strip)
              for (int row = 6; row <= 8; row++)
                for (int col = 9; col < 15; col++)
                  _buildCell(col, row, cellSize, _getCellColor(col, row)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBaseArea(
      int col, int row, Color color, double cellSize, PlayerSlot pSlot,
      {String? teamLabel}) {
    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      width: 6 * cellSize,
      height: 6 * cellSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: AppColors.boardBaseAlpha),
                  color.withValues(alpha: AppColors.boardBaseAlpha * 0.4),
                ],
              ),
              border: Border.all(
                  color:
                      color.withValues(alpha: AppColors.boardBaseBorderAlpha),
                  width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Noise texture for frosting
                Positioned.fill(
                  child: CustomPaint(
                    painter: FrostNoisePainter(opacity: 0.03),
                  ),
                ),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 4.2 * cellSize,
                      height: 4.2 * cellSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.8),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 1.575 * cellSize,
                  top: 1.575 * cellSize,
                  child: _buildEmptySpot(cellSize, color),
                ),
                Positioned(
                  left: 3.575 * cellSize,
                  top: 1.575 * cellSize,
                  child: _buildEmptySpot(cellSize, color),
                ),
                Positioned(
                  left: 1.575 * cellSize,
                  top: 3.575 * cellSize,
                  child: _buildEmptySpot(cellSize, color),
                ),
                Positioned(
                  left: 3.575 * cellSize,
                  top: 3.575 * cellSize,
                  child: _buildEmptySpot(cellSize, color),
                ),
                if (teamLabel != null && gameMode == GameMode.team)
                  Positioned(
                    top: (col == 0 && row == 9) || (col == 9 && row == 9)
                        ? 0
                        : null,
                    bottom: (col == 0 && row == 0) || (col == 9 && row == 0)
                        ? 0
                        : null,
                    left: (col == 9 && row == 0) || (col == 9 && row == 9)
                        ? 0
                        : null,
                    right: (col == 0 && row == 0) || (col == 0 && row == 9)
                        ? 0
                        : null,
                    width: cellSize,
                    height: cellSize,
                    child: Center(
                      child: Container(
                        width: cellSize * 0.8,
                        height: cellSize * 0.8,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [color, color.withValues(alpha: 0.8)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            teamLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
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

  Widget _buildEmptySpot(double cellSize, Color color) {
    return Container(
      width: cellSize * 0.85,
      height: cellSize * 0.85,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int col, int row, double cellSize, Color color) {
    bool isStar = false;
    if ((col == 1 && row == 6) ||
        (col == 6 && row == 2) ||
        (col == 8 && row == 1) ||
        (col == 12 && row == 6) ||
        (col == 13 && row == 8) ||
        (col == 8 && row == 12) ||
        (col == 6 && row == 13) ||
        (col == 2 && row == 8)) {
      isStar = true;
    }

    final isDefault = color.alpha == 38;

    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      width: cellSize,
      height: cellSize,
      child: Container(
        decoration: BoxDecoration(
          color: isStar && isDefault
              ? AppColors.starCellBackground
              : (isDefault
                  ? Colors.transparent
                  : color.withValues(alpha: AppColors.boardCellAlpha)),
          border: Border.all(color: AppColors.boardGridColor, width: 0.5),
        ),
        child: Stack(
          children: [
            // Specular highlight on cell edges (whitish)
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: 0.5,
              child: Container(color: Colors.white.withValues(alpha: 0.3)),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 0.5,
              child: Container(color: Colors.white.withValues(alpha: 0.1)),
            ),
            if (!isDefault)
              Positioned.fill(
                child: CustomPaint(
                  painter: FrostNoisePainter(opacity: 0.02),
                ),
              ),
            if (isStar)
              Center(
                child: Icon(
                  Icons.star_rounded,
                  color: AppColors.starPlatinum,
                  size: cellSize * 0.82,
                  shadows: [
                    Shadow(
                      color: AppColors.starPlatinumGlow,
                      blurRadius: 8,
                    ),
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCellColor(int col, int row) {
    // Red home stretch
    if (row == 7 && col >= 1 && col <= 5) {
      return AppColors.player4Red
          .withValues(alpha: AppColors.boardHomeStretchAlpha);
    }
    // Green home stretch
    if (col == 7 && row >= 1 && row <= 5) {
      return AppColors.player3Green
          .withValues(alpha: AppColors.boardHomeStretchAlpha);
    }
    // Yellow home stretch
    if (row == 7 && col >= 9 && col <= 13) {
      return AppColors.player2Yellow
          .withValues(alpha: AppColors.boardHomeStretchAlpha);
    }
    // Blue home stretch
    if (col == 7 && row >= 9 && row <= 13) {
      return AppColors.player1Blue
          .withValues(alpha: AppColors.boardHomeStretchAlpha);
    }

    // Starting positions
    if (col == 1 && row == 6)
      return AppColors.player4Red
          .withValues(alpha: AppColors.boardStartCellAlpha);
    if (col == 8 && row == 1) {
      return AppColors.player3Green
          .withValues(alpha: AppColors.boardStartCellAlpha);
    }
    if (col == 13 && row == 8) {
      return AppColors.player2Yellow
          .withValues(alpha: AppColors.boardStartCellAlpha);
    }
    if (col == 6 && row == 13)
      return AppColors.player1Blue
          .withValues(alpha: AppColors.boardStartCellAlpha);

    return Colors.white
        .withValues(alpha: 0.15); // Frosted glass default path color
  }
}

class CenterHomePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);

    Paint getPaint(Color color) {
      return Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.7),
            color.withValues(alpha: 0.6),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill;
    }

    final redPaint = getPaint(AppColors.player4Red);
    final greenPaint = getPaint(AppColors.player3Green);
    final yellowPaint = getPaint(AppColors.player2Yellow);
    final bluePaint = getPaint(AppColors.player1Blue);

    void drawCrystalTriangle(Path path, Paint paint) {
      canvas.drawPath(path, paint);
      // Add subtle noise/sparkle to center
      final random = math.Random(42);
      final sparklePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.05);
      for (int i = 0; i < 20; i++) {
        canvas.drawCircle(
          Offset(random.nextDouble() * w, random.nextDouble() * h),
          0.5,
          sparklePaint,
        );
      }
    }

    drawCrystalTriangle(
        Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(center.dx, center.dy)
          ..close(),
        greenPaint);
    drawCrystalTriangle(
        Path()
          ..moveTo(w, 0)
          ..lineTo(w, h)
          ..lineTo(center.dx, center.dy)
          ..close(),
        yellowPaint);
    drawCrystalTriangle(
        Path()
          ..moveTo(0, h)
          ..lineTo(w, h)
          ..lineTo(center.dx, center.dy)
          ..close(),
        bluePaint);
    drawCrystalTriangle(
        Path()
          ..moveTo(0, 0)
          ..lineTo(0, h)
          ..lineTo(center.dx, center.dy)
          ..close(),
        redPaint);

    // Thick Specular separation lines
    Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 0), center, linePaint);
    canvas.drawLine(Offset(w, 0), center, linePaint);
    canvas.drawLine(Offset(0, h), center, linePaint);
    canvas.drawLine(Offset(w, h), center, linePaint);

    // Outer border for the crystal
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
