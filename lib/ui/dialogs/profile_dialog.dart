import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

import '../../providers/auth_provider.dart';

import '../screens/auth_screen.dart';

import '../screens/friends_screen.dart';
import '../widgets/shared_ui.dart';
import '../widgets/custom_dialog_layout.dart';

class ProfileDialog extends ConsumerWidget {
  const ProfileDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final userProfileAsync = ref.watch(userProfileProvider);

    return CustomDialogLayout(
      header: Row(
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
      body: userProfileAsync.when(
        data: (profile) {
          final isAnonymous = user.isAnonymous;
          return [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              backgroundImage: profile?.photoURL != null
                  ? NetworkImage(profile!.photoURL!)
                  : null,
              child: profile?.photoURL == null
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              profile?.displayName ??
                  (user.displayName != null && user.displayName!.isNotEmpty
                      ? user.displayName!
                      : 'Anonymous King'),
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
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.5)),
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
            _buildStatRow(
                Icons.emoji_events, 'Games Won', '${profile?.gamesWon ?? 0}'),
            const SizedBox(height: 12),
            _buildStatRow(Icons.videogame_asset, 'Games Played',
                '${profile?.gamesPlayed ?? 0}'),
            const SizedBox(height: 12),
            _buildStatRow(
                Icons.people, 'Friends', '${profile?.friendsCount ?? 0}'),
            const SizedBox(height: 24),
            _buildActionButton(
              context,
              isAnonymous ? 'FRIENDS' : 'FRIENDS',
              isAnonymous ? Icons.lock_outline : Icons.people_outline,
              isAnonymous
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.cyanAccent, // Greenish like the icons
              isAnonymous
                  ? () {
                      CustomSnackBar.show(
                        context,
                        message: 'Link your account to unlock Friends!',
                        color: Colors.cyanAccent,
                      );
                    }
                  : () {
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
                const Color(0xFFE5E4E2),
                () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
                isPlatinum: true,
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
          ];
        },
        loading: () => [
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ],
        error: (err, stack) => [
          const Center(
            child: Text(
              'Error loading profile',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE5E4E2), size: 18),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onPressed,
      {bool isPlatinum = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: isPlatinum ? null : color.withValues(alpha: 0.1),
            gradient: isPlatinum
                ? const LinearGradient(
                    colors: [Color(0xFFE5E4E2), Color(0xFFB0B4B8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color:
                    isPlatinum ? Colors.white54 : color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: isPlatinum
                    ? Colors.black.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isPlatinum ? const Color(0xFF1A1A2E) : color,
                  size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isPlatinum ? const Color(0xFF1A1A2E) : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
