import 'package:flutter/material.dart';
import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _activeGameId = widget.initialGameId;
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _timeoutTimer?.cancel();
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                ? (widget.isQuickMatch ? 'Quick Match' : 'Play with Friends')
                : 'Game Lobby',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: _activeGameId == null ? _buildSelectionView() : _buildLobbyView(),
    );
  }

  Widget _buildSelectionView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('SELECT PLAYERS'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [2, 3, 4].map((n) {
                        final isSelected = _maxPlayers == n;
                        return ChoiceChip(
                          label: Text('$n Players'),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val && _maxPlayers != n) {
                              setState(() {
                                _maxPlayers = n;
                                if (_maxPlayers < 4) {
                                  _gameMode = GameMode.classic;
                                }
                              });
                            }
                          },
                          selectedColor: const Color(0xFFE5E4E2),
                          checkmarkColor: Colors.black,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white24),
                          labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Select Game Mode',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGameModeChip(
                          mode: GameMode.classic,
                          label: 'Classic',
                          description: 'Standard',
                          icon: Icons.person,
                          isEnabled: true,
                        ),
                        const SizedBox(width: 12),
                        _buildGameModeChip(
                          mode: GameMode.team,
                          label: '2vs2 Team',
                          description: '4 Players Only',
                          icon: Icons.group,
                          isEnabled: _maxPlayers == 4,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _buildMainButton(
                            'QUICK MATCH',
                            () => _joinQueue(_maxPlayers, _gameMode),
                          ),
                  ],
                ),
              ),
            ],
          ),
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
            return const Center(child: CircularProgressIndicator());
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
              return const Center(child: CircularProgressIndicator());
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

            return Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isPrivate) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecoration(
                          borderColor:
                              const Color(0xFFE5E4E2).withValues(alpha: 0.3)),
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
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: _cardDecoration(
                          borderColor:
                              Colors.deepPurpleAccent.withValues(alpha: 0.3)),
                      child: const Column(
                        children: [
                          CircularProgressIndicator(
                              color: Colors.deepPurpleAccent),
                          SizedBox(height: 24),
                          Text('SEARCHING FOR PLAYERS...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5)),
                          SizedBox(height: 8),
                          Text('Matchmaking in progress...',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
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
                          ? () => matchmakingService.startGame(_activeGameId!)
                          : null,
                    ),
                ],
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("No internet connection. Please connect to play online."),
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final gameId = await matchmakingService.joinQueue(maxPlayers, gameMode);
      if (mounted) setState(() => _activeGameId = gameId);
    } catch (e) {
      _showError("Matchmaking failed: $e");
    } finally {
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

  Widget _buildSectionTitle(String title) {
    return Text(title,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5));
  }

  BoxDecoration _cardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: const Color(0xFF2A2A3D),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor ?? Colors.white10),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4)),
      ],
    );
  }

  Widget _buildMainButton(String title, VoidCallback? onTap,
      {bool isSecondary = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: (onTap != null && !isSecondary)
            ? [
                BoxShadow(
                  color: const Color(0xFFE5E4E2).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSecondary ? Colors.transparent : const Color(0xFFE5E4E2),
          foregroundColor: isSecondary ? Colors.white : Colors.black,
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: isSecondary
                  ? const BorderSide(color: Colors.white24)
                  : BorderSide.none),
          elevation: 0,
          disabledBackgroundColor: Colors.white10,
        ),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  Color _getSlotColor(int index) {
    switch (index) {
      case 0:
        return Colors.blueAccent;
      case 1:
        return Colors.amber.shade600;
      case 2:
        return Colors.greenAccent.shade700;
      case 3:
        return Colors.redAccent;
      default:
        return Colors.white;
    }
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
              color: title.contains('A') ? Colors.blueAccent : Colors.redAccent,
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
                  color: Colors.blueAccent.withValues(alpha: 0.3),
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

  Widget _buildGameModeChip({
    required GameMode mode,
    required String label,
    required String description,
    required IconData icon,
    required bool isEnabled,
  }) {
    final isSelected = _gameMode == mode;
    final color = isSelected ? const Color(0xFFE5E4E2) : Colors.white70;

    return Tooltip(
      message: isEnabled ? '' : '2vs2 mode requires exactly 4 players',
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                setState(() {
                  _gameMode = mode;
                });
              }
            : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            width: 150,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE5E4E2)
                  : const Color(0xFF2A2A3D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.blueAccent.withValues(alpha: 0.5)
                    : Colors.white10,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF1E1E2C) : color,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF1E1E2C) : color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEnabled ? description : 'Locked',
                  style: TextStyle(
                    color: (isSelected ? const Color(0xFF1E1E2C) : color)
                        .withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
