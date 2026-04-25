import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/utils/colors.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showParticles;

  const AppBackground({
    super.key,
    required this.child,
    this.showParticles = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Base dark gradient (Deep void)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF03030F), Color(0xFF0B0B1A)],
              ),
            ),
          ),

          // Secondary depth gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    AppColors.primaryCyan.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Tabletop Texture Layer
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: TabletopTexturePainter(opacity: 0.05),
              ),
            ),
          ),

          // Central Spotlight
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Animated ambient soft glows (Sapphire accent)
          Positioned(
            top: -150,
            left: -100,
            child: RepaintBoundary(
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.midnightSapphire.withValues(
                        alpha: 0.25,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).move(
                    begin: const Offset(0, 0),
                    end: const Offset(50, 50),
                    duration: 15.seconds,
                    curve: Curves.easeInOut,
                  ),
            ),
          ),

          // Subtle Particle Layer
          if (showParticles)
            Positioned.fill(
              child: RepaintBoundary(child: const ParticlesWidget()),
            ),

          child,
        ],
      ),
    );
  }
}

class ParticlesWidget extends StatefulWidget {
  const ParticlesWidget({super.key});

  @override
  State<ParticlesWidget> createState() => _ParticlesWidgetState();
}

class _ParticlesWidgetState extends State<ParticlesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(_random));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var p in _particles) {
          p.update();
        }
        return CustomPaint(painter: ParticlesPainter(particles: _particles));
      },
    );
  }
}

class _Particle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late double size;
  late double opacity;
  final math.Random random;

  _Particle(this.random) {
    reset();
  }

  void reset() {
    x = random.nextDouble() * 400; // Relative to screen
    y = random.nextDouble() * 800;
    vx = (random.nextDouble() - 0.5) * 0.2;
    vy = (random.nextDouble() - 0.5) * 0.2;
    size = random.nextDouble() * 2 + 1;
    opacity = random.nextDouble() * 0.2 + 0.1;
  }

  void update() {
    x += vx;
    y += vy;
    if (x < -50 || x > 450 || y < -50 || y > 850) {
      reset();
    }
  }
}

class ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  ParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      // Scale x/y to actual size
      final px = (p.x / 400) * size.width;
      final py = (p.y / 800) * size.height;

      paint.color = AppColors.starPlatinum.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(px, py), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TabletopTexturePainter extends CustomPainter {
  final double opacity;
  TabletopTexturePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1.0;

    final random = math.Random(123); // Seeded for consistency

    // Draw fine grain/noise
    final List<Offset> points = [];
    for (int i = 0; i < (size.width * size.height * 0.01).toInt(); i++) {
      points.add(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
      );
    }
    canvas.drawPoints(PointMode.points, points, paint);

    // Draw subtle "wood/felt" fibers
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.5)
      ..strokeWidth = 0.5;

    for (int i = 0; i < 100; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double len = random.nextDouble() * 20 + 5;
      double angle = random.nextDouble() * math.pi;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(angle) * len, y + math.sin(angle) * len),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
