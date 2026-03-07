import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/models/player.dart';
import '../controllers/ludo_controller.dart';
import '../providers/audio_provider.dart';
import '../models/game_state.dart';
import '../models/token.dart';
import '../models/board_path.dart';
import 'board_widget.dart';
import 'token_widget.dart';
import 'dice_widget.dart';
import 'home_screen.dart';
import '../ui/rules_dialog.dart';
import '../ui/game_over_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LudoScreen extends ConsumerStatefulWidget {
  const LudoScreen({super.key});

  @override
  ConsumerState<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends ConsumerState<LudoScreen>
    with WidgetsBindingObserver {
  late final GameController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(gameControllerProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(gameControllerProvider).pause();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(gameControllerProvider).resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(gameStreamProvider);

    ref.listen<AsyncValue<GameState>>(gameStreamProvider, (previous, next) {
      next.whenData((state) {
        if (state.isGameOver) {
          final prevWasOver = previous?.value?.isGameOver ?? false;
          if (!prevWasOver) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showGameOverDialog(state);
            });
          }
        }
      });
    });

    return asyncState.when(
      data: (gameState) => _buildGame(context, gameState),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  Widget _buildGame(BuildContext context, GameState gameState) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            if (isLandscape) {
              return _buildLandscapeLayout(gameState);
            } else {
              return _buildPortraitLayout(gameState);
            }
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
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
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const RulesDialog(),
            );
          },
          tooltip: 'Game Rules',
        ),
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
    );
  }

  // ── Portrait Layout (unchanged from original) ──
  Widget _buildPortraitLayout(GameState gameState) {
    return Column(
      children: [
        _buildTopPanels(gameState),
        _buildBoard(gameState),
        _buildBottomPanels(gameState),
        const SizedBox(height: 20),
        _buildStatusMessage(gameState),
      ],
    );
  }

  // ── Landscape Layout ──
  Widget _buildLandscapeLayout(GameState gameState) {
    return Row(
      children: [
        // Left side: slot4 (top-left) and slot1 (bottom-left)
        _buildLandscapeSidePanels(gameState, isLeft: true),
        // Center: board + status message
        Expanded(
          child: Column(
            children: [
              _buildBoard(gameState),
              _buildStatusMessage(gameState),
            ],
          ),
        ),
        // Right side: slot3 (top-right) and slot2 (bottom-right)
        _buildLandscapeSidePanels(gameState, isLeft: false),
      ],
    );
  }

  // ── Shared widgets ──

  Widget _buildStatusMessage(GameState gameState) {
    return Padding(
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
    );
  }

  Widget _buildBoard(GameState gameState) {
    return Expanded(
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
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = constraints.biggest.shortestSide;
                final cellSize = boardSize / 15;

                return GestureDetector(
                  onTapUp: (details) {
                    if (!gameState.isDiceRolled) return;

                    bool isMoveValid(Token t, GameState state) {
                      if (t.state == TokenState.home) {
                        return state.diceValue == 6;
                      }
                      if (t.state == TokenState.finished) return false;
                      return t.position + state.diceValue <= 56;
                    }

                    double tapX = details.localPosition.dx / cellSize;
                    double tapY = details.localPosition.dy / cellSize;

                    Token? targetToken;
                    for (var player in gameState.players) {
                      if (player.slot != gameState.currentTurn) continue;
                      if (player.type == PlayerType.localBot ||
                          player.type == PlayerType.remoteBot) {
                        break;
                      }

                      for (var token in player.tokens) {
                        Offset gridPos = BoardPath.getTokenOffset(token);
                        double gridX = gridPos.dx;
                        double gridY = gridPos.dy;

                        if (tapX >= gridX &&
                            tapX < gridX + 1 &&
                            tapY >= gridY &&
                            tapY < gridY + 1) {
                          if (isMoveValid(token, gameState)) {
                            targetToken = token;
                            break;
                          }
                        }
                      }
                      if (targetToken != null) break;
                    }

                    if (targetToken != null) {
                      ref
                          .read(gameControllerProvider)
                          .sendMoveIntent(targetToken);
                    }
                  },
                  child: Stack(
                    children: [
                      const BoardWidget(),
                      for (var player in gameState.players)
                        for (var token in player.tokens)
                          TokenWidget(
                            token: token,
                            cellSize: cellSize,
                          ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showGameOverDialog(GameState state) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GameOverDialog(state: state),
    );
  }

  // ── Portrait panel rows (unchanged) ──

  Widget _buildTopPanels(GameState state) {
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

  Widget _buildBottomPanels(GameState state) {
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

  // ── Landscape side panels ──

  Widget _buildLandscapeSidePanels(GameState state, {required bool isLeft}) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isLeft) ...[
            if (state.players.any((p) => p.slot == PlayerSlot.slot4))
              _buildPlayerPanel(PlayerSlot.slot4, state,
                  isLandscape: true, isLeft: true)
            else
              const Expanded(child: SizedBox()),
            if (state.players.any((p) => p.slot == PlayerSlot.slot1))
              _buildPlayerPanel(PlayerSlot.slot1, state,
                  isLandscape: true, isLeft: true)
            else
              const Expanded(child: SizedBox()),
          ] else ...[
            if (state.players.any((p) => p.slot == PlayerSlot.slot3))
              _buildPlayerPanel(PlayerSlot.slot3, state,
                  isLandscape: true, isLeft: false)
            else
              const Expanded(child: SizedBox()),
            if (state.players.any((p) => p.slot == PlayerSlot.slot2))
              _buildPlayerPanel(PlayerSlot.slot2, state,
                  isLandscape: true, isLeft: false)
            else
              const Expanded(child: SizedBox()),
          ],
        ],
      ),
    );
  }

  // ── Player Panel ──

  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    String rankText;
    late IconData rankIcon;

    switch (rank) {
      case 1:
        // Platinum from GameOverDialog
        badgeColor = const Color(0xFFE5E4E2);
        rankText = '1st';
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        // Silver from GameOverDialog
        badgeColor = const Color(0xFFB0B4B8);
        rankText = '2nd';
        rankIcon = Icons.workspace_premium;
        break;
      case 3:
        // Darker Silver from GameOverDialog
        badgeColor = const Color(0xFF8A8D91);
        rankText = '3rd';
        rankIcon = Icons.workspace_premium;
        break;
      default:
        badgeColor = Colors.redAccent.shade200;
        rankText = '${rank}th';
        rankIcon = Icons.sentiment_very_dissatisfied;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: badgeColor.withValues(alpha: 0.15),
            boxShadow: [
              if (rank <= 3)
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 2),
                ),
            ],
            border: Border.all(
                color: badgeColor.withValues(alpha: 0.8),
                width: rank == 1 ? 2.5 : 1.5),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rankIcon,
              color: badgeColor,
              size: rank == 1 ? 22 : 18,
            ),
            Text(
              rankText,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w900,
                fontSize: rank == 1 ? 14 : 12,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  )
                ],
              ),
            ),
          ],
        ),
      ],
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 2000.ms, color: Colors.white.withValues(alpha: 0.5))
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.05, 1.05),
          duration: 1000.ms,
          curve: Curves.easeInOutSine,
        )
        .then()
        .scale(
          begin: const Offset(1.05, 1.05),
          end: const Offset(0.95, 0.95),
          duration: 1000.ms,
          curve: Curves.easeInOutSine,
        );
  }

  Widget _buildPlayerPanel(PlayerSlot slot, GameState state,
      {bool isLandscape = false, bool isLeft = true}) {
    final isTurn = slot == state.currentTurn;

    Color displayColor;
    switch (slot) {
      case PlayerSlot.slot1:
        displayColor = Colors.blueAccent;

        break;
      case PlayerSlot.slot2:
        displayColor = Colors.amber.shade600;

        break;
      case PlayerSlot.slot3:
        displayColor = Colors.greenAccent.shade700;

        break;
      case PlayerSlot.slot4:
        displayColor = Colors.redAccent;

        break;
    }

    final player = state.players.firstWhere((p) => p.slot == slot);
    final playerName = player.name;
    final isBot = player.type == PlayerType.localBot ||
        player.type == PlayerType.remoteBot;

    // Determine if panel should be right-aligned
    final bool isRightAligned = isLandscape
        ? !isLeft
        : (slot == PlayerSlot.slot2 || slot == PlayerSlot.slot3);

    Widget avatarBox = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: displayColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(isBot ? Icons.smart_toy : Icons.person,
          color: Colors.white, size: 40),
    );

    final int winnerRank = state.winners.indexOf(slot) + 1;
    final bool isWinner = winnerRank > 0;

    Widget diceBox;
    if (isWinner) {
      diceBox = _buildRankBadge(winnerRank);
    } else if (isTurn) {
      diceBox = SizedBox(
          width: 50,
          height: 50,
          child: Container(
              padding: const EdgeInsets.all(2), child: const DiceWidget()));
    } else {
      diceBox = Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30, width: 2),
        ),
      );
    }

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
              color: displayColor.withValues(alpha: 0.5),
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
        color:
            isTurn ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurn ? Colors.white : Colors.white24,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: isRightAligned
            ? [diceBox, const SizedBox(width: 8), avatarBox]
            : [avatarBox, const SizedBox(width: 8), diceBox],
      ),
    );

    return Expanded(
      child: Align(
        alignment:
            isRightAligned ? Alignment.centerRight : Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isRightAligned
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              panelContent,
              Transform.translate(
                offset: Offset(
                  isRightAligned ? -5 : 5,
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
