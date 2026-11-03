import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/utils/app_logger.dart';
import '../models/user_profile.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});

final displayNameProvider = Provider<String>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile?.displayName != null &&
      userProfile!.displayName!.isNotEmpty) {
    return userProfile.displayName!;
  }

  final user = ref.watch(authStateProvider).value;
  if (user == null) return "Guest";

  if (user.displayName != null && user.displayName!.isNotEmpty) {
    return user.displayName!;
  }

  final uid = user.uid;
  final shortUid = uid.length > 4 ? uid.substring(uid.length - 4) : uid;
  return "Guest #${shortUid.toUpperCase()}";
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  // Use Firestore snapshots to get real-time profile updates
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) {
          return UserProfile(
            uid: user.uid,
            displayName: user.displayName,
            email: user.email,
            photoURL: user.photoURL,
            isAnonymous: user.isAnonymous,
            createdAt: DateTime.now(),
          );
        }
        try {
          return UserProfile.fromFirestore(doc);
        } catch (e, stack) {
          AppLogger.error('Error parsing UserProfile from Firestore: $e\n$stack');
          return UserProfile(
            uid: user.uid,
            displayName: user.displayName,
            email: user.email,
            photoURL: user.photoURL,
            isAnonymous: user.isAnonymous,
            createdAt: DateTime.now(),
          );
        }
      })
      .handleError((error, stack) {
        AppLogger.error('Firestore userProfile stream error: $error\n$stack');
        return UserProfile(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
          photoURL: user.photoURL,
          isAnonymous: user.isAnonymous,
          createdAt: DateTime.now(),
        );
      });
});
