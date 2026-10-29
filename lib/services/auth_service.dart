import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:ludo_prince/utils/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

      return await _seamlessSignIn(
        credential: credential,
        overrideDisplayName: googleUser.displayName,
      );
    } catch (e) {
      if (_isCancellation(e)) return null;
      AppLogger.error('Error signing in with Google: $e');
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Strips leading/trailing and excess spaces, and caps length to [maxLength].
  String? sanitizeName(String? name, {int maxLength = 18}) {
    if (name == null) return null;
    var cleaned = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }
    return cleaned.isNotEmpty ? cleaned : null;
  }

  String? _deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    if (email.endsWith('@privaterelay.appleid.com')) return null;

    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return null;

    final username = email.substring(0, atIndex);
    // Replace separators like dots, underscores, dashes with spaces
    final cleaned = username.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return null;

    // Capitalize each word cleanly
    final words = cleaned.split(' ');
    final capitalized = words
        .map((w) => w.isNotEmpty
            ? w[0].toUpperCase() +
                (w.length > 1 ? w.substring(1).toLowerCase() : '')
            : '')
        .where((w) => w.isNotEmpty)
        .join(' ');

    return sanitizeName(capitalized);
  }

  Future<String?> _resolveDisplayName({
    String? givenName,
    String? familyName,
    String? userIdentifier,
    String? currentDisplayName,
    String? email,
    String? uid,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Direct from provider (e.g. Apple first-time sign-in)
    final parts = [givenName, familyName]
        .where((p) => p != null && p.trim().isNotEmpty)
        .cast<String>();
    if (parts.isNotEmpty) {
      final directName = sanitizeName(parts.join(' '));
      if (directName != null) {
        if (userIdentifier != null && userIdentifier.isNotEmpty) {
          await prefs.setString('apple_name_$userIdentifier', directName);
        }
        if (uid != null && uid.isNotEmpty) {
          await prefs.setString('apple_name_$uid', directName);
        }
        return directName;
      }
    }

    // 2. Previously cached name on this device
    String? cached;
    if (userIdentifier != null && userIdentifier.isNotEmpty) {
      cached = prefs.getString('apple_name_$userIdentifier');
    }
    if (cached == null && uid != null && uid.isNotEmpty) {
      cached = prefs.getString('apple_name_$uid');
    }
    if (cached != null) {
      final sanitized = sanitizeName(cached);
      if (sanitized != null) return sanitized;
    }

    // 3. Current Firebase Auth displayName if already human-readable
    if (currentDisplayName != null &&
        !currentDisplayName.startsWith('Player ') &&
        !currentDisplayName.startsWith('Guest #')) {
      final sanitized = sanitizeName(currentDisplayName);
      if (sanitized != null) return sanitized;
    }

    // 4. Derive from email (if not Apple Private Relay)
    final fromEmail = _deriveNameFromEmail(email);
    if (fromEmail != null) {
      return fromEmail;
    }

    return null;
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      // Pre-resolve human-readable name from Apple credentials, local device cache, or email
      final resolvedName = await _resolveDisplayName(
        givenName: appleCredential.givenName,
        familyName: appleCredential.familyName,
        userIdentifier: appleCredential.userIdentifier,
        email: appleCredential.email,
      );

      final userCredential = await _seamlessSignIn(
        credential: credential,
        overrideDisplayName: resolvedName,
      );

      final user = userCredential.user;
      if (user != null) {
        final finalName = resolvedName ??
            await _resolveDisplayName(
              email: user.email,
              uid: user.uid,
              currentDisplayName: user.displayName,
            );

        if (finalName != null && finalName.isNotEmpty) {
          if (user.displayName != finalName) {
            await user.updateDisplayName(finalName);
          }
          await _syncProfileAfterLinking(user, overrideDisplayName: finalName);
        }
      }

      return userCredential;
    } catch (e) {
      if (_isCancellation(e)) return null;
      AppLogger.error('Error signing in with Apple: $e');
      rethrow;
    }
  }

  Future<UserCredential> _seamlessSignIn({
    required AuthCredential credential,
    String? overrideDisplayName,
  }) async {
    final User? previousUser = _auth.currentUser;
    UserProfile? guestProfileToMerge;

    // 1. If previous session was an anonymous guest with gameplay stats,
    // preserve the stats so we can merge them into the target account without losing progress.
    if (previousUser != null && previousUser.isAnonymous) {
      try {
        final profile = await profileService.getUserProfile(previousUser.uid);
        if (profile != null &&
            (profile.gamesPlayed > 0 || profile.gamesWon > 0)) {
          guestProfileToMerge = profile;
        }
      } catch (_) {}
    }

    // 2. Directly sign in with the credential!
    // This is 100% reliable, never fails with 'credential-already-in-use',
    // never burns Apple's single-use authorization code, and requires only ONE Face ID prompt!
    final userCredential = await _auth.signInWithCredential(credential);
    final signedInUser = _auth.currentUser ?? userCredential.user;

    if (signedInUser != null) {
      // 3. Sync profile & resolve human-readable display name
      await _syncProfileAfterLinking(
        signedInUser,
        overrideDisplayName: overrideDisplayName,
      );

      // 4. If there were guest games to merge, seamlessly add them to the account!
      if (guestProfileToMerge != null && previousUser != null) {
        try {
          final targetProfile =
              await profileService.getUserProfile(signedInUser.uid);
          if (targetProfile != null) {
            final merged = targetProfile.copyWith(
              gamesPlayed:
                  targetProfile.gamesPlayed + guestProfileToMerge.gamesPlayed,
              gamesWon: targetProfile.gamesWon + guestProfileToMerge.gamesWon,
            );
            await profileService.createOrUpdateProfile(merged);
          }
          // Clean up the orphaned anonymous guest document from Firestore
          await profileService.deleteProfile(previousUser.uid);
        } catch (e) {
          AppLogger.error(
              'Failed to merge guest stats into permanent account: $e');
        }
      }
    }

    return userCredential;
  }

  Future<UserCredential> signInWithCredential(
    AuthCredential credential, {
    String? overrideDisplayName,
  }) async {
    return await _seamlessSignIn(
      credential: credential,
      overrideDisplayName: overrideDisplayName,
    );
  }

  /// Switches accounts for Apple Sign-In.
  /// Apple authorization codes are single-use. Once [linkWithCredential] fails with
  /// 'credential-already-in-use', that authorization code is consumed by Apple.
  /// To switch accounts, we must sign out the temporary anonymous guest session
  /// and trigger a fresh native Apple prompt so Apple generates a new valid code
  /// that signs straight into the existing account.
  Future<UserCredential?> switchAccountWithApple() async {
    await _auth.signOut();
    try {
      final cred = await signInWithApple();
      if (cred == null) {
        await signInAnonymously();
      }
      return cred;
    } catch (e) {
      if (_auth.currentUser == null) {
        await signInAnonymously();
      }
      rethrow;
    }
  }

  /// Switches accounts for Google Sign-In with fresh re-auth fallback.
  Future<UserCredential?> switchAccountWithGoogle() async {
    await _auth.signOut();
    try {
      final cred = await signInWithGoogle();
      if (cred == null) {
        await signInAnonymously();
      }
      return cred;
    } catch (e) {
      if (_auth.currentUser == null) {
        await signInAnonymously();
      }
      rethrow;
    }
  }

  Future<void> syncCurrentProfileIfPlaceholder() async {
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      await _syncProfileAfterLinking(user);
    }
  }

  Future<void> _syncProfileAfterLinking(
    User user, {
    String? overrideDisplayName,
  }) async {
    try {
      final currentProfile = await profileService.getUserProfile(user.uid);
      String? effectiveName = sanitizeName(overrideDisplayName ?? user.displayName);

      // If current name is missing or a placeholder ("Player 1234" / "Guest #1234"),
      // attempt resolution from email, Apple ID cache, etc.
      if (effectiveName == null ||
          effectiveName.isEmpty ||
          effectiveName.startsWith('Player ') ||
          effectiveName.startsWith('Guest #')) {
        final resolved = await _resolveDisplayName(
          email: user.email,
          uid: user.uid,
          currentDisplayName: effectiveName,
        );
        if (resolved != null && resolved.isNotEmpty) {
          effectiveName = sanitizeName(resolved);
          if (effectiveName != null) {
            await user.updateDisplayName(effectiveName);
          }
        }
      }

      final newEmail = user.email;
      final newPhoto = user.photoURL;

      if (currentProfile == null) {
        final newProfile = UserProfile(
          uid: user.uid,
          displayName: effectiveName ?? 'Player ${user.uid.substring(0, 4)}',
          email: newEmail,
          photoURL: newPhoto,
          createdAt: DateTime.now(),
        );
        await profileService.createOrUpdateProfile(newProfile);
      } else {
        bool needsUpdate = false;
        String? updatedName = currentProfile.displayName;

        // Upgrade placeholder names automatically!
        if ((updatedName == null ||
                updatedName.startsWith('Player ') ||
                updatedName.startsWith('Guest #')) &&
            effectiveName != null &&
            effectiveName.isNotEmpty &&
            !effectiveName.startsWith('Player ') &&
            !effectiveName.startsWith('Guest #')) {
          updatedName = effectiveName;
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
    if (e is SignInWithAppleAuthorizationException &&
        e.code == AuthorizationErrorCode.canceled) {
      return true;
    }
    final s = e.toString().toLowerCase();
    return s.contains('canceled') ||
        s.contains('cancelled') ||
        s.contains('1001') ||
        s.contains('12501') ||
        (e is PlatformException &&
            (e.code == 'sign_in_canceled' || e.code == '12501'));
  }
}

final authService = AuthService();
