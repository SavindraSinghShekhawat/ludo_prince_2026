import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/providers/game_provider.dart';

import '../../models/game_state.dart';

class DiceWidget extends ConsumerStatefulWidget {
  const DiceWidget({super.key});

  @override
  ConsumerState<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends ConsumerState<DiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _animatingValue = 1;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _controller.addListener(() {
      if (_controller.isAnimating) {
        setState(() {
          _animatingValue = Random().nextInt(6) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _rollDice() {
    final asyncState = ref.read(gameStreamProvider);
    final gameState = asyncState.value;

    if (gameState == null) return;
    if (gameState.isDiceRolled || _isAnimating) return;

    ref.read(gameControllerProvider).sendRollIntent();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<GameState>>(gameStreamProvider, (previous, next) {
      final state = next.value;
      if (state != null && state.isRolling && !_isAnimating) {
        setState(() {
          _isAnimating = true;
        });
        _controller.forward(from: 0).then((_) {
          if (mounted) {
            setState(() {
              _isAnimating = false;
            });
            _controller.reset();
          }
        });
      }
    });

    final asyncState = ref.watch(gameStreamProvider);
    final gameState = asyncState.value;
    if (gameState == null) return const SizedBox();
    final displayValue = _isAnimating ? _animatingValue : gameState.diceValue;

    return GestureDetector(
      onTap: _rollDice,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF), // White highlight
              Color(0xFFE5E4E2), // Platinum base
              Color(0xFFD0D3D6), // Slightly darker
              Color(0xFFA0A5A9), // Deep shadow
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7B8084), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 4,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CustomPaint(
            painter: DiceFacePainter(displayValue),
          ),
        ),
      )
          .animate(controller: _controller, autoPlay: false)
          .shake(hz: 8, duration: 450.ms, curve: Curves.easeInOut)
          .scaleXY(begin: 1.0, end: 1.2, duration: 225.ms)
          .then()
          .scaleXY(begin: 1.2, end: 1.0, duration: 225.ms),
    );
  }
}

class DiceFacePainter extends CustomPainter {
  final int value;
  DiceFacePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    double r = size.width * 0.12; // dot radius
    double w = size.width;
    double h = size.height;

    var paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF4A4A4A), Color(0xFF1A1A1A)],
        center: Alignment(-0.3, -0.3),
        radius: 0.8,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Centers
    Offset c = Offset(w / 2, h / 2);
    Offset tl = Offset(w * 0.25, h * 0.25);
    Offset tr = Offset(w * 0.75, h * 0.25);
    Offset bl = Offset(w * 0.25, h * 0.75);
    Offset br = Offset(w * 0.75, h * 0.75);
    Offset ml = Offset(w * 0.25, h * 0.5);
    Offset mr = Offset(w * 0.75, h * 0.5);

    if (value == 1) {
      canvas.drawCircle(c, r, paint);
    } else if (value == 2) {
      canvas.drawCircle(tl, r, paint);
      canvas.drawCircle(br, r, paint);
    } else if (value == 3) {
      canvas.drawCircle(tl, r, paint);
      canvas.drawCircle(c, r, paint);
      canvas.drawCircle(br, r, paint);
    } else if (value == 4) {
      canvas.drawCircle(tl, r, paint);
      canvas.drawCircle(tr, r, paint);
      canvas.drawCircle(bl, r, paint);
      canvas.drawCircle(br, r, paint);
    } else if (value == 5) {
      canvas.drawCircle(tl, r, paint);
      canvas.drawCircle(tr, r, paint);
      canvas.drawCircle(c, r, paint);
      canvas.drawCircle(bl, r, paint);
      canvas.drawCircle(br, r, paint);
    } else if (value == 6) {
      canvas.drawCircle(tl, r, paint);
      canvas.drawCircle(tr, r, paint);
      canvas.drawCircle(ml, r, paint);
      canvas.drawCircle(mr, r, paint);
      canvas.drawCircle(bl, r, paint);
      canvas.drawCircle(br, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
