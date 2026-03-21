import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'profile_service.dart';
import '../models/user_profile.dart';

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

  Future<void> initialize() async {
    if (_initialized) return;

    var app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable offline persistence
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);

    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
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
      // If reload fails (e.g., emulator data cleared), sign in again
      await auth.signOut();
      await auth.signInAnonymously();
    }

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
      }
    });
  }

  Future<void> _setupEmulators(String host) async {
    try {
      auth.useAuthEmulator(host, 9099);
      firestore.useFirestoreEmulator(host, 8080);
      functions.useFunctionsEmulator(host, 5001);
    } catch (e) {
      debugPrint('Firebase Emulator already connected: $e');
    }
  }
}

final firebaseService = FirebaseService();
