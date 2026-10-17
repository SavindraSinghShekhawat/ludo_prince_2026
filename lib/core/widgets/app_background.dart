import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';

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
          // 1. Base Gradient (Midnight Obsidian Charcoal Void)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
                colors: [
                  Color(0xFF0A0C10), // Neutral Midnight Obsidian
                  Color(0xFF0F1117), // Charcoal Depth (neutral, no blue/purple)
                  Color(0xFF08090D), // Anchored deep obsidian
                ],
              ),
            ),
          ),

          // 2. Top Ambient Halo (Subtle cool slate illumination)
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            height: 440,
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.6),
                    radius: 1.25,
                    colors: [
                      const Color(0xFF1E2430).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
                    begin: 0.75,
                    end: 1.0,
                    duration: 8.seconds,
                    curve: Curves.easeInOut,
                  ),
            ),
          ),

          // 3. Bottom-Right Ambient Slate Accent (Harmonious diagonal depth)
          Positioned(
            bottom: -140,
            right: -80,
            width: 440,
            height: 440,
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF161922).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.08, 1.08),
                    duration: 11.seconds,
                    curve: Curves.easeInOut,
                  ),
            ),
          ),

          // 4. Subtle Central Stage Bloom (Soft diffuse luminescence)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [
                    const Color(0xFF94A3B8).withValues(alpha: 0.035),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // 5. Velvety Tabletop Micro-Texture Layer
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: TabletopTexturePainter(opacity: 0.02),
              ),
            ),
          ),

          // 6. Subtle Particle Layer (Stardust)
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      final int count = (size.width * size.height / 15000).ceil().clamp(10, 50);
      for (int i = 0; i < count; i++) {
        _particles.add(_Particle(_random, size.width, size.height));
      }
      _initialized = true;
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
        return CustomPaint(painter: _ParticlesPainter(particles: _particles));
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
  final double width;
  final double height;

  _Particle(this.random, this.width, this.height) {
    reset();
  }

  void reset() {
    x = random.nextDouble() * width;
    y = random.nextDouble() * height;
    vx = (random.nextDouble() - 0.5) * 0.2;
    vy = (random.nextDouble() - 0.5) * 0.2;
    size = random.nextDouble() * 2 + 1;
    opacity = random.nextDouble() * 0.2 + 0.1;
  }

  void update() {
    x += vx;
    y += vy;
    if (x < -50 || x > width + 50 || y < -50 || y > height + 50) {
      reset();
    }
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      paint.color = AppColors.starPlatinum.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
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
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1.0;

    final random = math.Random(123); // Seeded for consistency

    // Soft, velvety micro-grain without scratch lines or harsh noise
    final int pointCount =
        (size.width * size.height * 0.0015).toInt().clamp(150, 600);
    final List<Offset> points = List.generate(
      pointCount,
      (_) => Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      ),
    );
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
