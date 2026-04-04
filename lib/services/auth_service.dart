import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../utils/app_logger.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _linkOrSignIn(credential);
    } catch (e) {
      if (_isCancellation(e)) return null;
      AppLogger.error('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _linkOrSignIn(credential);
    } catch (e) {
      if (_isCancellation(e)) return null;
      AppLogger.error('Error signing in with Apple: $e');
      rethrow;
    }
  }

  Future<UserCredential> _linkOrSignIn(AuthCredential credential) async {
    final User? user = _auth.currentUser;

    if (user != null && user.isAnonymous) {
      try {
        // Try linking first
        return await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          // If already in use, we sign in directly (Switch Account)
          // This will be handled by the UI to confirm, but here we provide the method
          return await _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    } else {
      return await _auth.signInWithCredential(credential);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      AppLogger.error('Error signing in anonymously: $e');
      rethrow;
    }
  }

  bool _isCancellation(dynamic e) {
    final s = e.toString().toLowerCase();
    return s.contains('canceled') ||
        s.contains('cancelled') ||
        s.contains('1000') ||
        s.contains('1001') ||
        s.contains('12501') ||
        (e is PlatformException &&
            (e.code == 'sign_in_canceled' || e.code == '12501'));
  }
}

final authService = AuthService();
