import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';
import '../widgets/shared_ui.dart';
import '../widgets/custom_dialog_layout.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_logger.dart';

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
    showDialog(
      context: context,
      builder: (context) => CustomDialogLayout(
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
            'This account is already linked to another profile. Would you like to switch to that profile? (Note: Your current guest progress will be lost!)',
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
                  const Icon(Icons.account_circle_outlined,
                          size: 100, color: Colors.white)
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.easeOutBack),
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
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else ...[
                    _AuthButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata,
                      onPressed: () =>
                          _handleSignIn(authService.signInWithGoogle),
                      color: Colors.white,
                      textColor: Colors.black87,
                    ).animate().slideY(
                        begin: 0.5, duration: 400.ms, curve: Curves.easeOut),
                    const SizedBox(height: 16),
                    _AuthButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple,
                      onPressed: () =>
                          _handleSignIn(authService.signInWithApple),
                      color: Colors.black,
                      textColor: Colors.white,
                    ).animate().slideY(
                        begin: 0.5, duration: 500.ms, curve: Curves.easeOut),
                  ],
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
  final IconData icon;
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
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
