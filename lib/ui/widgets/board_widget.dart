import 'package:flutter/material.dart';
import '../../models/token.dart';

class BoardWidget extends StatelessWidget {
  const BoardWidget({super.key});

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
                  0, 0, Colors.redAccent, cellSize, PlayerSlot.slot4),
              _buildBaseArea(9, 0, Colors.greenAccent.shade700, cellSize,
                  PlayerSlot.slot3),
              _buildBaseArea(
                  9, 9, Colors.amber.shade600, cellSize, PlayerSlot.slot2),
              _buildBaseArea(
                  0, 9, Colors.blueAccent, cellSize, PlayerSlot.slot1),

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
      int col, int row, Color color, double cellSize, PlayerSlot pSlot) {
    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      width: 6 * cellSize,
      height: 6 * cellSize,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16), // modern rounded bases
        ),
        child: Center(
          child: Container(
            width: 4 * cellSize,
            height: 4 * cellSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            // Tokens in base will be rendered on top of the BoardWidget by a separate TokenWidget layer.
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int col, int row, double cellSize, Color color) {
    bool isStar = false;
    // Map safe star spots to logical grid (based on absolute path index 0, 8, 13, 21, 26, 34, 39, 47)
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

    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      width: cellSize,
      height: cellSize,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border:
              Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        ),
        child: isStar
            ? Icon(Icons.star_rounded,
                color: Colors.black12, size: cellSize * 0.8)
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

    return Colors.white; // default path color
  }
}

class CenterHomePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Center point
    final Offset center = Offset(w / 2, h / 2);

    final Paint redPaint = Paint()..color = Colors.redAccent;
    final Paint greenPaint = Paint()..color = Colors.greenAccent.shade700;
    final Paint yellowPaint = Paint()..color = Colors.amber.shade600;
    final Paint bluePaint = Paint()..color = Colors.blueAccent;

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
