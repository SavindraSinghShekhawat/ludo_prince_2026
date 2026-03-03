import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/providers/game_provider.dart';

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
        vsync: this, duration: const Duration(milliseconds: 600));
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

    setState(() {
      _isAnimating = true;
    });

    _controller.forward(from: 0).then((_) {
      setState(() {
        _isAnimating = false;
      });
      ref.read(gameControllerProvider).sendRollIntent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(gameStreamProvider);
    final gameState = asyncState.value;
    if (gameState == null) return const SizedBox();
    final displayValue = _isAnimating ? _animatingValue : gameState.diceValue;

    return GestureDetector(
      onTap: _rollDice,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE5E4E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB0B4B8), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
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
          .shake(hz: 8, duration: 600.ms, curve: Curves.easeInOut)
          .scaleXY(begin: 1.0, end: 1.2, duration: 300.ms)
          .then()
          .scaleXY(begin: 1.2, end: 1.0, duration: 300.ms),
    );
  }
}

class DiceFacePainter extends CustomPainter {
  final int value;
  DiceFacePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    double r = size.width * 0.12; // dot radius
    double w = size.width;
    double h = size.height;

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
