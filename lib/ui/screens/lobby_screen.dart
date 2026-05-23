import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ludo_prince/ui/widgets/shared_ui.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/services/matchmaking_service.dart';
import 'package:ludo_prince/services/audio_service.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/domain/models/player.dart';
import 'package:ludo_prince/games/ludo/domain/models/token.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_controller.dart';
import 'package:ludo_prince/games/ludo/controller/ludo_multiplayer_controller.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/ui/screens/home_screen.dart';
import 'package:ludo_prince/games/ludo/ui/screens/ludo_screen.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/games/ludo/ui/widgets/player_count_selector.dart';
import 'package:ludo_prince/games/ludo/ui/widgets/game_mode_selector.dart';
import 'package:ludo_prince/ui/dialogs/settings_dialog.dart';
import 'package:ludo_prince/ui/dialogs/profile_dialog.dart';
import 'package:ludo_prince/services/social_service.dart';
import 'package:ludo_prince/services/profile_service.dart';
import '../../models/user_profile.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/utils/share_helper.dart';
import 'package:ludo_prince/providers/auth_provider.dart';
import 'package:ludo_prince/providers/connectivity_provider.dart';
import 'package:ludo_prince/core/constants/firebase_paths.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String? initialGameId;
  final bool isHost;
  final bool isQuickMatch;

  const LobbyScreen({
    super.key,
    this.initialGameId,
    this.isHost = false,
    this.isQuickMatch = true,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  String? _activeGameId;
  bool _isLoading = false;
  int _maxPlayers = 2;
  GameMode _gameMode = GameMode.classic;
  Timer? _heartbeatTimer;
  Timer? _timeoutTimer;
  Timer? _uiTimer;
  int _matchmakingSeconds = 60;
  StreamSubscription<String?>? _matchmakingSubscription;

  @override
  void initState() {
    super.initState();
    _activeGameId = widget.initialGameId;
    if (_activeGameId != null && !widget.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _joinExistingGame();
      });
    }
  }

  Future<void> _joinExistingGame() async {
    setState(() => _isLoading = true);
    final playerName = ref.read(displayNameProvider);
    try {
      await matchmakingService.joinGame(_activeGameId!, playerName: playerName);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to join game: ${e.toString()}");
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          FadeThroughPageRoute(page: const HomeScreen()),
        );
      }
    }
  }

  Future<void> _createPrivateRoom(int maxPlayers, GameMode gameMode) async {
    setState(() => _isLoading = true);
    final playerName = ref.read(displayNameProvider);
    try {
      final gameId = await matchmakingService.createGame(
        maxPlayers: maxPlayers,
        isPrivate: true,
        gameMode: gameMode,
        playerName: playerName,
      );
      if (mounted) {
        setState(() {
          _activeGameId = gameId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to create private room.");
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _timeoutTimer?.cancel();
    _uiTimer?.cancel();
    _matchmakingSubscription?.cancel();
    // Only leave queue if no game was found yet
    if (_activeGameId == null) {
      matchmakingService.leaveQueue(_maxPlayers, _gameMode);
    }
    super.dispose();
  }

  void _startHeartbeat(String gameId) {
    _heartbeatTimer?.cancel();
    socialService.updatePresence(UserStatus.inLobby, gameId: gameId);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      matchmakingService.updateHostHeartbeat(gameId);
    });
  }

  void _startTimeoutTimer(bool isPrivate) {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(seconds: isPrivate ? 600 : 60), () async {
      if (mounted && _activeGameId != null) {
        // Only host deletes the lobby
        final gameEvent = await firebaseService.database
            .ref()
            .child(FirebasePaths.session('ludo', _activeGameId!))
            .once();

        if (gameEvent.snapshot.exists) {
          final gameData = Map<String, dynamic>.from(
            gameEvent.snapshot.value as Map,
          );
          final currentUid = firebaseService.auth.currentUser?.uid;
          if (gameData['hostUid'] == currentUid) {
            await matchmakingService.deleteLobby(_activeGameId!);
          }
        }

        if (mounted) {
          _showError("No active players found. Please try again.");
          Navigator.pushReplacement(
            context,
            FadeThroughPageRoute(page: const HomeScreen()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            _activeGameId == null
                ? (widget.isQuickMatch ? 'BATTLE ONLINE' : 'CREATE ROOM')
                : 'GAME LOBBY',
          ),
          leading: BackButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.of(context).pushReplacement(
                  FadeThroughPageRoute(page: const HomeScreen()),
                );
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () {
                AppDialogLayout.show(
                  context: context,
                  child: const ProfileDialog(),
                );
              },
              tooltip: 'Player Profile',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                AppDialogLayout.show(
                  context: context,
                  child: const SettingsDialog(),
                );
              },
              tooltip: 'Settings',
            ),
          ],
        ),
        body: _activeGameId == null ? _buildSelectionView() : _buildLobbyView(),
      ),
    );
  }

  Widget _buildSelectionView() {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).orientation == Orientation.landscape
              ? 800
              : double.infinity,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: GlassContainer(
                  child: Column(
                    children: [
                      const Text(
                        'SELECT NUMBER OF PLAYERS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      PlayerCountSelector(
                        currentCount: _maxPlayers,
                        onCountChanged: (n) {
                          setState(() {
                            _maxPlayers = n;
                            if (_maxPlayers < 4) {
                              _gameMode = GameMode.classic;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'SELECT GAME MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      GameModeSelector(
                        currentMode: _gameMode,
                        isTeamModeEnabled: _maxPlayers == 4,
                        onModeChanged: (mode) {
                          setState(() {
                            _gameMode = mode;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Consumer(
                builder: (context, ref, child) {
                  final isOnline = ref.watch(isOnlineProvider);

                  return Column(
                    children: [
                      if (!isOnline) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'NO INTERNET CONNECTION',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ).animate().shake(),
                        const SizedBox(height: 16),
                      ],
                      if (_isLoading) ...[
                        if (widget.isQuickMatch) ...[
                          Builder(builder: (context) {
                            final bool isUrgent = _matchmakingSeconds < 10;
                            final Color timerColor =
                                isUrgent ? Colors.amber : Colors.cyanAccent;
                            return Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 70,
                                      height: 70,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween<double>(
                                            begin: 0,
                                            end: _matchmakingSeconds / 60),
                                        duration: const Duration(seconds: 1),
                                        builder: (context, value, _) {
                                          final angle = -math.pi / 2 +
                                              (value * 2 * math.pi);
                                          final dx = 35 + 35 * math.cos(angle);
                                          final dy = 35 + 35 * math.sin(angle);

                                          return Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned.fill(
                                                child:
                                                    CircularProgressIndicator(
                                                  value: value,
                                                  strokeWidth: 2,
                                                  color: timerColor.withValues(
                                                      alpha: 0.6),
                                                  backgroundColor: Colors.white
                                                      .withValues(alpha: 0.05),
                                                ),
                                              ),
                                              if (value > 0)
                                                Positioned(
                                                  left: dx - 3,
                                                  top: dy - 3,
                                                  child: Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: timerColor,
                                                          blurRadius: 6,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    const AppLoadingDots(size: 30),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          }),
                        ],
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          text: _isLoading
                              ? (widget.isQuickMatch
                                  ? 'SEARCHING... ${_matchmakingSeconds}s'
                                  : 'CREATING...')
                              : (widget.isQuickMatch
                                  ? 'QUICK MATCH'
                                  : 'CREATE ROOM'),
                          isLoading: false,
                          color: (!isOnline || _isLoading)
                              ? Colors.white24
                              : AppColors.starPlatinum,
                          onTap: (!isOnline || _isLoading)
                              ? null
                              : () {
                                  if (widget.isQuickMatch) {
                                    _joinQueue(_maxPlayers, _gameMode);
                                  } else {
                                    _createPrivateRoom(_maxPlayers, _gameMode);
                                  }
                                },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyView() {
    return StreamBuilder<DatabaseEvent>(
      stream: matchmakingService.watchGame(_activeGameId!),
      builder: (context, gameSnapshot) {
        if (!gameSnapshot.hasData ||
            gameSnapshot.data?.snapshot.value == null) {
          if (gameSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: MatchmakingLoader(size: 60));
          }
          return const Center(
            child: Text(
              "Game not found",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final gameData = Map<String, dynamic>.from(
          gameSnapshot.data!.snapshot.value as Map,
        );
        final status = gameData['status'];

        if (status == 'playing') {
          _heartbeatTimer?.cancel();
          _timeoutTimer?.cancel();
          _redirectToGame();
          return const Center(
            child: Text(
              "Starting game...",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return StreamBuilder<DatabaseEvent>(
          stream: matchmakingService.watchPlayers(_activeGameId!),
          builder: (context, playersSnapshot) {
            if (!playersSnapshot.hasData ||
                playersSnapshot.data?.snapshot.value == null) {
              return const Center(child: MatchmakingLoader(size: 60));
            }

            final playersMap = Map<String, dynamic>.from(
              playersSnapshot.data!.snapshot.value as Map,
            );
            final players = playersMap.entries.toList();

            final isPrivate = gameData['isPrivate'] ?? true;
            final currentUid = firebaseService.auth.currentUser?.uid;
            final hostUid = gameData['hostUid'];
            final isActuallyHost = currentUid == hostUid;
            final maxRequired = gameData['maxPlayers'] ?? _maxPlayers;
            final currentPlayers = gameData['currentPlayers'] ?? players.length;
            final isLandscape =
                MediaQuery.of(context).orientation == Orientation.landscape;

            if (isActuallyHost && status == 'lobby') {
              if (_heartbeatTimer == null) _startHeartbeat(_activeGameId!);
              if (_timeoutTimer == null) _startTimeoutTimer(isPrivate);
            }

            if (!isPrivate &&
                isActuallyHost &&
                currentPlayers >= maxRequired &&
                status == 'lobby') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                matchmakingService.startGame(_activeGameId!);
              });
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isLandscape ? 1000 : double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                  child: Flex(
                    direction: isLandscape ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- MAIN CONTENT AREA ---
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (isPrivate) ...[
                                      _buildPrivateRoomHeader(
                                        gameData,
                                        _activeGameId!,
                                      ),
                                    ] else ...[
                                      _buildQuickMatchHeader(),
                                    ],
                                    const SizedBox(height: 24),
                                    Text(
                                      isPrivate ? 'PLAYERS' : 'FOUND PLAYERS',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Grid shrinks to fit content inside ScrollView
                                    _buildPlayerGrid(
                                      players,
                                      maxRequired,
                                      _gameMode,
                                    ),

                                    if (isActuallyHost &&
                                        isPrivate &&
                                        !isLandscape)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 24.0,
                                        ),
                                        child: SizedBox(
                                          height: 300,
                                          child: _buildInviteSidebar(
                                            _activeGameId!,
                                            gameData['joiningCode']
                                                    ?.toString() ??
                                                "",
                                            playersMap,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (isActuallyHost && isPrivate)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: AppButton(
                                    text: currentPlayers >= 2
                                        ? 'START BATTLE'
                                        : 'WAITING FOR PLAYERS...',
                                    color: currentPlayers >= 2
                                        ? AppColors.starPlatinum
                                        : Colors.white24,
                                    onTap: currentPlayers >= 2
                                        ? () => matchmakingService.startGame(
                                              _activeGameId!,
                                            )
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // --- SOCIAL SIDEBAR ---
                      if (isActuallyHost && isPrivate && isLandscape) ...[
                        const SizedBox(width: 24, height: 24),
                        Expanded(
                          flex: 4,
                          child: _buildInviteSidebar(
                            _activeGameId!,
                            gameData['joiningCode']?.toString() ?? "",
                            playersMap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrivateRoomHeader(Map<String, dynamic> gameData, String gameId) {
    final code = gameData['joiningCode']?.toString() ?? gameId;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ROOM JOINING CODE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SelectableText(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          color: Colors.white54, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        AppSnackBar.show(context,
                            message: 'Code copied to clipboard!');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppButton(
            text: 'SHARE',
            icon: Icons.share,
            onTap: () => ShareHelper.shareJoiningCode(context, code),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMatchHeader() {
    final bool isUrgent = _matchmakingSeconds < 10;
    final Color timerColor = isUrgent ? Colors.amber : Colors.cyanAccent;

    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _matchmakingSeconds / 60),
                  duration: const Duration(seconds: 1),
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 4,
                      color: timerColor,
                      backgroundColor: Colors.white10,
                    );
                  },
                ),
              ),
              const MatchmakingLoader(size: 80),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'SEARCHING FOR EMPERORS... (${_matchmakingSeconds}s)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isUrgent ? timerColor : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
        ],
      ),
    );
  }

  Widget _buildPlayerGrid(
    List<MapEntry<String, dynamic>> players,
    int maxPlayers,
    GameMode mode,
  ) {
    final slots = PlayerSlotExtension.getSlotsFor(maxPlayers);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLandscape ? 2 : 1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isLandscape ? 3.0 : 4.0,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slotEnum = slots[index];
        final slotStr = slotEnum.name;
        final playerEntry = players.where((d) => d.key == slotStr).firstOrNull;
        final playerData = playerEntry != null
            ? Map<String, dynamic>.from(playerEntry.value as Map)
            : null;

        return _buildPlayerCard(slotEnum, playerData);
      },
    );
  }

  Widget _buildPlayerCard(PlayerSlot slot, Map<String, dynamic>? data) {
    Color slotColor = _getSlotColor(slot.index);
    bool isEmpty = data == null;

    final card = GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      glowColor: isEmpty ? Colors.transparent : slotColor,
      showGlow: !isEmpty,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background slot indicator
            if (!isEmpty)
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: slotColor.withValues(alpha: 0.05),
                ),
              ),

            // Selection/Status glow
            AnimatedContainer(
              duration: 400.ms,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isEmpty
                      ? Colors.white.withValues(alpha: 0.1)
                      : slotColor.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isEmpty
                        ? Colors.white.withValues(alpha: 0.05)
                        : slotColor.withValues(alpha: 0.1),
                    isEmpty
                        ? Colors.transparent
                        : slotColor.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Avatar Area
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isEmpty
                              ? Colors.white.withValues(alpha: 0.05)
                              : slotColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          boxShadow: isEmpty
                              ? []
                              : [
                                  BoxShadow(
                                    color: slotColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                        ),
                        child: Icon(
                          isEmpty ? Icons.add_circle_outline : Icons.person,
                          color: isEmpty ? Colors.white24 : slotColor,
                          size: 24,
                        ),
                      ).animate(target: isEmpty ? 0 : 1).shimmer(delay: 500.ms),

                      const SizedBox(width: 16),

                      // Name Area
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEmpty
                                  ? 'WAITING...'
                                  : (data['name'] ?? 'PLAYER')
                                      .toString()
                                      .toUpperCase(),
                              style: TextStyle(
                                color: isEmpty ? Colors.white38 : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isEmpty)
                              Text(
                                slot == PlayerSlot.slot1
                                    ? 'GAME HOST'
                                    : 'READY TO PLAY',
                                style: TextStyle(
                                  color: slot == PlayerSlot.slot1
                                      ? Colors.amber.withValues(alpha: 0.8)
                                      : slotColor.withValues(alpha: 0.8),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ).animate().fadeIn(duration: 300.ms),
                          ],
                        ),
                      ),

                      if (!isEmpty && slot == PlayerSlot.slot1)
                        const Icon(
                          Icons.stars,
                          color: Colors.amber,
                          size: 20,
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(duration: 2.seconds),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(target: isEmpty ? 0 : 1).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );

    if (isEmpty) {
      return card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
            duration: 2.seconds,
            color: Colors.white.withValues(alpha: 0.1),
          )
          .scale(
            begin: const Offset(0.98, 0.98),
            end: const Offset(1.0, 1.0),
            duration: 2.seconds,
          );
    }

    return card;
  }

  Widget _buildInviteSidebar(
    String gameId,
    String code,
    Map<String, dynamic> joinedPlayers,
  ) {
    final currentUid = firebaseService.auth.currentUser?.uid;
    if (currentUid == null) return const SizedBox.shrink();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.people, color: AppColors.imperialJade, size: 16),
              SizedBox(width: 8),
              Text(
                'INVITE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: profileService.getFriends(currentUid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: MatchmakingLoader(size: 20));
                }
                final joinedUids = joinedPlayers.values
                    .map((p) => (p as Map)['uid'] as String)
                    .toSet();
                final friends = snapshot.data!
                    .where((f) => !joinedUids.contains(f.uid))
                    .toList();
                if (friends.isEmpty) {
                  return Center(
                    child: Text(
                      'No friends found.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 11,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return StreamBuilder<Map<String, dynamic>>(
                      stream: socialService.watchUserStatus(friend.uid),
                      builder: (context, statusSnapshot) {
                        final statusData = statusSnapshot.data;
                        final isOnline = statusData?['status'] == 'online';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white10,
                                    backgroundImage: friend.photoURL != null
                                        ? NetworkImage(friend.photoURL!)
                                        : null,
                                    child: friend.photoURL == null
                                        ? const Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Colors.white54,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    right: -1,
                                    bottom: -1,
                                    child: AppStatusBadge(
                                      isOnline: isOnline,
                                      size: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  friend.displayName ?? 'Unknown Emperor',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.add_circle,
                                  color: isOnline
                                      ? AppColors.imperialJade
                                      : Colors.white10,
                                  size: 20,
                                ),
                                onPressed: isOnline
                                    ? () {
                                        socialService.sendInvite(
                                          targetUid: friend.uid,
                                          gameId: gameId,
                                          joiningCode: code,
                                        );
                                        AppSnackBar.show(
                                          context,
                                          message: 'Invite sent!',
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinQueue(int maxPlayers, GameMode gameMode) async {
    setState(() {
      _isLoading = true;
    });

    final isOnline = ref.read(isOnlineProvider);

    if (!isOnline) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: "No internet connection. Please connect to play online.",
          isError: true,
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      _matchmakingSeconds = 60;
      _uiTimer?.cancel();
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_matchmakingSeconds > 0) {
              _matchmakingSeconds--;
            } else {
              _uiTimer?.cancel();
              _matchmakingSubscription?.cancel();
              matchmakingService.leaveQueue(maxPlayers, gameMode);
              setState(() {
                _isLoading = false;
                _activeGameId = null;
              });
              AppSnackBar.show(
                context,
                message: "Matchmaking failed: no players found",
                isError: true,
              );
            }
          });
        } else {
          timer.cancel();
        }
      });

      final playerName = ref.read(displayNameProvider);
      final assignmentStream = await matchmakingService.joinQueue(
        maxPlayers,
        gameMode,
        playerName: playerName,
      );
      _matchmakingSubscription?.cancel();
      _matchmakingSubscription = assignmentStream.listen((gameId) {
        if (gameId != null && mounted) {
          _uiTimer?.cancel();
          _matchmakingSubscription?.cancel();
          setState(() {
            _activeGameId = gameId;
            _isLoading = false;
          });
          _redirectToGame();
        }
      });
    } catch (e) {
      _uiTimer?.cancel();
      _showError("Matchmaking failed: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _redirectToGame() {
    Future.microtask(() async {
      final playersEvent = await firebaseService.database
          .ref()
          .child(FirebasePaths.players('ludo', _activeGameId!))
          .once();

      final currentUserUid = firebaseService.auth.currentUser!.uid;

      PlayerSlot localSlot = PlayerSlot.slot1;
      Map<PlayerSlot, PlayerSetupConfig> config = {};

      if (playersEvent.snapshot.exists) {
        final playersData = Map<String, dynamic>.from(
          playersEvent.snapshot.value as Map,
        );
        for (var entry in playersData.entries) {
          final slotStr = entry.key;
          final slot = PlayerSlot.values.firstWhere((e) => e.name == slotStr);
          final data = Map<String, dynamic>.from(entry.value as Map);
          if (data['uid'] == currentUserUid) localSlot = slot;
          // All remote players and bots are treated as remoteHuman by local UI, server handles bot turns
          config[slot] = PlayerSetupConfig(
            name: data['name'],
            type: PlayerType.remoteHuman,
          );
        }
      }

      final controller = LudoMultiplayerController(
        config,
        gameId: _activeGameId!,
        localPlayerSlot: localSlot,
      );
      await controller.initializeFromSnapshot();

      if (!mounted) return;
      await audioService.playStart();
      Navigator.pushReplacement(
        context,
        ScaleFadePageRoute(
          page: ProviderScope(
            overrides: [gameControllerProvider.overrideWithValue(controller)],
            child: const LudoScreen(),
          ),
        ),
      );
    });
  }

  // --- UI Helpers ---

  void _showError(String msg) {
    AppSnackBar.show(context, message: msg, isError: true);
  }

  Color _getSlotColor(int index) {
    return AppColors.getUiColorForSlot(PlayerSlot.values[index]);
  }
}
