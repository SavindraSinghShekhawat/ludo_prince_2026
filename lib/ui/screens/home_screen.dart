import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'local_setup_screen.dart';
import 'lobby_screen.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/shared_ui.dart';
import '../../utils/colors.dart';
import '../dialogs/profile_dialog.dart';
import '../widgets/logo_widget.dart';
import '../../providers/presence_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 0 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 0 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineCountAsync = ref.watch(onlineCountProvider);
    final onlineCount = onlineCountAsync.value ?? 0;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      return Scaffold(
        body: AnimatedBackground(
          showParticles: true,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Area: Full-width Header
                _buildHeader(context, ref),
                Expanded(
                  child: Row(
                    children: [
                      // Left Column: Logo and Status
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 48),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const LogoWidget(fontSize: 48),
                              const SizedBox(height: 20),
                              _buildOnlineStatusBar(onlineCount),
                            ],
                          ),
                        ),
                      ),
                      // Right Column: Cards
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GlassCard(
                                title: "BATTLE ONLINE",
                                subtitle: "Quick Match & Tournaments",
                                icon: Icons.public,
                                accentColor: Colors.deepPurpleAccent,
                                isPrimary: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LobbyScreen(
                                          isQuickMatch: true)),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: GlassCard(
                                      title: "FRIENDS",
                                      subtitle: "Social & Rewards",
                                      icon: Icons.people,
                                      accentColor: Colors.cyanAccent,
                                      height: 120,
                                      isComingSoon: true,
                                      onTap: () => CustomSnackBar.show(context,
                                          message:
                                              "Friends feature is coming soon!"),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: GlassCard(
                                      title: "OFFLINE",
                                      subtitle: "Local & Bots",
                                      icon: Icons.videogame_asset,
                                      accentColor: AppColors.player1BlueUI,
                                      height: 120,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const LocalSetupScreen()),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 48),
                              _buildFooter(context),
                              const SizedBox(height: 16),
                              _buildCommunityNote(),
                              const SizedBox(height: 48),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AnimatedBackground(
        showParticles: true,
        child: Stack(
          children: [
            // 1. Scrollable Content Layer (Underneath)
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(
                  top:
                      350, // Adjusted to move "BATTLE ONLINE" up while keeping it below the imaginary line
                  bottom: 40,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary Action

                    // Primary Action
                    GlassCard(
                      title: "BATTLE ONLINE",
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
                    const SizedBox(height: 20),

                    // Secondary Actions Grid
                    Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            title: "FRIENDS",
                            subtitle: "Social & Rewards",
                            icon: Icons.people,
                            accentColor: Colors.cyanAccent,
                            height: 120,
                            isComingSoon: true,
                            onTap: () => CustomSnackBar.show(context,
                                message: "Friends feature is coming soon!"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassCard(
                            title: "OFFLINE",
                            subtitle: "Local & Bots",
                            icon: Icons.videogame_asset,
                            accentColor: AppColors.player1BlueUI,
                            height: 120,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LocalSetupScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Footer Navigation
                    _buildFooter(context),
                    const SizedBox(height: 16),
                    _buildCommunityNote(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // 2. Fixed Sticky Header (Top Layer with EXTRA BLUR)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: _isScrolled ? 45 : 0,
                    sigmaY: _isScrolled ? 45 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _isScrolled
                          ? const Color(0xFF0B0B1A).withValues(alpha: 0.15)
                          : Colors.transparent,
                      border: _isScrolled
                          ? Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(context, ref),
                          const SizedBox(height: 10),
                          const LogoWidget(fontSize: 42),
                          const SizedBox(height: 16),
                          _buildOnlineStatusBar(onlineCount),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineStatusBar(int count) {
    // Show actual real numbers as requested
    final displayCount = count.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF00FF88),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.8, 1.8),
                    duration: 1.2.seconds,
                    curve: Curves.easeInOutSine,
                  )
                  .fadeOut(duration: 1.2.seconds),
            ],
          ),
          const SizedBox(width: 10),
          Text(
            "$displayCount EMPERORS ONLINE",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final profile = ref.watch(userProfileProvider).value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
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
                Text(profile?.displayName ?? displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Row(
            children: [
              _buildHeaderIcon(context, Icons.notifications),
              const SizedBox(width: 12),
              _buildHeaderIcon(context, Icons.settings, onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }),
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

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _footerLink("Settings", () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()));
        }),
        const _FooterDivider(),
        _footerLink("About & Fairness", () {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AboutScreen()));
        }),
      ],
    );
  }

  Widget _footerLink(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(text,
          style: const TextStyle(color: Colors.white60, fontSize: 13)),
    );
  }

  Widget _buildCommunityNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          Text(
            "Thanks for supporting us in the beginning! Players might be few now, but we'll get there together. 🚀",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text("|", style: TextStyle(color: Colors.white24)),
    );
  }
}
