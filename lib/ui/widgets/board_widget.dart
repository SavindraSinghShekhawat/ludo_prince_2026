import 'package:flutter/material.dart';
import '../../models/token.dart';
import '../../models/game_state.dart';

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
              _buildBaseArea(0, 0, Colors.redAccent, cellSize, PlayerSlot.slot4,
                  teamLabel: 'B'),
              _buildBaseArea(
                  9, 0, Colors.greenAccent.shade700, cellSize, PlayerSlot.slot3,
                  teamLabel: 'A'),
              _buildBaseArea(
                  9, 9, Colors.amber.shade600, cellSize, PlayerSlot.slot2,
                  teamLabel: 'B'),
              _buildBaseArea(
                  0, 9, Colors.blueAccent, cellSize, PlayerSlot.slot1,
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
      child: Container(
        decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.25)
              ],
              center: Alignment.topLeft,
              radius: 1.5,
            ),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 2.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2),
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 5,
                  offset: const Offset(2, 2)),
            ]),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 4 * cellSize,
                height: 4 * cellSize,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFE5E4E2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 2,
                          offset: const Offset(-1, -1)),
                    ]),
              ),
            ),
            if (teamLabel != null && gameMode == GameMode.team)
              Positioned(
                top:
                    (col == 0 && row == 9) || (col == 9 && row == 9) ? 0 : null,
                bottom:
                    (col == 0 && row == 0) || (col == 9 && row == 0) ? 0 : null,
                left:
                    (col == 9 && row == 0) || (col == 9 && row == 9) ? 0 : null,
                right:
                    (col == 0 && row == 0) || (col == 0 && row == 9) ? 0 : null,
                width: cellSize,
                height: cellSize,
                child: Center(
                  child: Container(
                    width: cellSize * 0.55,
                    height: cellSize * 0.55,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [color.withValues(alpha: 0.7), color],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2),
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
    );
  }

  Widget _buildCell(int col, int row, double cellSize, Color color) {
    bool isStar = false;
    // Map safe star spots to logical grid
    if ((col == 1 && row == 6) || // index 0 (Red start)
        (col == 6 && row == 2) || // index 8 (Green star)
        (col == 8 && row == 1) || // index 13 (Green start)
        (col == 12 && row == 6) || // index 21 (Yellow star)
        (col == 13 && row == 8) || // index 26 (Yellow start)
        (col == 8 && row == 12) || // index 34 (Blue star)
        (col == 6 && row == 13) || // index 39 (Blue start)
        (col == 2 && row == 8)) {
      // index 47 (Red star)
      isStar = true;
    }

    final isDefault = color.alpha == 38; // alpha 0.15 * 255 = 38

    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      width: cellSize,
      height: cellSize,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDefault
                ? [
                    Colors.white.withValues(alpha: 0.25),
                    color,
                    Colors.black.withValues(alpha: 0.1),
                  ]
                : [
                    Colors.black.withValues(alpha: 0.1),
                    color,
                    Colors.white.withValues(alpha: 0.3),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(
              color: isDefault
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.3),
              width: 0.5),
        ),
        child: isStar
            ? Icon(Icons.star_rounded,
                color: isDefault
                    ? Colors.white24
                    : Colors.black.withValues(alpha: 0.2),
                size: cellSize * 0.8)
            : null,
      ),
    );
  }

  Color _getCellColor(int col, int row) {
    // Red home stretch
    if (row == 7 && col >= 1 && col <= 5) {
      return Colors.redAccent.withValues(alpha: 0.5);
    }
    // Green home stretch
    if (col == 7 && row >= 1 && row <= 5) {
      return Colors.greenAccent.shade700.withValues(alpha: 0.5);
    }
    // Yellow home stretch
    if (row == 7 && col >= 9 && col <= 13) {
      return Colors.amber.shade600.withValues(alpha: 0.5);
    }
    // Blue home stretch
    if (col == 7 && row >= 9 && row <= 13) {
      return Colors.blueAccent.withValues(alpha: 0.5);
    }

    // Starting positions
    if (col == 1 && row == 6) return Colors.redAccent.withValues(alpha: 0.8);
    if (col == 8 && row == 1) {
      return Colors.greenAccent.shade700.withValues(alpha: 0.8);
    }
    if (col == 13 && row == 8) {
      return Colors.amber.shade600.withValues(alpha: 0.8);
    }
    if (col == 6 && row == 13) return Colors.blueAccent.withValues(alpha: 0.8);

    return Colors.white.withValues(alpha: 0.15); // Glass default path color
  }
}

class CenterHomePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Center point
    final Offset center = Offset(w / 2, h / 2);
    final Rect rect = Rect.fromLTWH(0, 0, w, h);

    Paint getPaint(Color color) {
      return Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.6), color],
          center: Alignment.center,
          radius: 0.8,
        ).createShader(rect)
        ..style = PaintingStyle.fill;
    }

    final Paint redPaint = getPaint(Colors.redAccent);
    final Paint greenPaint = getPaint(Colors.greenAccent.shade700);
    final Paint yellowPaint = getPaint(Colors.amber.shade600);
    final Paint bluePaint = getPaint(Colors.blueAccent);

    // Top Triangle (Green)
    Path topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(topPath, greenPaint);

    // Right Triangle (Yellow)
    Path rightPath = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(rightPath, yellowPaint);

    // Bottom Triangle (Blue)
    Path bottomPath = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(bottomPath, bluePaint);

    // Left Triangle (Red)
    Path leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, h)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(leftPath, redPaint);

    // Draw lines to separate triangles clearly
    Paint linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 0), center, linePaint);
    canvas.drawLine(Offset(w, 0), center, linePaint);
    canvas.drawLine(Offset(0, h), center, linePaint);
    canvas.drawLine(Offset(w, h), center, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
