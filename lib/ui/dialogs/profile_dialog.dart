import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_profile.dart';
import '../screens/auth_screen.dart';
import '../screens/friends_screen.dart';
import '../widgets/shared_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileDialog extends ConsumerWidget {
  const ProfileDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<UserProfile?>(
          future: profileService.getUserProfile(user.uid),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final isAnonymous = user.isAnonymous;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PLAYER PROFILE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.deepPurpleAccent,
                  backgroundImage: profile?.photoURL != null
                      ? NetworkImage(profile!.photoURL!)
                      : null,
                  child: profile?.photoURL == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                Text(
                  profile?.displayName ?? 'Anonymous King',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                if (isAnonymous)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'GUEST ACCOUNT',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 32),
                _buildStatRow(Icons.emoji_events, 'Games Won',
                    '${profile?.gamesWon ?? 0}'),
                const SizedBox(height: 12),
                _buildStatRow(Icons.videogame_asset, 'Games Played',
                    '${profile?.gamesPlayed ?? 0}'),
                const SizedBox(height: 12),
                _buildStatRow(
                    Icons.people, 'Friends', '${profile?.friendsCount ?? 0}'),
                const SizedBox(height: 24),
                _buildActionButton(
                  context,
                  'FRIENDS',
                  Icons.people_outline,
                  Colors.blueAccent.withValues(alpha: 0.8),
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FriendsScreen()));
                  },
                ),
                const SizedBox(height: 12),
                if (isAnonymous)
                  _buildActionButton(
                    context,
                    'LINK ACCOUNT',
                    Icons.link,
                    Colors.deepPurpleAccent,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AuthScreen()));
                    },
                  )
                else
                  _buildActionButton(
                    context,
                    'SIGN OUT',
                    Icons.logout,
                    Colors.redAccent.withValues(alpha: 0.8),
                    () async {
                      await authService.signOut();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}
