import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
