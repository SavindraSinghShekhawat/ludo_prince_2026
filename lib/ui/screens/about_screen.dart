import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/package_info_provider.dart';
import '../../utils/colors.dart';
import '../widgets/shared_ui.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'ABOUT & FAIRNESS',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.starPlatinum.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 80,
                      color: AppColors.starPlatinum,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Why Ludo Prince Exists",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "In recent years, many players have reported fairness issues with popular digital Ludo applications. Claims of biased dice rolls, rigged algorithms to stimulate in-app purchases, and an unfair advantage given to certain players have ruined the fun of this classic game.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Our Core Values",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildValueRow(
                  Icons.casino,
                  "True Randomness",
                  "Our dice rolls use cryptographically secure random number generators (RNG). Every roll has a pure 1/6 chance. We do not use algorithms to manipulate the outcome based on who is winning or losing.",
                ),
                const SizedBox(height: 16),
                _buildValueRow(
                  Icons.money_off,
                  "100% Free-to-Play",
                  "We do not sell coins or gems. There is no 'pay to win' mechanism. We believe Ludo should be a test of pure luck and equal strategy for everyone.",
                ),
                const SizedBox(height: 16),
                _buildValueRow(
                  Icons.visibility,
                  "Transparency",
                  "No hidden mechanics. The board is clear, the rules are standard, and the execution is honest.",
                ),
                const SizedBox(height: 40),
                Center(
                  child: ref.watch(packageInfoProvider).when(
                        data: (info) => Text(
                          "v${info.version}${kReleaseMode ? '' : '+${info.buildNumber}'}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (e, s) => const SizedBox.shrink(),
                      ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.starPlatinum.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.starPlatinum.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Icon(icon, color: AppColors.starPlatinum, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
