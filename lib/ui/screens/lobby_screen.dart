import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _activeGameId = widget.initialGameId;
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
              // --- Mode Selection Hidden for Launch ---
              /*
              _buildSectionTitle('CHOOSE GAME MODE'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildModeToggle(GameMode.classic, "CLASSIC", Icons.star_border)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildModeToggle(GameMode.team, "2VS2 TEAM", Icons.groups)),
                ],
              ),
              const SizedBox(height: 32),
              */

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
                      children: [2].map((n) {
                        // Restricted to 2 players for launch
                        final isSelected = _maxPlayers == n;
                        return ChoiceChip(
                          label: Text('$n Players'),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _maxPlayers = n);
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
                    const SizedBox(height: 12),
                    Text(
                      '4-Player & 2vs2 Team Mode Coming Soon!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _buildMainButton(
                            'QUICK MATCH',
                            _joinQueue,
                          ),
                  ],
                ),
              ),
              // --- Private Lobby Hidden for Launch ---
              /*
              if (!widget.isQuickMatch) ...[
                ...
              ]
              */
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyView() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: matchmakingService.watchGame(_activeGameId!),
      builder: (context, gameSnapshot) {
        if (!gameSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (!gameSnapshot.data!.exists) {
          return const Center(
              child: Text("Game not found",
                  style: TextStyle(color: Colors.white)));
        }

        final gameData = gameSnapshot.data!.data()!;
        final status = gameData['status'];

        if (status == 'playing') {
          _redirectToGame();
          return const Center(
              child: Text("Starting game...",
                  style: TextStyle(color: Colors.white)));
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: matchmakingService.watchPlayers(_activeGameId!),
          builder: (context, playersSnapshot) {
            if (!playersSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final players = playersSnapshot.data!.docs;
            final isPrivate = gameData['isPrivate'] ?? true;
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            final hostUid = gameData['hostUid'];
            final isActuallyHost = currentUid == hostUid;
            final maxRequired = gameData['maxPlayers'] ?? _maxPlayers;

            // Auto-start for public games (Quick Match) if full
            if (!isPrivate &&
                isActuallyHost &&
                players.length >= maxRequired &&
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
                    // Quick Match "Searching..." UI
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
                    child: ListView.separated(
                      itemCount: maxRequired,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final slot = 'slot${index + 1}';
                        final playerDoc =
                            players.where((d) => d.id == slot).firstOrNull;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A3D),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: playerDoc != null
                                    ? _getSlotColor(index)
                                        .withValues(alpha: 0.5)
                                    : Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  playerDoc != null
                                      ? Icons.person
                                      : Icons.person_outline,
                                  color: playerDoc != null
                                      ? _getSlotColor(index)
                                      : Colors.white24),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  playerDoc != null
                                      ? playerDoc.data()['name']
                                      : 'Searching...',
                                  style: TextStyle(
                                      color: playerDoc != null
                                          ? Colors.white
                                          : Colors.white24,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (playerDoc != null && playerDoc.id == 'slot1')
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (isActuallyHost && isPrivate)
                    _buildMainButton(
                      'START BATTLE',
                      players.length >= maxRequired
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

  Future<void> _joinQueue() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final gameId = await matchmakingService.joinQueue(_maxPlayers, _gameMode);
      if (mounted) setState(() => _activeGameId = gameId);
    } catch (e) {
      _showError("Matchmaking failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _redirectToGame() {
    Future.microtask(() async {
      final playersSnap = await FirebaseFirestore.instance
          .collection('ludogames')
          .doc(_activeGameId)
          .collection('players')
          .get();
      final currentUserUid = FirebaseAuth.instance.currentUser!.uid;

      PlayerSlot localSlot = PlayerSlot.slot1;
      Map<PlayerSlot, PlayerSetupConfig> config = {};

      for (var doc in playersSnap.docs) {
        final slot = PlayerSlot.values.firstWhere((e) => e.name == doc.id);
        final data = doc.data();
        if (data['uid'] == currentUserUid) localSlot = slot;
        config[slot] =
            PlayerSetupConfig(name: data['name'], type: PlayerType.remoteHuman);
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
}
