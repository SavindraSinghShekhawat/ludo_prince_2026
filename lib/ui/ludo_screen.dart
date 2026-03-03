import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import '../providers/audio_provider.dart';
import '../models/game_state.dart';
import '../models/token.dart';
import 'board_widget.dart';
import 'token_widget.dart';
import 'dice_widget.dart';
import 'home_screen.dart';

class LudoScreen extends ConsumerStatefulWidget {
  const LudoScreen({super.key});

  @override
  ConsumerState<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends ConsumerState<LudoScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(gameStreamProvider);

    return asyncState.when(
      data: (gameState) => _buildGame(context, gameState),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  Widget _buildGame(BuildContext context, GameState gameState) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF2A2A3D),
                title: const Text(
                  'Exit Game?',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Are you sure you want to stop playing? Current progress will be lost.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Exit',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        title: const Text(
          'Ludo Prince',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final audio = ref.watch(audioProvider);
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      audio.isBgmEnabled ? Icons.music_note : Icons.music_off,
                      color: audio.isBgmEnabled ? Colors.white : Colors.white54,
                    ),
                    onPressed: () => audio.toggleBGM(),
                    tooltip: 'Toggle Background Music',
                  ),
                  IconButton(
                    icon: Icon(
                      audio.isSfxEnabled ? Icons.volume_up : Icons.volume_off,
                      color: audio.isSfxEnabled ? Colors.white : Colors.white54,
                    ),
                    onPressed: () => audio.toggleSFX(),
                    tooltip: 'Toggle Sound Effects',
                  ),
                ],
              );
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Player Panels
            _buildTopPanels(gameState),

            // Board
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize = constraints.biggest.shortestSide;
                        final cellSize = boardSize / 15;

                        return Stack(
                          children: [
                            const BoardWidget(),
                            for (var player in gameState.players)
                              for (var token in player.tokens)
                                TokenWidget(
                                  token: token,
                                  cellSize: cellSize,
                                ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Player Panels
            _buildBottomPanels(gameState),

            const SizedBox(height: 20),

            // Status Message
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                gameState.message,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPanels(GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (state.players.any((p) => p.slot == PlayerSlot.slot1))
            _buildPlayerPanel(PlayerSlot.slot1, state)
          else
            const Expanded(child: SizedBox()),
          if (state.players.any((p) => p.slot == PlayerSlot.slot2))
            _buildPlayerPanel(PlayerSlot.slot2, state)
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildBottomPanels(GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (state.players.any((p) => p.slot == PlayerSlot.slot4))
            _buildPlayerPanel(PlayerSlot.slot4, state)
          else
            const Expanded(child: SizedBox()),
          if (state.players.any((p) => p.slot == PlayerSlot.slot3))
            _buildPlayerPanel(PlayerSlot.slot3, state)
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel(PlayerSlot slot, GameState state) {
    final isTurn = slot == state.currentTurn;

    Color displayColor;
    switch (slot) {
      case PlayerSlot.slot1:
        displayColor = Colors.redAccent;
        break;
      case PlayerSlot.slot2:
        displayColor = Colors.greenAccent.shade700;
        break;
      case PlayerSlot.slot3:
        displayColor = Colors.amber.shade600;
        break;
      case PlayerSlot.slot4:
        displayColor = Colors.blueAccent;
        break;
    }

    final playerName = state.players.firstWhere((p) => p.slot == slot).name;

    Widget avatarBox = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: displayColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 40),
    );

    Widget diceBox = isTurn
        ? const SizedBox(width: 50, height: 50, child: DiceWidget())
        : Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30, width: 2),
            ),
          );

    Widget nameTag = Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isTurn ? Colors.white : Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurn ? displayColor : Colors.white24,
          width: 1.5,
        ),
        boxShadow: [
          if (isTurn)
            BoxShadow(
              color: displayColor.withOpacity(0.5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Text(
        playerName,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isTurn ? Colors.black87 : Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    Widget panelContent = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isTurn ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurn ? Colors.white : Colors.white24,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: slot == PlayerSlot.slot2 || slot == PlayerSlot.slot3
            ? [diceBox, const SizedBox(width: 8), avatarBox]
            : [avatarBox, const SizedBox(width: 8), diceBox],
      ),
    );

    return Expanded(
      child: Align(
        alignment: slot == PlayerSlot.slot2 || slot == PlayerSlot.slot3
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                slot == PlayerSlot.slot2 || slot == PlayerSlot.slot3
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
            children: [
              panelContent,
              Transform.translate(
                offset: Offset(
                  slot == PlayerSlot.slot2 || slot == PlayerSlot.slot3 ? -5 : 5,
                  -10,
                ),
                child: nameTag,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
