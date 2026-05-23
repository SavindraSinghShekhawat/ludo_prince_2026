import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ludo_prince/services/auth_service.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/friends_screen.dart';
import '../widgets/shared_ui.dart';
import 'package:ludo_prince/services/profile_service.dart';
import '../../models/user_profile.dart';

class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({super.key});

  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(UserProfile? currentProfile) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Name cannot be empty!',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Update Firebase Auth display name
        await user.updateDisplayName(newName);

        // 2. Update Firestore profile
        final updatedProfile = (currentProfile ??
                UserProfile(uid: user.uid, createdAt: DateTime.now()))
            .copyWith(displayName: newName);
        await profileService.createOrUpdateProfile(updatedProfile);

        if (mounted) {
          AppSnackBar.show(
            context,
            message: 'Profile updated successfully!',
            isSuccess: true,
          );
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Failed to update profile: $e',
          isError: true,
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final userProfileAsync = ref.watch(userProfileProvider);

    return AppDialogLayout(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'PLAYER PROFILE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
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
          final displayName = profile?.displayName ??
              (user.displayName != null && user.displayName!.isNotEmpty
                  ? user.displayName!
                  : 'Anonymous King');

          if (!_isEditing) {
            _nameController.text = displayName;
          }

          return [
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () {
                  AppSnackBar.show(
                    context,
                    message: "Profile picture updates are coming soon!",
                  );
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.primaries[
                      displayName.hashCode % Colors.primaries.length],
                  backgroundImage: profile?.photoURL != null
                      ? NetworkImage(profile!.photoURL!)
                      : null,
                  child: profile?.photoURL == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Name Section
            if (_isEditing)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter name...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryCyan),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primaryCyan,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryCyan,
                          ),
                        )
                      : IconButton(
                          onPressed: () => _handleSave(profile),
                          icon: const Icon(
                            Icons.check_circle,
                            color: AppColors.imperialJade,
                            size: 28,
                          ),
                        ),
                  IconButton(
                    onPressed: () => setState(() => _isEditing = false),
                    icon: const Icon(
                      Icons.cancel,
                      color: AppColors.crimsonVelvet,
                      size: 28,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(
                      Icons.edit,
                      color: AppColors.primaryCyan,
                      size: 18,
                    ),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

            if (isAnonymous)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'GUEST ACCOUNT',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMiniStat(Icons.videogame_asset, 'Played',
                      '${profile?.gamesPlayed ?? 0}', AppColors.primaryCyan),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.1)),
                  _buildMiniStat(Icons.emoji_events, 'Won',
                      '${profile?.gamesWon ?? 0}', AppColors.imperialAmber),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.1)),
                  _buildMiniStat(
                      Icons.pie_chart,
                      'Win Rate',
                      '${((profile?.gamesPlayed ?? 0) > 0 ? ((profile?.gamesWon ?? 0) / (profile?.gamesPlayed ?? 1)) * 100 : 0).toStringAsFixed(0)}%',
                      AppColors.imperialJade),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'FRIENDS',
              icon: Icons.people,
              color: AppColors.imperialJade,
              onTap: isAnonymous
                  ? () {
                      AppSnackBar.show(
                        context,
                        message: 'Link your account to unlock Friends!',
                        color: Colors.cyanAccent,
                      );
                    }
                  : () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        SlideUpPageRoute(
                          page: const FriendsScreen(),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            if (isAnonymous)
              AppButton(
                text: 'LINK ACCOUNT',
                icon: Icons.link,
                color: AppColors.starPlatinum,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    SlideUpPageRoute(page: const AuthScreen()),
                  );
                },
              )
            else
              AppButton(
                text: 'SIGN OUT',
                icon: Icons.logout,
                color: Colors.redAccent.withValues(alpha: 0.8),
                onTap: () async {
                  await authService.signOut();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ];
        },
        loading: () => [
          const Center(child: CircularProgressIndicator(color: Colors.white)),
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

  Widget _buildMiniStat(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
