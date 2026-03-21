import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final displayNameProvider = Provider<String>((ref) {
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
      .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
});
