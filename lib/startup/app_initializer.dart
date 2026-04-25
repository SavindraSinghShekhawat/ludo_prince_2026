import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/services/presence_service.dart';

/// Handles all one-time app initialisation before [runApp].
class AppInitializer {
  AppInitializer._();

  /// Returns whether the user has completed onboarding.
  static Future<bool> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    await firebaseService.initialize();

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

    audioService.playBGM();
    presenceService.setPresence();

    return hasSeenOnboarding;
  }
}
