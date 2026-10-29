import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/services/presence_service.dart';
import 'package:ludo_prince/services/notification_service.dart';
import 'package:ludo_prince/utils/app_logger.dart';

/// Handles all one-time app initialisation before [runApp].
class AppInitializer {
  AppInitializer._();

  /// Returns whether the user has completed onboarding.
  static Future<bool> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch framework errors and present them
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      AppLogger.error('[FlutterError] ${details.exception}', details.stack);
    };

    // Catch unhandled async errors to prevent crashes/lost connection
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger.error('[PlatformDispatcher] Unhandled async error: $error', stack);
      return true; // Mark handled to prevent app termination
    };

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    await firebaseService.initialize();

    try {
      await GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? '264745171932-8cb0f3leuo7lhheqder6attdgmoekp31.apps.googleusercontent.com'
            : null,
        serverClientId:
            '264745171932-8i2apv189ojnm1i4eee4ghe3s18hs9b9.apps.googleusercontent.com',
      );
    } catch (e) {
      AppLogger.debug('GoogleSignIn init deferred or offline: $e');
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

    try {
      await notificationService.init();
    } catch (e) {
      AppLogger.error('NotificationService init error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    audioService.playBGM();
    presenceService.setPresence();

    return hasSeenOnboarding;
  }
}
