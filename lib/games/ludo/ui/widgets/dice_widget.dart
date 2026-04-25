import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/providers/game_provider.dart';

import '../../domain/models/game_state.dart';

class DiceWidget extends ConsumerStatefulWidget {
  const DiceWidget({super.key});

  @override
  ConsumerState<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends ConsumerState<DiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isAnimating = false;
  bool _isWaitingForResult = false;
  DateTime? _waitStartTime;
  double _currentRotationSpeed = 100; // ms per shuffle

  static final Random _rng = Random.secure();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Shake animation: jitter between -2 and 2 pixels
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 2.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: -2.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    // Scale animation: pop up and down
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );
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
      if (state == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Detect "Waiting for Result" state
        if (state.isWaitingForResult && !_isWaitingForResult) {
          setState(() {
            _isWaitingForResult = true;
            _isAnimating = true;
            _waitStartTime = DateTime.now();
            _currentRotationSpeed = 100;
          });
          _controller.duration = Duration(
            milliseconds: _currentRotationSpeed.toInt(),
          );
          _controller.repeat();
          _startSlowdownTimer();
        }

        // Detect Transition from "Waiting" to "Landing"
        if (!state.isWaitingForResult && _isWaitingForResult) {
          setState(() {
            _isWaitingForResult = false;
          });
          _controller.duration = const Duration(milliseconds: 450);
          _controller.forward(from: 0).then((_) {
            if (mounted) {
              setState(() {
                _isAnimating = false;
              });
              _controller.reset();
            }
          });
        }

        // Fallback for non-multiplayer or sudden state changes
        if (state.isRolling && !state.isWaitingForResult && !_isAnimating) {
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
    });

    final diceValue = ref.watch(
      gameStreamProvider.select((s) => s.value?.diceValue ?? 1),
    );

    return GestureDetector(
      onTap: _rollDice,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // If in the rapid loop, randomize value locally based on controller progress
          // This avoids calling setState during build context while keeping the visuals alive
          final int displayValue = (_isAnimating && _isWaitingForResult)
              ? (_rng.nextInt(6) + 1)
              : diceValue;

          // Jitter offset
          final double offset = _isAnimating ? _shakeAnimation.value : 0;
          final double scale = _isAnimating ? _scaleAnimation.value : 1.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(offset, -offset),
                child: Transform.scale(
                  scale: scale,
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
                      border: Border.all(
                        color: const Color(0xFF7B8084),
                        width: 1.5,
                      ),
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
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(
                          painter: DiceFacePainter(displayValue),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isWaitingForResult &&
                  _waitStartTime != null &&
                  DateTime.now().difference(_waitStartTime!).inMilliseconds >
                      2500)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Syncing...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _startSlowdownTimer() async {
    while (_isWaitingForResult && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_isWaitingForResult || !mounted) break;

      final elapsed = DateTime.now().difference(_waitStartTime!).inMilliseconds;
      if (elapsed > 1500) {
        setState(() {
          // Gradually slow down from 100ms to 400ms per shuffle
          _currentRotationSpeed = min(400, 100 + (elapsed - 1500) / 10);
          _controller.duration = Duration(
            milliseconds: _currentRotationSpeed.toInt(),
          );
          if (!_controller.isAnimating) _controller.repeat();
        });
      }
    }
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
  bool shouldRepaint(DiceFacePainter oldDelegate) => oldDelegate.value != value;
}
