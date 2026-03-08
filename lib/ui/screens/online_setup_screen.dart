import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/services/matchmaking_service.dart';
import 'package:ludo_prince/services/presence_service.dart';
import 'package:ludo_prince/models/game_state.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/models/token.dart';
import 'package:ludo_prince/controllers/ludo_controller.dart';
import 'package:ludo_prince/controllers/src/firebase_event_provider.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'ludo_screen.dart';

class OnlineSetupScreen extends ConsumerStatefulWidget {
  const OnlineSetupScreen({super.key});

  @override
  ConsumerState<OnlineSetupScreen> createState() => _OnlineSetupScreenState();
}

class _OnlineSetupScreenState extends ConsumerState<OnlineSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String? _gameId;
  bool _isLoading = false;
  Stream<GameState>? _gameStream;

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available in prefs (optional)
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    presenceService.stopTracking();
    super.dispose();
  }

  void _createGame() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final id = await matchmakingService.createGame(_nameController.text);
      presenceService.startTracking(id);
      setState(() {
        _gameId = id;
        _gameStream = matchmakingService.listenToGame(id);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _isLoading = false);
    }
  }

  void _joinGame() async {
    if (_nameController.text.isEmpty || _codeController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final id = _codeController.text.trim();
      await matchmakingService.joinGame(id, _nameController.text);
      presenceService.startTracking(id);
      setState(() {
        _gameId = id;
        _gameStream = matchmakingService.listenToGame(id);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _isLoading = false);
    }
  }

  void _startGame() async {
    if (_gameId == null) return;
    try {
      await matchmakingService.startGame(_gameId!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _onGameStarted(GameState state) {
    if (!mounted) return;

    // Build the configuration for LudoController
    Map<PlayerSlot, PlayerSetupConfig> config = {};
    PlayerSlot? mySlot;

    final myUid = matchmakingService.currentUserId;

    for (var player in state.players) {
      final isMe = player.userId == myUid;
      if (isMe) mySlot = player.slot;

      config[player.slot] = PlayerSetupConfig(
        name: player.name,
        type: isMe ? PlayerType.localHuman : PlayerType.remoteHuman,
      );
    }

    // Navigate to LudoScreen with the overridden game controller
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ProviderScope(
          overrides: [
            gameControllerProvider.overrideWithValue(
              LudoController(
                config,
                gameId: state.gameId,
                localPlayerSlot: mySlot,
                eventProvider: FirebaseEventProvider(state.gameId),
              ),
            ),
          ],
          child: const LudoScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_gameId != null && _gameStream != null) {
      return _buildLobby();
    }

    return _buildInitialInput();
  }

  Widget _buildInitialInput() {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
          title: const Text("Online Multiplayer"),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Your Nickname",
                    filled: true,
                    fillColor: const Color(0xFF2A2A3D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _isLoading ? null : _createGame,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Create New Game",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("OR JOIN",
                            style: TextStyle(color: Colors.white54))),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: "Enter 6-digit Game ID",
                    filled: true,
                    fillColor: const Color(0xFF2A2A3D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _isLoading ? null : _joinGame,
                  child: const Text("Join Game",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLobby() {
    return StreamBuilder<GameState>(
      stream: _gameStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text("Error: ${snapshot.error}")));
        }
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final state = snapshot.data!;

        // If game started, navigate!
        if (state.status == GameStatus.playing) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _onGameStarted(state));
        }

        final myUid = matchmakingService.currentUserId;
        final isHost = state.hostId == myUid;

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E2C),
          appBar: AppBar(
            title: Text("Game Lobby: $_gameId"),
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _gameId ?? ""));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Game ID copied!")));
                },
              )
            ],
          ),
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Waiting for players...",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontStyle: FontStyle.italic),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.players.length,
                  itemBuilder: (context, index) {
                    final player = state.players[index];
                    final isMe = player.userId == myUid;

                    return Card(
                      color: const Color(0xFF2A2A3D),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getSlotColor(player.slot),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          "${player.name}${isMe ? ' (You)' : ''}",
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        trailing: state.hostId == player.userId
                            ? const Icon(Icons.star, color: Colors.amber)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: isHost
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed:
                            state.players.length >= 2 ? _startGame : null,
                        child: const Text("Start Game",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      )
                    : const Text(
                        "Waiting for host to start...",
                        style: TextStyle(color: Colors.white54),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getSlotColor(PlayerSlot slot) {
    switch (slot) {
      case PlayerSlot.slot1:
        return Colors.blue;
      case PlayerSlot.slot2:
        return Colors.yellow.shade700;
      case PlayerSlot.slot3:
        return Colors.green;
      case PlayerSlot.slot4:
        return Colors.red;
    }
  }
}
