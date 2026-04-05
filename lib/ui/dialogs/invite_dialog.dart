import 'package:flutter/material.dart';
import '../../services/social_service.dart';
import '../widgets/shared_ui.dart';
import '../screens/lobby_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InviteDialog extends StatelessWidget {
  final String inviteId;
  final String fromName;
  final String gameId;
  final String joiningCode;

  const InviteDialog({
    super.key,
    required this.inviteId,
    required this.fromName,
    required this.gameId,
    required this.joiningCode,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videogame_asset_outlined,
                    color: Colors.cyanAccent, size: 60)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(duration: 2.seconds),
            const SizedBox(height: 24),
            Text(
              'ROOM INVITATION',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fromName.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'invited you to play a match!',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      socialService.respondToInvite(inviteId, false);
                      Navigator.pop(context);
                    },
                    child: const Text('DECLINE',
                        style: TextStyle(color: Colors.white38)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await socialService.respondToInvite(inviteId, true);
                      if (!context.mounted) return;
                      Navigator.pop(context);

                      // Navigate to Lobby and clear other screens to avoid stacking games
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LobbyScreen(
                            initialGameId: gameId,
                            isHost: false,
                            isQuickMatch: false,
                          ),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('JOIN NOW',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
