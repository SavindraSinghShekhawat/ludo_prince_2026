import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'local_setup_screen.dart';
import 'lobby_screen.dart';
import '../../providers/auth_provider.dart';
import '../widgets/shared_ui.dart';
import '../dialogs/profile_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, ref),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassCard(
                        title: "PLAY ONLINE",
                        subtitle: "Quick Match & Tournaments",
                        icon: Icons.public,
                        accentColor: Colors.deepPurpleAccent,
                        isPrimary: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LobbyScreen(isQuickMatch: true)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GlassCard(
                        title: "LOCAL & BOTS",
                        subtitle: "Offline, Friends & Computer",
                        icon: Icons.home,
                        accentColor: Colors.blueAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LocalSetupScreen()),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen())),
                            child: const Text("Settings",
                                style: TextStyle(color: Colors.white60)),
                          ),
                          const Text("|",
                              style: TextStyle(color: Colors.white24)),
                          TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AboutScreen())),
                            child: const Text("About & Fairness",
                                style: TextStyle(color: Colors.white60)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final profile = ref.watch(userProfileProvider).value;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const ProfileDialog(),
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    backgroundImage: profile?.photoURL != null
                        ? NetworkImage(profile!.photoURL!)
                        : null,
                    child: profile?.photoURL == null
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFE5E4E2),
                          Color(0xFFFFFFFF),
                          Color(0xFFA0A0A0),
                          Color(0xFFE5E4E2)
                        ],
                        stops: [0.0, 0.4, 0.6, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text("LUDO PRINCE",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0)),
                    ),
                    Text(profile?.displayName ?? displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildHeaderIcon(context, Icons.settings, onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }),
              const SizedBox(width: 12),
              _buildHeaderIcon(context, Icons.notifications),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(BuildContext context, IconData icon,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.05)),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}
