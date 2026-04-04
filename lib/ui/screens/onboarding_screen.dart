import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../widgets/shared_ui.dart';
import '../../utils/colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "WELCOME TO LUDO PRINCE",
      "description":
          "A beautifully crafted, modern take on the classic Ludo board game. Play with friends in vibrant digital arenas.",
      "icon": "casino"
    },
    {
      "title": "100% FAIR & CERTIFIED RNG",
      "description":
          "Tired of rigged dice? Ludo Prince uses true Random Number Generation. No algorithms to favor losing players. Pure luck and strategy.",
      "icon": "gavel"
    },
    {
      "title": "FOREVER FREE FROM CLUTTER",
      "description":
          "No coins, no manipulative micro-transactions, and no hidden biases. Play pure Ludo the way it was meant to be played.",
      "icon": "workspace_premium"
    },
  ];

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'casino':
        return Icons.casino;
      case 'gavel':
        return Icons.gavel;
      case 'workspace_premium':
        return Icons.workspace_premium;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (value) {
                    setState(() {
                      _currentPage = value;
                    });
                  },
                  itemCount: _onboardingData.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIcon(_onboardingData[index]["icon"]!),
                            size: 100,
                            color: AppColors.starPlatinum,
                          ),
                          const SizedBox(height: 40),
                          Text(
                            _onboardingData[index]["title"]!,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _onboardingData[index]["description"]!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _onboardingData.length,
                  (index) => buildDot(index, context),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40.0, vertical: 20.0),
                child: GameButton(
                  text: _currentPage == _onboardingData.length - 1
                      ? "START PLAYING"
                      : "CONTINUE",
                  isPrimary: true,
                  onTap: () async {
                    if (_currentPage == _onboardingData.length - 1) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('hasSeenOnboarding', true);

                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HomeScreen()),
                        );
                      }
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDot(int index, BuildContext context) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 10,
      width: isActive ? 28 : 10,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isActive
            ? AppColors.starPlatinum
            : Colors.white.withValues(alpha: 0.1),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: AppColors.starPlatinum.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
    );
  }
}
