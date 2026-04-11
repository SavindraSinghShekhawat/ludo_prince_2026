import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/game_state.dart';
import '../../utils/colors.dart';

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

        return RepaintBoundary(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: CustomPaint(
              painter: StaticBoardPainter(gameMode: gameMode),
            ),
          ),
        );
      },
    );
  }
}

class StaticBoardPainter extends CustomPainter {
  final GameMode gameMode;
  static final Map<String, Picture> _cache = {};

  StaticBoardPainter({required this.gameMode});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final String cacheKey = "${size.width}x${size.height}_$gameMode";

    if (!_cache.containsKey(cacheKey)) {
      final recorder = PictureRecorder();
      final offscreenCanvas = Canvas(recorder);
      final double cellSize = size.width / 15;

      // 1. Draw Base Areas
      _drawBaseArea(offscreenCanvas, 0, 0, AppColors.player4Red, cellSize,
          borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16)));
      _drawBaseArea(offscreenCanvas, 9, 0, AppColors.player3Green, cellSize,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16)));
      _drawBaseArea(offscreenCanvas, 9, 9, AppColors.player2Yellow, cellSize,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16)));
      _drawBaseArea(offscreenCanvas, 0, 9, AppColors.player1Blue, cellSize,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16)));

      // 2. Draw Center Home
      _drawCenterHome(offscreenCanvas, size, cellSize);

      // 3. Draw Path Cells
      // Top path
      for (int col = 6; col <= 8; col++) {
        for (int row = 0; row < 6; row++) {
          _drawCell(
              offscreenCanvas, col, row, cellSize, _getCellColor(col, row));
        }
      }
      // Bottom path
      for (int col = 6; col <= 8; col++) {
        for (int row = 9; row < 15; row++) {
          _drawCell(
              offscreenCanvas, col, row, cellSize, _getCellColor(col, row));
        }
      }
      // Left path
      for (int row = 6; row <= 8; row++) {
        for (int col = 0; col < 6; col++) {
          _drawCell(
              offscreenCanvas, col, row, cellSize, _getCellColor(col, row));
        }
      }
      // Right path
      for (int row = 6; row <= 8; row++) {
        for (int col = 9; col < 15; col++) {
          _drawCell(
              offscreenCanvas, col, row, cellSize, _getCellColor(col, row));
        }
      }

      // 4. Draw Stars (Special cells)
      _drawStars(offscreenCanvas, cellSize);

      _cache[cacheKey] = recorder.endRecording();
    }

    canvas.drawPicture(_cache[cacheKey]!);
  }

  void _drawBaseArea(
      Canvas canvas, int col, int row, Color color, double cellSize,
      {required BorderRadius borderRadius}) {
    final rect = Rect.fromLTWH(
        col * cellSize, row * cellSize, 6 * cellSize, 6 * cellSize);
    final RRect rrect = borderRadius.toRRect(rect);

    // Gradient Background
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: AppColors.boardBaseAlpha),
          color.withValues(alpha: AppColors.boardBaseAlpha * 0.4),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rrect, paint);

    // Noise frost
    _drawNoise(canvas, rect, 0.03);

    // Inner frosted square
    final innerSize = 4.2 * cellSize;
    final innerRect = Rect.fromCenter(
        center: rect.center, width: innerSize, height: innerSize);
    final innerRRect =
        RRect.fromRectAndRadius(innerRect, const Radius.circular(12));

    canvas.drawRRect(
        innerRRect, Paint()..color = Colors.white.withValues(alpha: 0.03));
    canvas.drawRRect(
        innerRRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);

    // Empty spots
    void drawSpot(double dx, double dy) {
      final spotCenter =
          Offset(rect.left + dx * cellSize, rect.top + dy * cellSize);
      final spotRadius = cellSize * 0.85 / 2;

      canvas.drawCircle(spotCenter, spotRadius,
          Paint()..color = Colors.black.withValues(alpha: 0.15));
      canvas.drawCircle(
          spotCenter,
          spotRadius,
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }

    drawSpot(2, 2);
    drawSpot(4, 2);
    drawSpot(2, 4);
    drawSpot(4, 4);

    // Team Labels (Optional: could keep as widgets if interaction is needed, but here we paint them)
    if (gameMode == GameMode.team) {
      final String teamLabel =
          (col == 0 && row == 0) || (col == 9 && row == 9) ? 'B' : 'A';

      double labelX, labelY;
      if ((col == 0 && row == 9) || (col == 9 && row == 9)) {
        labelY = rect.top + cellSize / 2;
      } else {
        labelY = rect.bottom - cellSize / 2;
      }

      if ((col == 9 && row == 0) || (col == 9 && row == 9)) {
        labelX = rect.left + cellSize / 2;
      } else {
        labelX = rect.right - cellSize / 2;
      }

      final labelCenter = Offset(labelX, labelY);
      final badgeRadius = cellSize * 0.8 / 2;

      // Badge
      canvas.drawCircle(
          labelCenter,
          badgeRadius,
          Paint()
            ..shader = RadialGradient(
                    colors: [color, color.withValues(alpha: 0.8)])
                .createShader(
                    Rect.fromCircle(center: labelCenter, radius: badgeRadius)));
      canvas.drawCircle(
          labelCenter,
          badgeRadius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      // Text (Note: Painting text in CustomPainter is a bit verbose, we might skip or keep as widgets.
      // But let's try painting it for efficiency)
      final textPainter = TextPainter(
        text: TextSpan(
          text: teamLabel,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas,
          labelCenter - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  void _drawCell(
      Canvas canvas, int col, int row, double cellSize, Color color) {
    final rect =
        Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);
    final bool isDefault = color.alpha == 38 || color == Colors.transparent;

    if (!isDefault) {
      canvas.drawRect(rect,
          Paint()..color = color.withValues(alpha: AppColors.boardCellAlpha));
      _drawNoise(canvas, rect, 0.02);
    }

    canvas.drawRect(
        rect,
        Paint()
          ..color = AppColors.boardGridColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
  }

  void _drawStars(Canvas canvas, double cellSize) {
    const starPositions = [
      Offset(1, 6),
      Offset(6, 2),
      Offset(8, 1),
      Offset(12, 6),
      Offset(13, 8),
      Offset(8, 12),
      Offset(6, 13),
      Offset(2, 8)
    ];

    for (var pos in starPositions) {
      final rect = Rect.fromLTWH(
          pos.dx * cellSize, pos.dy * cellSize, cellSize, cellSize);

      // Star Background (if default cell)
      // Note: _drawCell already handled the background color logic if we pass correct color.
      // But we can specifically draw AppColors.starCellBackground here if needed.

      // Drawing the star icon is tricky in CustomPainter. Let's use a TextPainter with a star character or IconData.
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.star_rounded.codePoint),
          style: TextStyle(
            fontSize: cellSize,
            fontFamily: Icons.star_rounded.fontFamily,
            package: Icons.star_rounded.fontPackage,
            color: AppColors.starPlatinum,
            shadows: [
              Shadow(color: AppColors.starPlatinumGlow, blurRadius: 8),
              Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas,
          rect.center - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  void _drawCenterHome(Canvas canvas, Size size, double cellSize) {
    final double w = 3 * cellSize;
    final double h = 3 * cellSize;
    final double startX = 6 * cellSize;
    final double startY = 6 * cellSize;
    final Offset center = Offset(startX + w / 2, startY + h / 2);

    Paint getPaint(Color color) {
      return Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.6)],
        ).createShader(Rect.fromLTWH(startX, startY, w, h))
        ..style = PaintingStyle.fill;
    }

    void drawCrystalTriangle(Path path, Paint paint) {
      canvas.drawPath(path, paint);
      final random = math.Random(42);
      final sparklePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.05);
      for (int i = 0; i < 15; i++) {
        canvas.drawCircle(
            Offset(startX + random.nextDouble() * w,
                startY + random.nextDouble() * h),
            0.5,
            sparklePaint);
      }
    }

    drawCrystalTriangle(
        Path()
          ..moveTo(startX, startY)
          ..lineTo(startX + w, startY)
          ..lineTo(center.dx, center.dy)
          ..close(),
        getPaint(AppColors.player3Green));
    drawCrystalTriangle(
        Path()
          ..moveTo(startX + w, startY)
          ..lineTo(startX + w, startY + h)
          ..lineTo(center.dx, center.dy)
          ..close(),
        getPaint(AppColors.player2Yellow));
    drawCrystalTriangle(
        Path()
          ..moveTo(startX, startY + h)
          ..lineTo(startX + w, startY + h)
          ..lineTo(center.dx, center.dy)
          ..close(),
        getPaint(AppColors.player1Blue));
    drawCrystalTriangle(
        Path()
          ..moveTo(startX, startY)
          ..lineTo(startX, startY + h)
          ..lineTo(center.dx, center.dy)
          ..close(),
        getPaint(AppColors.player4Red));

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(startX, startY), center, linePaint);
    canvas.drawLine(Offset(startX + w, startY), center, linePaint);
    canvas.drawLine(Offset(startX, startY + h), center, linePaint);
    canvas.drawLine(Offset(startX + w, startY + h), center, linePaint);
    canvas.drawRect(
        Rect.fromLTWH(startX, startY, w, h), linePaint..strokeWidth = 1);
  }

  void _drawNoise(Canvas canvas, Rect rect, double opacity) {
    final random = math.Random(42);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1.0;
    final int pointCount = (rect.width * rect.height * 0.04).toInt();
    for (int i = 0; i < pointCount; i++) {
      canvas.drawPoints(
          PointMode.points,
          [
            Offset(rect.left + random.nextDouble() * rect.width,
                rect.top + random.nextDouble() * rect.height)
          ],
          paint);
    }
  }

  Color _getCellColor(int col, int row) {
    if (row == 7 && col >= 1 && col <= 5) {
      return AppColors.player4Red
          .withValues(alpha: AppColors.boardHomeStretchAlpha);
    }
    if (col == 7 && row >= 1 && row <= 5) {
      return AppColors.player3Green
          .withValues(alpha: AppColors.boardHomeStretchAlpha);
    }
    if (row == 7 && col >= 9 && col <= 13) {
      return AppColors.player2Yellow
          .withValues(alpha: AppColors.boardHomeStretchAlpha);
    }
    if (col == 7 && row >= 9 && row <= 13) {
      return AppColors.player1Blue
          .withValues(alpha: AppColors.boardHomeStretchAlpha);
    }
    if (col == 1 && row == 6) {
      return AppColors.player4Red
          .withValues(alpha: AppColors.boardStartCellAlpha);
    }
    if (col == 8 && row == 1) {
      return AppColors.player3Green
          .withValues(alpha: AppColors.boardStartCellAlpha);
    }
    if (col == 13 && row == 8) {
      return AppColors.player2Yellow
          .withValues(alpha: AppColors.boardStartCellAlpha);
    }
    if (col == 6 && row == 13) {
      return AppColors.player1Blue
          .withValues(alpha: AppColors.boardStartCellAlpha);
    }
    return Colors.white.withValues(alpha: 0.15);
  }

  @override
  bool shouldRepaint(covariant StaticBoardPainter oldDelegate) =>
      oldDelegate.gameMode != gameMode;
}
