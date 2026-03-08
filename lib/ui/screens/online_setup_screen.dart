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
import 'package:flutter_animate/flutter_animate.dart';

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

  // Platinum Style Constants
  static const Color platinumColor = Color(0xFFE5E4E2);
  static const Color darkBackground = Color(0xFF1E1E2C);
  static const Color surfaceColor = Color(0xFF2A2A3D);
  static const Color platinumShadow = Color(0xFF8B9BB4);

  @override
  void initState() {
    super.initState();
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
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: const Text(
          "Online Matchmaking",
          style: TextStyle(
            color: platinumColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: platinumColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              surfaceColor.withValues(alpha: 0.5),
              darkBackground,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: platinumColor.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.public,
                    color: platinumColor,
                    size: 60,
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 2.seconds, color: Colors.white24)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.1, 1.1),
                        duration: 1.5.seconds,
                        curve: Curves.easeInOut,
                      )
                      .then()
                      .scale(
                        begin: const Offset(1.1, 1.1),
                        end: const Offset(0.9, 0.9),
                        duration: 1.5.seconds,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: 16),
                  const Text(
                    "PREPARE TO PLAY",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: platinumColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: _nameController,
                    label: "Your Nickname",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 24),
                  _buildPlatinumButton(
                    onPressed: _isLoading ? null : _createGame,
                    text: "CREATE GAME",
                    isLoading: _isLoading,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 32),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white10)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "OR JOIN",
                          style: TextStyle(
                            color: Colors.white24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white10)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _codeController,
                    label: "6-Digit Game ID",
                    icon: Icons.grid_3x3,
                    isDigits: true,
                  ),
                  const SizedBox(height: 24),
                  _buildPlatinumButton(
                    onPressed: _isLoading ? null : _joinGame,
                    text: "JOIN GAME",
                    color: Colors.greenAccent.shade700,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).scale(
                  begin: const Offset(0.9, 0.9),
                  curve: Curves.easeOutBack,
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
            backgroundColor: darkBackground,
            body: Center(
                child: Text("Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red))),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: darkBackground,
            body:
                Center(child: CircularProgressIndicator(color: platinumColor)),
          );
        }

        final state = snapshot.data!;

        if (state.status == GameStatus.playing) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _onGameStarted(state));
        }

        final myUid = matchmakingService.currentUserId;
        final isHost = state.hostId == myUid;

        return Scaffold(
          backgroundColor: darkBackground,
          appBar: AppBar(
            title: Text(
              "LOBBY: $_gameId",
              style: const TextStyle(
                color: platinumColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.copy, color: platinumColor),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _gameId ?? ""));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Game ID copied to clipboard")),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: platinumColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "WAITING FOR PLAYERS (${state.players.length}/4)",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: state.players.length,
                  itemBuilder: (context, index) {
                    final player = state.players[index];
                    final isMe = player.userId == myUid;
                    final isHostPlayer = state.hostId == player.userId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isMe ? platinumColor : Colors.white10,
                          width: isMe ? 2 : 1,
                        ),
                        boxShadow: [
                          if (isMe)
                            BoxShadow(
                              color: platinumShadow.withValues(alpha: 0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: _getSlotColor(player.slot),
                            child:
                                const Icon(Icons.person, color: Colors.white),
                          ),
                        ),
                        title: Text(
                          player.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                isMe ? FontWeight.w900 : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          isHostPlayer ? "HOST" : "PLAYER",
                          style: TextStyle(
                            color: isHostPlayer ? Colors.amber : Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        trailing: isMe
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: platinumColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "YOU",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : isHostPlayer
                                ? const Icon(Icons.star, color: Colors.amber)
                                : null,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (index * 150).ms)
                        .slideX(begin: -0.1);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: isHost
                    ? _buildPlatinumButton(
                        onPressed:
                            state.players.length >= 2 ? _startGame : null,
                        text: "START GAME",
                        color: Colors.greenAccent.shade700,
                      )
                        .animate(target: state.players.length >= 2 ? 1 : 0)
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          duration: 300.ms,
                        )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Text(
                          "WAITING FOR HOST TO START...",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 4.seconds),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isDigits = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isDigits ? TextInputType.number : TextInputType.text,
      inputFormatters:
          isDigits ? [FilteringTextInputFormatter.digitsOnly] : null,
      maxLength: isDigits ? 6 : null,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: platinumColor),
        filled: true,
        fillColor: Colors.black26,
        counterText: "",
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: platinumColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildPlatinumButton({
    required VoidCallback? onPressed,
    required String text,
    required Color color,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white10,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
      ),
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
