import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ludo_prince/services/network_service.dart';
import '../../services/firebase_service.dart';
import '../../services/matchmaking_service.dart';
import '../../services/audio_service.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/token.dart';
import '../../controllers/ludo_controller.dart';
import '../../controllers/multiplayer_controller.dart';
import '../../providers/game_provider.dart';
import 'home_screen.dart';
import 'ludo_screen.dart';
import '../widgets/player_count_selector.dart';
import '../widgets/game_mode_selector.dart';
import '../widgets/shared_ui.dart';
import '../dialogs/profile_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../../utils/colors.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String? initialGameId;
  final bool isHost;
  final bool isQuickMatch;

  const LobbyScreen(
      {super.key,
      this.initialGameId,
      this.isHost = false,
      this.isQuickMatch = true});

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
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      matchmakingService.updateHostHeartbeat(gameId);
    });
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 60), () async {
      if (mounted && _activeGameId != null) {
        // Only host deletes the lobby
        final gameEvent = await firebaseService.database
            .ref()
            .child('ludogames')
            .child(_activeGameId!)
            .once();

        if (gameEvent.snapshot.exists) {
          final gameData =
              Map<String, dynamic>.from(gameEvent.snapshot.value as Map);
          final currentUid = firebaseService.auth.currentUser?.uid;
          if (gameData['hostUid'] == currentUid) {
            await matchmakingService.deleteLobby(_activeGameId!);
          }
        }

        if (mounted) {
          _showError("No active players found. Please try again.");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            }
          },
        ),
        title: Text(
            _activeGameId == null
                ? (widget.isQuickMatch ? 'PLAY ONLINE' : 'PLAY WITH FRIENDS')
                : 'GAME LOBBY',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ProfileDialog(),
              );
            },
            tooltip: 'Player Profile',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const SettingsDialog(),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _activeGameId == null ? _buildSelectionView() : _buildLobbyView(),
    ));
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
                            letterSpacing: 1.5),
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
                            letterSpacing: 1.5),
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
              child: _buildMainButton(
                _isLoading
                    ? 'SEARCHING... (${_matchmakingSeconds}s)'
                    : 'QUICK MATCH',
                _isLoading ? null : () => _joinQueue(_maxPlayers, _gameMode),
                isLoading: _isLoading,
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
              child: Text("Game not found",
                  style: TextStyle(color: Colors.white)));
        }

        final gameData =
            Map<String, dynamic>.from(gameSnapshot.data!.snapshot.value as Map);
        final status = gameData['status'];

        if (status == 'playing') {
          _heartbeatTimer?.cancel();
          _timeoutTimer?.cancel();
          _redirectToGame();
          return const Center(
              child: Text("Starting game...",
                  style: TextStyle(color: Colors.white)));
        }

        return StreamBuilder<DatabaseEvent>(
          stream: matchmakingService.watchPlayers(_activeGameId!),
          builder: (context, playersSnapshot) {
            if (!playersSnapshot.hasData ||
                playersSnapshot.data?.snapshot.value == null) {
              return const Center(child: MatchmakingLoader(size: 60));
            }

            final playersMap = Map<String, dynamic>.from(
                playersSnapshot.data!.snapshot.value as Map);
            final players = playersMap.entries.toList();

            final isPrivate = gameData['isPrivate'] ?? true;
            final currentUid = firebaseService.auth.currentUser?.uid;
            final hostUid = gameData['hostUid'];
            final isActuallyHost = currentUid == hostUid;
            final maxRequired = gameData['maxPlayers'] ?? _maxPlayers;
            final currentPlayers = gameData['currentPlayers'] ?? players.length;

            // Start heartbeat and timeout if host
            if (isActuallyHost && status == 'lobby') {
              if (_heartbeatTimer == null) _startHeartbeat(_activeGameId!);
              if (_timeoutTimer == null) _startTimeoutTimer();
            }

            // Auto-start for public games (Quick Match) if full
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
                  maxWidth: MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? 800
                      : double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isPrivate) ...[
                        GlassContainer(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Text('GAME ID',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              SelectableText(_activeGameId!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1)),
                              const SizedBox(height: 4),
                              const Text('Sharing coming soon...',
                                  style: TextStyle(
                                      color: Colors.white24, fontSize: 10)),
                            ],
                          ),
                        ),
                      ] else ...[
                        GlassContainer(
                          padding: const EdgeInsets.all(40),
                          color: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                          child: Column(
                            children: [
                              const MatchmakingLoader(size: 100),
                              const SizedBox(height: 32),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.deepPurpleAccent,
                                    Colors.white
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'SEARCHING FOR PLAYERS... (${_matchmakingSeconds}s)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              )
                                  .animate(onPlay: (c) => c.repeat())
                                  .shimmer(duration: 2.seconds),
                              const SizedBox(height: 12),
                              Text(
                                'Finding the best match for you...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Text(isPrivate ? 'Players' : 'Found Players',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: (() {
                            List<Widget> listWidgets = [];
                            final slots =
                                PlayerSlotExtension.getSlotsFor(maxRequired);
                            bool isTeam =
                                _gameMode == GameMode.team && maxRequired == 4;

                            List<PlayerSlot> displaySlots = List.from(slots);
                            if (isTeam) {
                              displaySlots = [
                                PlayerSlot.slot1,
                                PlayerSlot.slot3,
                                PlayerSlot.slot2,
                                PlayerSlot.slot4
                              ];
                            }

                            for (int i = 0; i < displaySlots.length; i++) {
                              final slotEnum = displaySlots[i];
                              if (isTeam && i == 0) {
                                listWidgets.add(_buildTeamHeader("TEAM A"));
                              } else if (isTeam && i == 2) {
                                listWidgets.add(_buildVsDivider());
                                listWidgets.add(_buildTeamHeader("TEAM B"));
                              }

                              final slotStr = slotEnum.name;
                              final playerEntry = players
                                  .where((d) => d.key == slotStr)
                                  .firstOrNull;
                              final playerData = playerEntry != null
                                  ? Map<String, dynamic>.from(
                                      playerEntry.value as Map)
                                  : null;

                              listWidgets.add(
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A3D),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: playerData != null
                                            ? _getSlotColor(slotEnum.index)
                                                .withValues(alpha: 0.5)
                                            : Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                          playerData != null
                                              ? Icons.person
                                              : Icons.person_outline,
                                          color: playerData != null
                                              ? _getSlotColor(slotEnum.index)
                                              : Colors.white24),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          playerData != null
                                              ? playerData['name']
                                              : 'Searching...',
                                          style: TextStyle(
                                              color: playerData != null
                                                  ? Colors.white
                                                  : Colors.white24,
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (playerData != null &&
                                          playerEntry!.key == 'slot1') ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.star,
                                            color: Colors.amber, size: 16),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                            return listWidgets;
                          })(),
                        ),
                      ),
                      if (isActuallyHost && isPrivate)
                        _buildMainButton(
                          'START BATTLE',
                          currentPlayers >= maxRequired
                              ? () =>
                                  matchmakingService.startGame(_activeGameId!)
                              : null,
                        ),
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

  // --- Logic ---

  Future<void> _joinQueue(int maxPlayers, GameMode gameMode) async {
    setState(() {
      _isLoading = true;
    });

    final online = await NetworkService.hasInternet();

    if (!online) {
      if (mounted) {
        CustomSnackBar.show(
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
              CustomSnackBar.show(
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

      final assignmentStream =
          await matchmakingService.joinQueue(maxPlayers, gameMode);
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
          .child('ludogames')
          .child(_activeGameId!)
          .child('players')
          .once();

      final currentUserUid = firebaseService.auth.currentUser!.uid;

      PlayerSlot localSlot = PlayerSlot.slot1;
      Map<PlayerSlot, PlayerSetupConfig> config = {};

      if (playersEvent.snapshot.exists) {
        final playersData =
            Map<String, dynamic>.from(playersEvent.snapshot.value as Map);
        for (var entry in playersData.entries) {
          final slotStr = entry.key;
          final slot = PlayerSlot.values.firstWhere((e) => e.name == slotStr);
          final data = Map<String, dynamic>.from(entry.value as Map);
          if (data['uid'] == currentUserUid) localSlot = slot;
          // All remote players and bots are treated as remoteHuman by local UI, server handles bot turns
          config[slot] = PlayerSetupConfig(
              name: data['name'], type: PlayerType.remoteHuman);
        }
      }

      final controller = MultiplayerGameController(config,
          gameId: _activeGameId!, localPlayerSlot: localSlot);
      await controller.initializeFromSnapshot();

      if (!mounted) return;
      await audioService.playStart();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderScope(
            overrides: [gameControllerProvider.overrideWithValue(controller)],
            child: const LudoScreen(),
          ),
        ),
      );
    });
  }

  // --- UI Helpers ---

  Widget _buildMainButton(String title, VoidCallback? onTap,
      {bool isSecondary = false, bool isLoading = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        // Ensure we handle infinite or invalid constraints gracefully
        final baseWidth = maxWidth.isFinite ? maxWidth : 320.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastOutSlowIn, // More premium, fluid curve
                width: isLoading ? 60 : baseWidth,
                height: 60,
                constraints: const BoxConstraints(minWidth: 60),
                decoration: BoxDecoration(
                  color: isSecondary
                      ? Colors.transparent
                      : const Color(0xFFE5E4E2),
                  borderRadius: BorderRadius.circular(isLoading ? 30 : 15),
                  border:
                      isSecondary ? Border.all(color: Colors.white24) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                          alpha: isLoading ? 0.15 : 0.0), // Fade in shadow
                      blurRadius: 15,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isLoading ? null : onTap,
                    borderRadius: BorderRadius.circular(isLoading ? 30 : 15),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Button Title Text
                          AnimatedOpacity(
                            opacity: isLoading ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),

                          // Loader layer (Always there but hidden)
                          IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: isLoading ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // The dots
                                  LudoLoadingDots(size: isLoading ? 35 : 10),

                                  // The progress ring
                                  SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: CircularProgressIndicator(
                                      value: _matchmakingSeconds / 60,
                                      strokeWidth: 2,
                                      backgroundColor:
                                          Colors.black.withValues(alpha: 0.05),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Colors.black26),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Status Feedback (Always present but fades in/out)
            AnimatedOpacity(
              opacity: isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: isLoading ? 50 : 0, // Animate height to avoid jump
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Center(
                      child: Text(
                        'SEARCHING... ${_matchmakingSeconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2.0,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(duration: 2.seconds, color: Colors.white24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showError(String msg) {
    CustomSnackBar.show(context, message: msg, isError: true);
  }

  Color _getSlotColor(int index) {
    return AppColors.getUiColorForSlot(PlayerSlot.values[index]);
  }

  Widget _buildTeamHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: title.contains('A')
                  ? AppColors.player1BlueUI
                  : AppColors.player4RedUI,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVsDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent.withValues(alpha: 0.8),
                  Colors.redAccent.withValues(alpha: 0.8)
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.player1BlueUI.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Text(
              'VS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        ],
      ),
    );
  }
}
