import 'package:firebase_core/firebase_core.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ludo_prince/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/home_screen.dart';
import 'services/audio_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (kDebugMode) {
    try {
      final String host = defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
      print('Using Firebase Emulators at $host');
    } catch (e) {
      print('Error connecting to Firebase Emulators: $e');
    }
  }

  await FlameAudio.audioCache.loadAll([
    'roll.wav',
    'six.wav',
    'move_1.wav',
    'move_2.wav',
    'move_3.wav',
    'move_4.wav',
    'move_5.wav',
    'move_6.wav',
    'die.wav',
    'home.wav',
    'safe.wav',
    'start.wav',
    'victory.wav',
    'bgm.wav',
  ]);

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
      home: widget.hasSeenOnboarding
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
