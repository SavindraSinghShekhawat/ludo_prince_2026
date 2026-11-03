import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/core/widgets/app_dialog_layout.dart';
import 'package:ludo_prince/core/widgets/app_button.dart';
import 'package:ludo_prince/core/widgets/app_snackbar.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart';
import 'package:ludo_prince/games/ludo/ui/widgets/player_count_selector.dart';
import 'package:ludo_prince/games/ludo/ui/widgets/game_mode_selector.dart';
import 'package:ludo_prince/providers/auth_provider.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/services/matchmaking_service.dart';
import 'package:ludo_prince/services/social_service.dart';
import 'package:ludo_prince/core/constants/firebase_paths.dart';
import 'package:ludo_prince/ui/screens/lobby_screen.dart';

class FriendGameSetupDialog extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final List<String> targetUids;
  final List<String> targetNames;
  final int initialMaxPlayers;
  final GameMode initialGameMode;
  final String actionButtonLabel;
  final void Function(String gameId)? onSuccess;

  const FriendGameSetupDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.targetUids,
    required this.targetNames,
    this.initialMaxPlayers = 2,
    this.initialGameMode = GameMode.classic,
    this.actionButtonLabel = 'CREATE & INVITE',
    this.onSuccess,
  });

  @override
  ConsumerState<FriendGameSetupDialog> createState() =>
      _FriendGameSetupDialogState();
}

class _FriendGameSetupDialogState extends ConsumerState<FriendGameSetupDialog> {
  late int _maxPlayers;
  late GameMode _gameMode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _maxPlayers = widget.initialMaxPlayers.clamp(2, 4);
    _gameMode = (_maxPlayers == 4) ? widget.initialGameMode : GameMode.classic;
  }

  Future<void> _handleStart() async {
    setState(() => _isLoading = true);
    try {
      final playerName = ref.read(displayNameProvider);

      // 1. Create the private game with the chosen settings
      final gameId = await matchmakingService.createGame(
        maxPlayers: _maxPlayers,
        isPrivate: true,
        gameMode: _gameMode,
        playerName: playerName,
      );

      // 2. Fetch joining code
      final gameSnap = await firebaseService.database
          .ref()
          .child(FirebasePaths.session('ludo', gameId))
          .get();

      if (!gameSnap.exists) {
        throw Exception("Failed to initialize game session node.");
      }

      final gameData = Map<String, dynamic>.from(gameSnap.value as Map);
      final joiningCode = gameData['joiningCode']?.toString();

      if (joiningCode == null) {
        throw Exception("No room joining code generated.");
      }

      // 3. Send invites to all target friends
      for (final uid in widget.targetUids) {
        await socialService.sendInvite(
          targetUid: uid,
          gameId: gameId,
          joiningCode: joiningCode,
        );
      }

      // 4. Update own presence
      await socialService.updatePresence(UserStatus.inLobby, gameId: gameId);

      if (!mounted) return;

      final navigator = Navigator.of(context);
      navigator.pop();

      // Trigger custom callback if provided (e.g. game over dialog replacement)
      if (widget.onSuccess != null) {
        widget.onSuccess!(gameId);
      } else {
        navigator.push(
          ScaleFadePageRoute(
            page: LobbyScreen(
              initialGameId: gameId,
              isHost: true,
              isQuickMatch: false,
            ),
            settings: const RouteSettings(name: '/lobby'),
          ),
        );
      }

      final successMsg = widget.targetNames.isNotEmpty
          ? 'Challenge sent to ${widget.targetNames.join(", ")}!'
          : 'New room created!';
      AppSnackBar.show(context, message: successMsg, isSuccess: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.show(
          context,
          message: 'Failed to create room: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogLayout(
      header: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryCyan.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.primaryCyan.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: AppColors.primaryCyan,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      body: [
        if (widget.targetNames.isNotEmpty) ...[
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: widget.targetNames.map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.starPlatinum.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.starPlatinum.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person,
                        size: 14,
                        color: AppColors.starPlatinum,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
        const Text(
          'SELECT NUMBER OF PLAYERS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 24),
        const Text(
          'SELECT GAME MODE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        GameModeSelector(
          currentMode: _gameMode,
          isTeamModeEnabled: _maxPlayers == 4,
          onModeChanged: (mode) {
            setState(() {
              _gameMode = mode;
            });
          },
        ),
        if (_maxPlayers > (widget.targetUids.length + 1)) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.primaryCyan,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Room will open with $_maxPlayers slots. You can invite more friends from the lobby.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
      footer: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AppButton(
              text: widget.actionButtonLabel,
              fontSize: 13,
              isLoading: _isLoading,
              color: AppColors.starPlatinum,
              onTap: _isLoading ? null : _handleStart,
            ),
          ),
        ],
      ),
    );
  }
}
