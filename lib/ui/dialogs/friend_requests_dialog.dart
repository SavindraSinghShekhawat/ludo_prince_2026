import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/friend_request.dart';
import 'package:ludo_prince/services/profile_service.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import '../widgets/shared_ui.dart';

class FriendRequestsDialog extends ConsumerWidget {
  final List<FriendRequest>? requests;
  const FriendRequestsDialog({super.key, this.requests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Firebase.apps.isEmpty) return const SizedBox.shrink();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final requestsAsync = ref.watch(friendRequestsProvider(user.uid));

    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 32,
            showGlow: false,
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: AppColors.primaryCyan,
                  size: 28,
                ),
                const SizedBox(width: 16),
                const Text(
                  'FRIEND REQUESTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 24),
            requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No pending requests',
                      style: TextStyle(color: Colors.white38, fontSize: 16),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return _RequestItemTile(request: request);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(
                    color: AppColors.primaryCyan,
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}

class _RequestItemTile extends ConsumerStatefulWidget {
  final FriendRequest request;
  const _RequestItemTile({required this.request});

  @override
  ConsumerState<_RequestItemTile> createState() => _RequestItemTileState();
}

class _RequestItemTileState extends ConsumerState<_RequestItemTile> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final profile = request.fromProfile;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.1),
            backgroundImage: profile?.photoURL != null
                ? NetworkImage(profile!.photoURL!)
                : null,
            child: profile?.photoURL == null
                ? const Icon(Icons.person, color: AppColors.primaryCyan)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.displayName ?? 'Unknown Player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'wants to be your friend',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.check,
            color: AppColors.imperialJade,
            isLoading: _isLoading,
            onTap: _isLoading
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    setState(() => _isLoading = true);
                    try {
                      final notifier = ref.read(notificationProvider.notifier);
                      await profileService.acceptFriendRequest(request);
                      notifier.removeNotification(request.id);
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message: 'Friend request accepted!',
                          isSuccess: true,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message: e.toString().replaceAll('Exception: ', ''),
                          isError: true,
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.close,
            color: AppColors.crimsonVelvet,
            isLoading: _isLoading,
            onTap: _isLoading
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    setState(() => _isLoading = true);
                    try {
                      final notifier = ref.read(notificationProvider.notifier);
                      await profileService.declineFriendRequest(request.id);
                      notifier.removeNotification(request.id);
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          message: 'Friend request declined.',
                        );
                      }
                    } catch (_) {
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(icon, color: color, size: 20),
      ),
    );
  }
}
