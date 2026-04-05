import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';
import '../../providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/friends_screen.dart';
import '../widgets/shared_ui.dart';
import '../widgets/custom_dialog_layout.dart';
import '../../services/profile_service.dart';
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
      CustomSnackBar.show(context,
          message: 'Name cannot be empty!', isError: true);
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
            .copyWith(
          displayName: newName,
        );
        await profileService.createOrUpdateProfile(updatedProfile);

        if (mounted) {
          CustomSnackBar.show(context,
              message: 'Profile updated successfully!', isSuccess: true);
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context,
            message: 'Failed to update profile: $e', isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  CustomSnackBar.show(context,
                      message: "Profile picture updates are coming soon!");
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage: profile?.photoURL != null
                      ? NetworkImage(profile!.photoURL!)
                      : null,
                  child: profile?.photoURL == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
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
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Enter name...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3)),
                        enabledBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: AppColors.primaryCyan)),
                        focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: AppColors.primaryCyan, width: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryCyan))
                      : IconButton(
                          onPressed: () => _handleSave(profile),
                          icon: const Icon(Icons.check_circle,
                              color: AppColors.imperialJade, size: 28),
                        ),
                  IconButton(
                    onPressed: () => setState(() => _isEditing = false),
                    icon: const Icon(Icons.cancel,
                        color: AppColors.crimsonVelvet, size: 28),
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
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit,
                        color: AppColors.primaryCyan, size: 18),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

            if (isAnonymous)
              Center(
                child: Container(
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
                        fontWeight: FontWeight.w500),
                  ),
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
              'FRIENDS',
              Icons.people,
              AppColors.imperialJade,
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
          Icon(icon, color: AppColors.starPlatinum, size: 18),
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
                ? LinearGradient(
                    colors: [AppColors.starPlatinum, const Color(0xFFB0B4B8)],
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
                  color: isPlatinum ? AppColors.systemBackground : color,
                  size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isPlatinum ? AppColors.systemBackground : color,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
