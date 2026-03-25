import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/controllers/ludo_controller.dart';
import 'package:ludo_prince/providers/game_provider.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/ui/widgets/robot_icon.dart';
import '../../utils/colors.dart';
import '../../models/game_state.dart';
import '../../models/token.dart';
import '../../models/board_path.dart';
import '../widgets/board_widget.dart';
import '../widgets/token_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/shared_ui.dart';
import '../widgets/custom_dialog_layout.dart';
import 'home_screen.dart';
import '../dialogs/rules_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/game_over_dialog.dart';
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
    return const AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _GameAppBar(),
        body: SafeArea(
          child: _GameBody(),
        ),
      ),
    );
  }
}

class _GameAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _GameAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      leading: BackButton(
        color: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => CustomDialogLayout(
              header: const Text(
                'Exit Game?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              body: const [
                Text(
                  'Are you sure you want to stop playing? Current progress will be lost.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
              footer: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(gameControllerProvider).quitGame();
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const HomeScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side:
                            const BorderSide(color: Colors.redAccent, width: 1),
                      ),
                    ),
                    child: const Text(
                      'Exit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
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
          icon: const Icon(Icons.help_outline, color: Colors.white, size: 28),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const RulesDialog(),
            );
          },
          tooltip: 'Game Rules',
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const SettingsDialog(),
            );
          },
          tooltip: 'Settings',
        ),
      ],
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    );
  }
}

class _GameBody extends ConsumerWidget {
  const _GameBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(gameStreamProvider);

    ref.listen<AsyncValue<GameState>>(gameStreamProvider, (previous, next) {
      next.whenData((state) {
        if (state.isGameOver) {
          final prevWasOver = previous?.value?.isGameOver ?? false;
          if (!prevWasOver) {
            final localSlot = ref.read(gameControllerProvider).localPlayerSlot;
            if (localSlot != null) {
              final me = state.players.firstWhere((p) => p.slot == localSlot,
                  orElse: () => state.players.first);
              if (me.status == PlayerStatus.left) return;
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => GameOverDialog(state: state),
              );
            });
          }
        }
      });
    });

    return asyncState.when(
      data: (gameState) => LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          if (isLandscape) {
            return _LandscapeLayout(gameState: gameState);
          } else {
            return _PortraitLayout(gameState: gameState);
          }
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _PortraitLayout extends StatelessWidget {
  final GameState gameState;
  const _PortraitLayout({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _TopPanels(gameState: gameState),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: _BoardArea(gameState: gameState),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _BottomPanels(gameState: gameState),
              ),
            ),
          ),
          _StatusMessage(message: gameState.message),
          const SizedBox(height: 10),
        ],
      );
    });
  }
}

class _LandscapeLayout extends StatelessWidget {
  final GameState gameState;
  const _LandscapeLayout({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final boardSize = constraints.maxHeight;

      return Row(
        children: [
          Expanded(
            child: _LandscapeSidePanels(gameState: gameState, isLeft: true),
          ),
          SizedBox(
            width: boardSize,
            height: boardSize,
            child: _BoardArea(gameState: gameState),
          ),
          Expanded(
            child: _LandscapeSidePanels(gameState: gameState, isLeft: false),
          ),
        ],
      );
    });
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;
  const _StatusMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _BoardArea extends StatelessWidget {
  final GameState gameState;
  const _BoardArea({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: AppColors.boardGlassBackground,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = constraints.biggest.shortestSide;
                    final cellSize = boardSize / 15;

                    return _BoardInteractionLayer(
                      cellSize: cellSize,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardInteractionLayer extends ConsumerWidget {
  final double cellSize;
  const _BoardInteractionLayer({required this.cellSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDiceRolled = ref.watch(
        gameStreamProvider.select((s) => s.value?.isDiceRolled ?? false));

    return GestureDetector(
      onTapUp: (details) {
        if (!isDiceRolled) return;

        final gameState = ref.read(gameStreamProvider).value;
        if (gameState == null) return;

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
          ref.read(gameControllerProvider).sendMoveIntent(targetToken);
        }
      },
      child: Stack(
        children: [
          BoardWidget(
            gameMode: ref.watch(gameStreamProvider
                .select((s) => s.value?.gameMode ?? GameMode.classic)),
          ),
          _TokenLayer(cellSize: cellSize),
        ],
      ),
    );
  }
}

class _TokenLayer extends ConsumerWidget {
  final double cellSize;
  const _TokenLayer({required this.cellSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players =
        ref.watch(gameStreamProvider.select((s) => s.value?.players));
    final currentTurn =
        ref.watch(gameStreamProvider.select((s) => s.value?.currentTurn));
    final isDiceRolled = ref.watch(
        gameStreamProvider.select((s) => s.value?.isDiceRolled ?? false));
    final diceValue =
        ref.watch(gameStreamProvider.select((s) => s.value?.diceValue ?? 0));

    if (players == null || currentTurn == null) return const SizedBox.shrink();

    final List<Widget> tokenWidgets = [];
    final Map<String, List<Token>> boardOverlaps = {};
    final Map<String, List<Token>> homeOverlaps = {};

    for (var player in players) {
      for (var token in player.tokens) {
        if (token.state == TokenState.board) {
          int absPos =
              BoardPath.getAbsolutePosition(token.slot, token.position);
          String key = "abs_$absPos";
          boardOverlaps.putIfAbsent(key, () => []).add(token);
        } else if (token.state == TokenState.homeStretch ||
            token.state == TokenState.finished) {
          String key = "${token.slot.name}_${token.position}";
          homeOverlaps.putIfAbsent(key, () => []).add(token);
        }
      }
    }

    for (var player in players) {
      final isTurn = currentTurn == player.slot;
      for (var token in player.tokens) {
        bool isMovable = false;
        if (isTurn && isDiceRolled) {
          if (token.state == TokenState.home) {
            isMovable = diceValue == 6;
          } else if (token.state != TokenState.finished) {
            isMovable = token.position + diceValue <= 56;
          }
        }

        Offset overlapOffset = Offset.zero;
        double scaleAdjustment = 1.0;

        if (token.state != TokenState.home) {
          List<Token>? overlapping;
          if (token.state == TokenState.board) {
            int absPos =
                BoardPath.getAbsolutePosition(token.slot, token.position);
            overlapping = boardOverlaps["abs_$absPos"];
          } else {
            overlapping = homeOverlaps["${token.slot.name}_${token.position}"];
          }

          if (overlapping != null && overlapping.length > 1) {
            int index = overlapping
                .indexWhere((t) => t.slot == token.slot && t.id == token.id);
            double tokenSize = cellSize * 0.85;
            double spread = tokenSize * 0.3;

            if (overlapping.length == 2) {
              overlapOffset =
                  Offset((index == 0) ? -spread / 1.5 : spread / 1.5, 0);
            } else if (overlapping.length == 3) {
              if (index == 0) {
                overlapOffset = Offset(0, -spread);
              } else if (index == 1) {
                overlapOffset = Offset(-spread, spread);
              } else {
                overlapOffset = Offset(spread, spread);
              }
            } else if (overlapping.length == 4) {
              overlapOffset = Offset((index % 2 == 1) ? spread : -spread,
                  (index % 4 >= 2) ? spread : -spread);
            } else {
              double multiSpread = spread * 0.8;
              int cols =
                  (overlapping.length > 4 && overlapping.length <= 6) ? 3 : 4;
              int row = index ~/ cols;
              int col = index % cols;
              overlapOffset = Offset(
                  (col - (cols - 1) / 2) * multiSpread,
                  (row - (overlapping.length / cols).ceil() / 2 + 0.5) *
                      multiSpread);
            }
            scaleAdjustment = (overlapping.length > 4) ? 0.6 : 0.8;
          }
        }

        tokenWidgets.add(
          TokenWidget(
            key: ValueKey("token_${token.slot.name}_${token.id}"),
            token: token,
            cellSize: cellSize,
            isMovable: isMovable,
            overlapOffset: overlapOffset,
            scaleAdjustment: scaleAdjustment,
          ),
        );
      }
    }
    return Stack(children: tokenWidgets);
  }
}

class _TopPanels extends StatelessWidget {
  final GameState gameState;
  const _TopPanels({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (gameState.players.any((p) => p.slot == PlayerSlot.slot4))
            _PlayerPanelWrapper(slot: PlayerSlot.slot4)
          else
            const Expanded(child: SizedBox()),
          if (gameState.players.any((p) => p.slot == PlayerSlot.slot3))
            _PlayerPanelWrapper(slot: PlayerSlot.slot3)
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _BottomPanels extends StatelessWidget {
  final GameState gameState;
  const _BottomPanels({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (gameState.players.any((p) => p.slot == PlayerSlot.slot1))
            _PlayerPanelWrapper(slot: PlayerSlot.slot1)
          else
            const Expanded(child: SizedBox()),
          if (gameState.players.any((p) => p.slot == PlayerSlot.slot2))
            _PlayerPanelWrapper(slot: PlayerSlot.slot2)
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _LandscapeSidePanels extends StatelessWidget {
  final GameState gameState;
  final bool isLeft;
  const _LandscapeSidePanels({required this.gameState, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isLeft) ...[
            if (gameState.players.any((p) => p.slot == PlayerSlot.slot4))
              _PlayerPanelWrapper(
                  slot: PlayerSlot.slot4, isLandscape: true, isLeft: true)
            else
              const Expanded(child: SizedBox()),
            if (gameState.players.any((p) => p.slot == PlayerSlot.slot1))
              _PlayerPanelWrapper(
                  slot: PlayerSlot.slot1, isLandscape: true, isLeft: true)
            else
              const Expanded(child: SizedBox()),
          ] else ...[
            if (gameState.players.any((p) => p.slot == PlayerSlot.slot3))
              _PlayerPanelWrapper(
                  slot: PlayerSlot.slot3, isLandscape: true, isLeft: false)
            else
              const Expanded(child: SizedBox()),
            if (gameState.players.any((p) => p.slot == PlayerSlot.slot2))
              _PlayerPanelWrapper(
                  slot: PlayerSlot.slot2, isLandscape: true, isLeft: false)
            else
              const Expanded(child: SizedBox()),
          ],
        ],
      ),
    );
  }
}

class _PlayerPanelWrapper extends ConsumerWidget {
  final PlayerSlot slot;
  final bool isLandscape;
  final bool isLeft;

  const _PlayerPanelWrapper({
    required this.slot,
    this.isLandscape = false,
    this.isLeft = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTurn =
        ref.watch(gameStreamProvider.select((s) => s.value?.currentTurn));
    final player = ref.watch(gameStreamProvider
        .select((s) => s.value?.players.firstWhere((p) => p.slot == slot)));
    final winners =
        ref.watch(gameStreamProvider.select((s) => s.value?.winners ?? []));
    final isDiceRolled = ref.watch(
        gameStreamProvider.select((s) => s.value?.isDiceRolled ?? false));

    if (player == null || currentTurn == null) return const SizedBox();

    final winnerRank = winners.indexOf(slot) + 1;
    final isWinner = winnerRank > 0;

    return _PlayerPanelContent(
      slot: slot,
      player: player,
      currentTurn: currentTurn,
      isWinner: isWinner,
      winnerRank: winnerRank,
      isDiceRolled: isDiceRolled,
      isLandscape: isLandscape,
      isLeft: isLeft,
    );
  }
}

class _PlayerPanelContent extends StatelessWidget {
  final PlayerSlot slot;
  final Player player;
  final PlayerSlot currentTurn;
  final bool isWinner;
  final int winnerRank;
  final bool isDiceRolled;
  final bool isLandscape;
  final bool isLeft;

  const _PlayerPanelContent({
    required this.slot,
    required this.player,
    required this.currentTurn,
    required this.isWinner,
    required this.winnerRank,
    required this.isDiceRolled,
    required this.isLandscape,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final isTurn = slot == currentTurn;
    final Color displayColor = AppColors.getUiColorForSlot(slot);
    final playerName = player.name;
    final isBot = player.type == PlayerType.localBot ||
        player.type == PlayerType.remoteBot;
    final bool isRightAligned = isLandscape
        ? !isLeft
        : (slot == PlayerSlot.slot2 || slot == PlayerSlot.slot3);

    Widget avatarContent = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: displayColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isTurn ? Colors.white : Colors.white70,
            width: isTurn ? 3 : 2),
        boxShadow: [
          if (isTurn)
            BoxShadow(
              color: displayColor.withValues(alpha: 0.8),
              blurRadius: 15,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Center(
        child: isBot
            ? RobotIcon(
                size: 36,
                color: isTurn ? Colors.white : Colors.white70,
              )
            : Icon(
                Icons.person,
                color: isTurn ? Colors.white : Colors.white70,
                size: 40,
              ),
      ),
    );

    Widget avatarBox = isTurn
        ? avatarContent
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scaleXY(
                begin: 1.0,
                end: 1.08,
                duration: 800.ms,
                curve: Curves.easeInOut)
            .shimmer(duration: 2.seconds, color: Colors.white24)
        : avatarContent;

    Widget diceBox;
    if (isWinner) {
      diceBox = _RankBadge(rank: winnerRank);
    } else if (isTurn) {
      diceBox = const SizedBox(
          width: 50,
          height: 50,
          child: Padding(padding: EdgeInsets.all(2), child: DiceWidget()));
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

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String rankText;
    late IconData rankIcon;

    switch (rank) {
      case 1:
        badgeColor = const Color(0xFFE5E4E2);
        rankText = '1st';
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = const Color(0xFFB0B4B8);
        rankText = '2nd';
        rankIcon = Icons.workspace_premium;
        break;
      case 3:
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
}
