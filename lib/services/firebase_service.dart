import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

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

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
    functions = FirebaseFunctions.instance;

    if (!kReleaseMode) {
      database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'http://127.0.0.1:9000?ns=ludo-prince-cf74a-default-rtdb',
      );
      // Removed database.useDatabaseEmulator to fix connection drops
      await _setupEmulators();
    } else {
      database = FirebaseDatabase.instance;
    }

    // Initial sign in if needed
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    _initialized = true;
  }

  Future<void> _setupEmulators() async {
    const host = '127.0.0.1';

    try {
      auth.useAuthEmulator(host, 9099);
      firestore.useFirestoreEmulator(host, 8080);
      functions.useFunctionsEmulator(host, 5001);
    } catch (e) {
      // Ignored if already connected
      debugPrint(
          'Firebase Emulator connection error (likely already connected): $e');
    }
  }
}

final firebaseService = FirebaseService();
