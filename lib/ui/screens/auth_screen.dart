import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';
import '../../utils/app_logger.dart';
import '../../utils/svg_assets.dart';
import '../widgets/shared_ui.dart';
import '../widgets/custom_dialog_layout.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLoading = false;

  Future<void> _handleSignIn(Future<dynamic> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      final result = await signInMethod();
      if (result == null) {
        if (mounted) {
          _showError('Sign-in cancelled',
              debugDetails: 'User cancelled the sign-in flow');
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        _showSwitchAccountDialog(e.credential!);
      } else {
        _showError(_getFriendlyErrorMessage(e),
            debugDetails: 'Firebase Auth Error (${e.code}): ${e.message}');
      }
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.',
          debugDetails: 'General Auth Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'operation-not-allowed':
        return 'Sign-in method not enabled.';
      case 'user-not-found':
        return 'User not found.';
      case 'wrong-password':
        return 'Incorrect password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  void _showSwitchAccountDialog(AuthCredential credential) {
    CustomDialogLayout.show(
      context: context,
      child: CustomDialogLayout(
        header: const Text(
          'Account Already Linked',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: const [
          Text(
            'This account is already linked to another profile. Switching will delete your current guest progress. Do you want to Switch Account?',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await FirebaseAuth.instance.signInWithCredential(credential);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  _showError('Failed to switch account. Please try again.',
                      debugDetails: 'Switch Account Error: $e');
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Switch Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message, {String? debugDetails}) {
    if (debugDetails != null) {
      AppLogger.error('AUTH_ERROR: $debugDetails');
    }
    CustomSnackBar.show(context, message: message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Backlight Glow
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.starPlatinum.withValues(alpha: 0.3),
                                AppColors.starPlatinum.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.3, 1.3),
                              duration: 2.seconds,
                              curve: Curves.easeInOutSine,
                            )
                            .blur(
                                begin: const Offset(10, 10),
                                end: const Offset(20, 20)),

                        // The Crown itself
                        Image.asset(
                          'assets/crown.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .moveY(
                              begin: 0,
                              end: -10,
                              duration: 2.5.seconds,
                              curve: Curves.easeInOutSine,
                            )
                            .rotate(
                              begin: -0.06,
                              end: 0.06,
                              duration: 3.seconds,
                              curve: Curves.easeInOutSine,
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(
                              delay: 2.seconds,
                              duration: 3.seconds,
                              color:
                                  AppColors.starPlatinum.withValues(alpha: 0.8),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'JOIN THE ROYAL COURT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to save progress and play with friends',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 48),
                  SizedBox(
                    height: 128, // Height of 2 buttons (56x2) + spacing (16)
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Column(
                              children: [
                                _AuthButton(
                                  label: 'Continue with Google',
                                  icon: Transform.translate(
                                    offset: const Offset(0,
                                        -1), // Slight upward shift for optical centering
                                    child: SvgPicture.string(
                                      SvgAssets.googleLogo,
                                      width:
                                          20, // Slightly smaller for better balance
                                      height: 20,
                                    ),
                                  ),
                                  onPressed: () => _handleSignIn(
                                      authService.signInWithGoogle),
                                  color: Colors.white,
                                  textColor: Colors.black87,
                                ).animate().slideY(
                                    begin: 0.5,
                                    duration: 400.ms,
                                    curve: Curves.easeOut),
                                const SizedBox(height: 16),
                                _AuthButton(
                                  label: 'Continue with Apple',
                                  icon: Transform.translate(
                                    offset: const Offset(
                                        0, -3), // Pushed up further for Apple
                                    child: const Icon(Icons.apple, size: 24),
                                  ),
                                  onPressed: () => _handleSignIn(
                                      authService.signInWithApple),
                                  color: Colors.white,
                                  textColor: Colors.black87,
                                ).animate().slideY(
                                    begin: 0.5,
                                    duration: 500.ms,
                                    curve: Curves.easeOut),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1, // Ensure text doesn't have extra leading
              ),
            ),
          ],
        ),
      ),
    );
  }
}
