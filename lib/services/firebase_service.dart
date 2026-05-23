import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'network_service.dart';
import 'package:ludo_prince/utils/app_logger.dart';
import '../firebase_options.dart';
import 'profile_service.dart';
import '../models/user_profile.dart';
import 'social_service.dart';
import 'remote_config_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  bool _initialized = false;

  late final FirebaseAuth auth;
  late final FirebaseFirestore firestore;
  late final FirebaseDatabase database;
  late final FirebaseFunctions functions;

  int _serverTimeOffset = 0;
  int get serverTimeMillis =>
      DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

  Future<void> initialize() async {
    if (_initialized) return;

    var app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Disable offline persistence as per requirement (to avoid race conditions/stale sync)
    FirebaseDatabase.instance.setPersistenceEnabled(false);

    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
    firestore.settings = const Settings(persistenceEnabled: false);
    functions = FirebaseFunctions.instance;

    if (!kReleaseMode) {
      final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

      database = FirebaseDatabase.instanceFor(
        app: app,
        databaseURL: 'http://$host:9000?ns=ludo-prince-cf74a-default-rtdb',
      );
      // Removed database.useDatabaseEmulator to fix connection drops
      await _setupEmulators(host);
    } else {
      database = FirebaseDatabase.instanceFor(
        app: app,
        databaseURL:
            'https://ludo-prince-cf74a-default-rtdb.europe-west1.firebasedatabase.app?ns=ludo-prince-cf74a-default-rtdb',
      );
    }

    // Initial sign in if needed
    try {
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      } else {
        await auth.currentUser!.reload();
      }
    } catch (e) {
      AppLogger.debug('Initial auth check failed (might be offline): $e');
      try {
        await auth.signOut();
        await auth.signInAnonymously();
      } catch (authError) {
        AppLogger.error(
            'Failed to sign in anonymously (offline mode): $authError');
        // Do not throw; allow app to initialize offline
      }
    }

    // Connect to serverTimeOffset to synchronize clocks
    database.ref('.info/serverTimeOffset').onValue.listen((event) {
      _serverTimeOffset = (event.snapshot.value as num?)?.toInt() ?? 0;
      AppLogger.debug(
        '[FirebaseService] Server time offset updated: $_serverTimeOffset ms',
      );
    });

    // Initialize Remote Config
    await remoteConfigService.initialize();

    // Setup connectivity listener for database
    networkService.connectivityStream.listen((isOnline) async {
      if (isOnline) {
        database.goOnline();
        AppLogger.debug(
            '[FirebaseService] Internet restored: database.goOnline()');

        // If we started completely offline and now have internet, try to auth
        if (auth.currentUser == null) {
          try {
            AppLogger.debug(
                '[FirebaseService] Internet restored, attempting anonymous sign in');
            await auth.signInAnonymously();
          } catch (e) {
            AppLogger.error(
                '[FirebaseService] Sign in failed after internet restored: $e');
          }
        }
      } else {
        database.goOffline();
        AppLogger.debug(
            '[FirebaseService] Internet lost: database.goOffline()');
      }
    });

    _initialized = true;

    // Listen for auth changes and sync profile
    auth.authStateChanges().listen((user) async {
      if (user != null) {
        final profile = await profileService.getUserProfile(user.uid);
        if (profile == null) {
          // Create new profile for first-time sign in (or anonymous)
          final newProfile = UserProfile(
            uid: user.uid,
            displayName:
                user.displayName ?? 'Player ${user.uid.substring(0, 4)}',
            email: user.email,
            photoURL: user.photoURL,
            createdAt: DateTime.now(),
          );
          await profileService.createOrUpdateProfile(newProfile);
        } else {
          await profileService.updateLastActive(user.uid);
        }
        // Initialize Social Presence
        await socialService.init();
      }
    });
  }

  Future<void> _setupEmulators(String host) async {
    try {
      auth.useAuthEmulator(host, 9099);
      firestore.useFirestoreEmulator(host, 8080);
      functions.useFunctionsEmulator(host, 5001);
    } catch (e) {
      AppLogger.error('Firebase Emulator already connected: $e');
    }
  }
}

final firebaseService = FirebaseService();
