import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/core/widgets/app_snackbar.dart';
import 'package:ludo_prince/core/widgets/glass_container.dart';
import 'package:ludo_prince/services/smart_review_service.dart';
import 'package:ludo_prince/ui/screens/feedback_screen.dart';

class SmartReviewDialog extends StatefulWidget {
  const SmartReviewDialog({super.key});

  @override
  State<SmartReviewDialog> createState() => _SmartReviewDialogState();
}

class _SmartReviewDialogState extends State<SmartReviewDialog> {
  int _selectedRating = 0;
  int _hoveredRating = 0;
  bool _isActionRevealed = false;

  // Dual Confetti Cannons for multi-burst celebratory crescendo (minimum 2 times)
  late ConfettiController _confettiController1;
  late ConfettiController _confettiController2;
  Timer? _revealTimer;
  Timer? _secondConfettiTimer;

  // Platinum Palette Tokens
  static const Color platinumLight = Color(0xFFFFFFFF);
  static const Color platinumBase = Color(0xFFE5E4E2);
  static const Color platinumSilver = Color(0xFFB0B4B8);
  static const Color charcoalDark = Color(0xFF1E1E2C);

  @override
  void initState() {
    super.initState();
    _confettiController1 = ConfettiController(
      duration: const Duration(milliseconds: 1400),
    );
    _confettiController2 = ConfettiController(
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _secondConfettiTimer?.cancel();
    _confettiController1.dispose();
    _confettiController2.dispose();
    super.dispose();
  }

  void _onRatingSelected(int rating) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedRating = rating;
    });

    if (rating >= 4) {
      _triggerCelebrationBursts();
    } else {
      _confettiController1.stop();
      _confettiController2.stop();
      _secondConfettiTimer?.cancel();
    }

    // Pacing delay before revealing action area so the transition is gentle and does not shock the user
    if (!_isActionRevealed) {
      _revealTimer?.cancel();
      _revealTimer = Timer(const Duration(milliseconds: 420), () {
        if (mounted) {
          setState(() {
            _isActionRevealed = true;
          });
        }
      });
    }
  }

  void _triggerCelebrationBursts() {
    // Burst 1: Initial celebration burst
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _selectedRating >= 4) {
        _confettiController1.stop();
        _confettiController1.play();
      }
    });

    // Burst 2: Second celebration volley (guaranteeing minimum 2 bursts)
    _secondConfettiTimer?.cancel();
    _secondConfettiTimer = Timer(const Duration(milliseconds: 680), () {
      if (mounted && _selectedRating >= 4) {
        _confettiController2.stop();
        _confettiController2.play();
      }
    });
  }

  Future<void> _handleStoreReview() async {
    Navigator.of(context).pop();
    await SmartReviewService.instance.requestStoreReview();
    if (mounted) {
      AppSnackBar.show(
        context,
        message: 'Thank you for your royal support! 👑',
        isSuccess: true,
      );
    }
  }

  void _handleFeedbackNavigation() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(initialRating: _selectedRating),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Disappointed 😞';
      case 2:
        return 'Needs Work 😕';
      case 3:
        return "It's Okay 😐";
      case 4:
        return 'Really Fun! 😊';
      case 5:
        return 'Royally Epic! 👑✨';
      default:
        return 'Tap a star to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    final storeName = isIOS ? 'App Store' : 'Google Play';
    final activeRating = _hoveredRating > 0 ? _hoveredRating : _selectedRating;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            borderRadius: 24,
            showGlow: true,
            glowColor: platinumBase,
            color: AppColors.systemBackground.withValues(alpha: 0.92),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Close button at top right
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),

                      // Crown Icon with metallic radial glow
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              platinumBase.withValues(alpha: 0.35),
                              platinumSilver.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          ),
                          border: Border.all(
                            color: platinumBase.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: platinumBase.withValues(alpha: 0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.military_tech_rounded,
                            size: 38,
                            color: platinumBase,
                          ),
                        ),
                      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                      const SizedBox(height: 14),

                      const Text(
                        'ENJOYING LUDO PRINCE?',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: platinumLight,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Your experience helps shape the game!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 18),

                      // 5 Interactive Platinum Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starNumber = index + 1;
                          final isFilled = starNumber <= activeRating;

                          return GestureDetector(
                            onTap: _selectedRating == 0
                                ? () => _onRatingSelected(starNumber)
                                : null,
                            child: MouseRegion(
                              onEnter: _selectedRating == 0
                                  ? (_) => setState(() => _hoveredRating = starNumber)
                                  : null,
                              onExit: _selectedRating == 0
                                  ? (_) => setState(() => _hoveredRating = 0)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: AnimatedScale(
                                  scale: isFilled ? 1.18 : 1.0,
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutBack,
                                  child: ShaderMask(
                                    shaderCallback: (bounds) {
                                      return LinearGradient(
                                        colors: isFilled
                                            ? [platinumLight, platinumBase, platinumSilver]
                                            : [
                                                Colors.white.withValues(alpha: 0.3),
                                                Colors.white.withValues(alpha: 0.15),
                                              ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ).createShader(bounds);
                                    },
                                    child: Icon(
                                      isFilled
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 44,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ).animate().fadeIn(delay: 150.ms),

                      const SizedBox(height: 10),

                      // Reaction Text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          _getRatingLabel(activeRating),
                          key: ValueKey(activeRating),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: activeRating > 0
                                ? platinumBase
                                : Colors.white38,
                          ),
                        ),
                      ),

                      // Progressive In-Place Action Section (Smoothly, non-shockingly expands after pacing delay)
                      if (_isActionRevealed && _selectedRating > 0) ...[
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeInOutCubic,
                          switchOutCurve: Curves.easeInOutCubic,
                          child: _selectedRating >= 4
                              ? _buildPositiveActionArea(storeName)
                              : _buildConstructiveActionArea(),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Maybe Later',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Confetti Cannon 1 (Top-Left, fires Burst 1)
          Positioned(
            top: -12,
            left: 20,
            child: ConfettiWidget(
              confettiController: _confettiController1,
              blastDirection: -pi / 3,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 25,
              emissionFrequency: 0.05,
              gravity: 0.22,
              colors: const [
                Color(0xFFFFFFFF), // Pure White
                Color(0xFFE5E4E2), // Platinum
                Color(0xFFB0B4B8), // Silver
                Color(0xFF00D1FF), // Cyan Sparkle
                Color(0xFFFFD700), // Royal Gold
              ],
            ),
          ),

          // Confetti Cannon 2 (Top-Right, fires Burst 2 crescendo)
          Positioned(
            top: -12,
            right: 20,
            child: ConfettiWidget(
              confettiController: _confettiController2,
              blastDirection: -2 * pi / 3,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 28,
              emissionFrequency: 0.05,
              gravity: 0.22,
              colors: const [
                Color(0xFFFFFFFF), // Pure White
                Color(0xFFE5E4E2), // Platinum
                Color(0xFFB0B4B8), // Silver
                Color(0xFF00D1FF), // Cyan Sparkle
                Color(0xFFFFD700), // Royal Gold
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Progressive Action Area for High Ratings (4 or 5 stars)
  Widget _buildPositiveActionArea(String storeName) {
    return Column(
      key: const ValueKey('positive_action'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your review on the $storeName helps fellow players discover Ludo Prince and supports new modes and continuous updates!',
          style: TextStyle(
            fontSize: 13,
            height: 1.42,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.82),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Platinum Metallic Gradient Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _handleStoreReview,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: platinumBase.withValues(alpha: 0.4),
              backgroundColor: Colors.transparent,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    platinumLight,
                    platinumBase,
                    platinumSilver,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: charcoalDark,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RATE ON $storeName'.toUpperCase(),
                      style: const TextStyle(
                        color: charcoalDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Maybe Later',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.08, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }

  // Progressive Action Area for Lower Ratings (1, 2, or 3 stars) - NO STORE LINKS
  Widget _buildConstructiveActionArea() {
    return Column(
      key: const ValueKey('constructive_action'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "We want to make Ludo Prince a 5-star experience for you. Help us improve with your direct feedback!",
          style: TextStyle(
            fontSize: 13,
            height: 1.42,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.82),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Private Feedback Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _handleFeedbackNavigation,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: platinumBase.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              elevation: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: platinumLight,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'TELL US HOW TO IMPROVE',
                  style: TextStyle(
                    color: platinumLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Not Now',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.08, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}
