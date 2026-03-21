import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../widgets/shared_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      await signInMethod();
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        _showSwitchAccountDialog(e.credential!);
      } else {
        _showError(e.message ?? 'Authentication failed');
      }
    } catch (e) {
      _showError('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSwitchAccountDialog(AuthCredential credential) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Account Already Linked',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This account is already linked to another profile. Would you like to switch to that profile? (Current guest progress will not be merged)',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await FirebaseAuth.instance.signInWithCredential(credential);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                _showError('Failed to switch account: $e');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Switch Account'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
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
                    onPressed: () => _handleSignIn(authService.signInWithApple),
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
