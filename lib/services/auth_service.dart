import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:ludo_prince/utils/app_logger.dart';
import 'package:flutter/services.dart';
import 'presence_service.dart';
import 'social_service.dart';
import 'profile_service.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Stream<User?> get authStateChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message:
              'Google Sign-In failed to retrieve an ID token from authentication provider.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
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
        // Try linking anonymous session to permanent credential
        final cred = await user.linkWithCredential(credential);
        await _auth.currentUser?.reload();
        final linkedUser = _auth.currentUser ?? cred.user;
        if (linkedUser != null) {
          await _syncProfileAfterLinking(linkedUser);
        }
        return cred;
      } on FirebaseAuthException catch (e) {
        // If credential already belongs to an existing account, rethrow with the
        // credential attached so the UI can prompt the user with the Switch Account warning dialog!
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          throw FirebaseAuthException(
            code: 'credential-already-in-use',
            message: e.message,
            credential: credential,
          );
        }
        rethrow;
      }
    } else {
      return await signInWithCredential(credential);
    }
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    final cred = await _auth.signInWithCredential(credential);
    final signedInUser = _auth.currentUser ?? cred.user;
    if (signedInUser != null) {
      await _syncProfileAfterLinking(signedInUser);
    }
    return cred;
  }

  Future<void> _syncProfileAfterLinking(User user) async {
    try {
      final currentProfile = await profileService.getUserProfile(user.uid);
      final newName = user.displayName;
      final newEmail = user.email;
      final newPhoto = user.photoURL;

      if (currentProfile == null) {
        final newProfile = UserProfile(
          uid: user.uid,
          displayName: newName ?? 'Player ${user.uid.substring(0, 4)}',
          email: newEmail,
          photoURL: newPhoto,
          createdAt: DateTime.now(),
        );
        await profileService.createOrUpdateProfile(newProfile);
      } else {
        bool needsUpdate = false;
        String? updatedName = currentProfile.displayName;
        if ((updatedName == null ||
                updatedName.startsWith('Player ') ||
                updatedName.startsWith('Guest #')) &&
            newName != null &&
            newName.isNotEmpty) {
          updatedName = newName;
          needsUpdate = true;
        }
        String? updatedEmail = currentProfile.email ?? newEmail;
        if (updatedEmail != currentProfile.email) needsUpdate = true;
        String? updatedPhoto = currentProfile.photoURL ?? newPhoto;
        if (updatedPhoto != currentProfile.photoURL) needsUpdate = true;

        if (needsUpdate) {
          await profileService.createOrUpdateProfile(
            currentProfile.copyWith(
              displayName: updatedName,
              email: updatedEmail,
              photoURL: updatedPhoto,
              lastActive: DateTime.now(),
            ),
          );
        }
      }
      await socialService.init();
    } catch (e) {
      AppLogger.error('Error syncing profile after linking: $e');
    }
  }

  Future<void> signOut() async {
    try {
      // We no longer manually update presence here. 
      // The Firebase onDisconnect trigger will automatically and instantly 
      // mark the user as offline when _auth.signOut() severs the connection.

      await _auth.signOut();

      // Re-sign in anonymously as requested
      await signInAnonymously();

      // Re-init services to start listeners for the new anonymous user
      presenceService.setPresence();
      await socialService.init();
    } catch (e) {
      AppLogger.error('Error during sign out: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.isAnonymous) return;

      final uid = user.uid;

      // 1. Set offline status is handled automatically by onDisconnect 
      // when the auth user is deleted in step 3.

      // 2. Delete Firestore profile
      try {
        await profileService.deleteProfile(uid).timeout(const Duration(seconds: 3));
      } catch (e) {
        AppLogger.error('Could not delete profile from Firestore: $e');
      }

      // 3. Delete Firebase Auth user
      await user.delete();

      // 4. Re-sign in anonymously
      await signInAnonymously();

      // 5. Re-init services
      presenceService.setPresence();
      await socialService.init();
    } catch (e) {
      AppLogger.error('Error deleting account: $e');
      rethrow;
    }
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
    if (e is GoogleSignInException &&
        e.code == GoogleSignInExceptionCode.canceled) {
      return true;
    }
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
