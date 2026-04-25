// Centralised Riverpod providers for all platform services.
//
// During migration the underlying services still use their `final` singleton
// instances. New code should access services via `ref.read(xxxProvider)`
// rather than importing the singleton directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/services/network_service.dart';
import 'package:ludo_prince/services/presence_service.dart';
import 'package:ludo_prince/services/social_service.dart';
import 'package:ludo_prince/services/profile_service.dart';
import 'package:ludo_prince/services/matchmaking_service.dart';
import 'package:ludo_prince/services/auth_service.dart';
import 'package:ludo_prince/services/remote_config_service.dart';

// ── Core Firebase ──────────────────────────────────────────────────────────
final firebaseServiceProvider =
    Provider<FirebaseService>((_) => firebaseService);

// ── Auth ────────────────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((_) => authService);

// ── Audio ───────────────────────────────────────────────────────────────────
final audioServiceProvider = Provider<AudioService>((_) => audioService);

// ── Network ─────────────────────────────────────────────────────────────────
final networkServiceProvider = Provider<NetworkService>((_) => networkService);

// ── Presence ────────────────────────────────────────────────────────────────
final presenceServiceProvider =
    Provider<PresenceService>((_) => presenceService);

// ── Social ──────────────────────────────────────────────────────────────────
final socialServiceProvider = Provider<SocialService>((_) => socialService);

// ── Profile ─────────────────────────────────────────────────────────────────
final profileServiceProvider = Provider<ProfileService>((_) => profileService);

// ── Matchmaking ─────────────────────────────────────────────────────────────
final matchmakingServiceProvider =
    Provider<MatchmakingService>((_) => matchmakingService);

// ── Remote Config ───────────────────────────────────────────────────────────
final remoteConfigServiceProvider =
    Provider<RemoteConfigService>((_) => remoteConfigService);
