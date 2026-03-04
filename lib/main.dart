import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/onboarding_screen.dart';
import 'ui/home_screen.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  audioService.playBGM(); // Start background music on app launch

  runApp(
    ProviderScope(
      child: LudoPrinceApp(hasSeenOnboarding: hasSeenOnboarding),
    ),
  );
}

class LudoPrinceApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  const LudoPrinceApp({super.key, required this.hasSeenOnboarding});

  @override
  State<LudoPrinceApp> createState() => _LudoPrinceAppState();
}

class _LudoPrinceAppState extends State<LudoPrinceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      audioService.pauseBGM();
    } else if (state == AppLifecycleState.resumed) {
      audioService.resumeBGM();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo Prince',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: widget.hasSeenOnboarding ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
