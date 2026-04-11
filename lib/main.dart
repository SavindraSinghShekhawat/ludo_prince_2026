import 'dart:async';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/home_screen.dart';
import 'services/audio_service.dart';
import 'services/presence_service.dart';
import 'services/firebase_service.dart';
import 'services/social_service.dart';
import 'services/profile_service.dart';
import 'services/remote_config_service.dart';
import 'ui/dialogs/update_dialog.dart';
import 'ui/widgets/shared_ui.dart';
import 'ui/widgets/top_notification_host.dart';
import 'providers/notification_provider.dart';
import 'models/ludo_notification.dart';
import 'utils/colors.dart';
import 'utils/app_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  await firebaseService.initialize();

  await FlameAudio.audioCache.loadAll([
    'roll.wav',
    'six.wav',
    'move_1.wav',
    'move_2.wav',
    'move_3.wav',
    'move_4.wav',
    'move_5.wav',
    'move_6.wav',
    'die.wav',
    'home.wav',
    'safe.wav',
    'start.wav',
    'victory.wav',
    'bgm.wav',
  ]);

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  audioService.playBGM(); // Start background music on app launch

  presenceService.setPresence();
  runApp(
    ProviderScope(
      child: LudoPrinceApp(hasSeenOnboarding: hasSeenOnboarding),
    ),
  );
}

class LudoPrinceApp extends StatefulWidget {
  final bool hasSeenOnboarding;
  const LudoPrinceApp({super.key, required this.hasSeenOnboarding});

  @override
  State<LudoPrinceApp> createState() => _LudoPrinceAppState();
}

class _LudoPrinceAppState extends State<LudoPrinceApp>
    with WidgetsBindingObserver {
  StreamSubscription? _inviteSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    presenceService.setPresence();

    // Check for App Updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (remoteConfigService.updateStatus != UpdateStatus.none) {
        UpdateDialog.show(
          navigatorKey.currentContext!,
          isForce: remoteConfigService.updateStatus == UpdateStatus.force,
          message: remoteConfigService.updateMessage,
          currentVersion: remoteConfigService.currentVersion,
          newVersion: remoteConfigService.latestVersion,
        );
      }
    });

    // Global listener for game invites
    _inviteSubscription = socialService.watchInvites().listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final invites = Map<String, dynamic>.from(event.snapshot.value as Map);
        final container = ProviderScope.containerOf(context, listen: false);

        for (final entry in invites.entries) {
          final inviteId = entry.key;
          final data = Map<String, dynamic>.from(entry.value as Map);

          if (data['status'] == 'pending') {
            container.read(notificationProvider.notifier).addNotification(
                  LudoNotification(
                    id: inviteId,
                    type: NotificationType.gameInvite,
                    title: 'GAME INVITATION',
                    message:
                        '${data['fromName'] ?? 'Someone'} invited you to play Ludo!',
                    data: {
                      'inviteId': inviteId,
                      'fromName': data['fromName'] ?? 'Someone',
                      'gameId': data['gameId'] ?? '',
                      'joiningCode': data['joiningCode'] ?? '',
                    },
                    timestamp: DateTime.now(),
                  ),
                );
          }
        }
      }
    });

    // Global listener for friend requests
    _requestsSubscription =
        socialService.auth.authStateChanges().listen((user) {
      if (user != null) {
        profileService.getIncomingFriendRequests(user.uid).listen((reqs) {
          final container = ProviderScope.containerOf(context, listen: false);
          for (final req in reqs) {
            container.read(notificationProvider.notifier).addNotification(
                  LudoNotification(
                    id: req.id,
                    type: NotificationType.friendRequest,
                    title: 'FRIEND REQUEST',
                    message:
                        '${req.fromProfile?.displayName ?? 'Someone'} wants to be your friend',
                    data: {'fromUid': req.fromUid},
                    timestamp: req.timestamp,
                  ),
                );
          }
        });
      }
    });
  }

  StreamSubscription? _requestsSubscription;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    presenceService.dispose();
    _inviteSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      audioService.pauseBGM();
    } else if (state == AppLifecycleState.resumed) {
      audioService.resumeBGM();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Ludo Prince',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const CustomSnackBarHost(),
            const TopNotificationHost(),
          ],
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryCyan,
          brightness: Brightness.dark,
          surface: AppColors.systemSurface,
          primary: AppColors.primaryCyan,
          secondary: AppColors.midnightSapphire,
        ),
        scaffoldBackgroundColor: AppColors.systemBackground,
        textTheme:
            GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
          titleLarge: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white, size: 24),
          titleTextStyle: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starPlatinum,
            foregroundColor: AppColors.systemBackground,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.4),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.systemSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          titleTextStyle: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
          contentTextStyle: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: AppColors.primaryCyan.withValues(alpha: 0.6),
                width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
      ),
      home: widget.hasSeenOnboarding
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
