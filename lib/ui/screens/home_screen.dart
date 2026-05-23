import 'package:ludo_prince/ui/widgets/shared_ui.dart';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ludo_prince/ui/screens/settings_screen.dart';
import 'package:ludo_prince/ui/screens/about_screen.dart';
import 'package:ludo_prince/ui/screens/local_setup_screen.dart';
import 'package:ludo_prince/ui/screens/lobby_screen.dart';
import 'package:ludo_prince/ui/screens/friends_screen.dart';
import 'package:ludo_prince/providers/auth_provider.dart';
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/core/widgets/animated_counter.dart';
import 'package:ludo_prince/ui/dialogs/profile_dialog.dart';
import 'package:ludo_prince/ui/dialogs/notification_inbox_dialog.dart';
import 'package:ludo_prince/providers/presence_provider.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import 'package:ludo_prince/providers/connectivity_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  bool _isAvatarPressed = false;

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
        body: AppBackground(
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
                              const AppLogo(fontSize: 48),
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
                            horizontal: 40,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GlassCard(
                                title: "BATTLE ONLINE",
                                subtitle: "Matchmaking & Live Battles",
                                icon: Icons.public,
                                accentColor: AppColors.primaryCyan,
                                isPrimary: true,
                                onTap: () => Navigator.push(
                                  context,
                                  ScaleFadePageRoute(
                                    page: const LobbyScreen(isQuickMatch: true),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: GlassCard(
                                      title: "FRIENDS",
                                      subtitle: "Private Room Challenges",
                                      icon: Icons.people,
                                      accentColor: AppColors.imperialJade,
                                      height: 120,
                                      onTap: () => Navigator.push(
                                        context,
                                        SlideUpPageRoute(
                                          page: const FriendsScreen(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: GlassCard(
                                      title: "OFFLINE",
                                      subtitle: "Local & AI Challenges",
                                      icon: Icons.videogame_asset,
                                      accentColor: AppColors.slateIndigo,
                                      height: 120,
                                      onTap: () => Navigator.push(
                                        context,
                                        SlideUpPageRoute(
                                          page: const LocalSetupScreen(),
                                        ),
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

    // Portrait Layout
    return Scaffold(
      body: AppBackground(
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
                  top: 350,
                  bottom: 40,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary Action
                    GlassCard(
                      title: "BATTLE ONLINE",
                      subtitle: "Matchmaking & Live Battles",
                      icon: Icons.public,
                      accentColor: AppColors.primaryCyan,
                      isPrimary: true,
                      onTap: () => Navigator.push(
                        context,
                        ScaleFadePageRoute(
                          page: const LobbyScreen(isQuickMatch: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Secondary Actions Grid
                    Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            title: "FRIENDS",
                            subtitle: "Private Room Challenges",
                            icon: Icons.people,
                            accentColor: AppColors.imperialJade,
                            height: 120,
                            onTap: () => Navigator.push(
                              context,
                              SlideUpPageRoute(
                                page: const FriendsScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassCard(
                            title: "OFFLINE",
                            subtitle: "Local & AI Challenges",
                            icon: Icons.videogame_asset,
                            accentColor: AppColors.slateIndigo,
                            height: 120,
                            onTap: () => Navigator.push(
                              context,
                              SlideUpPageRoute(
                                page: const LocalSetupScreen(),
                              ),
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
                                color: AppColors.primaryCyan.withValues(
                                  alpha: 0.1,
                                ),
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
                          const AppLogo(fontSize: 42),
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
    final bool isEmpty = count == 0;
    final Color dotColor =
        isEmpty ? const Color(0xFFFFB300) : const Color(0xFF00FF88);

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
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.1),
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
          if (isEmpty)
            Text(
              "BE THE FIRST TO PLAY!",
              style: TextStyle(
                color: dotColor.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(
                  duration: 2.seconds,
                  begin: 0.6,
                )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCounter(
                  value: count,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Text(
                  " EMPERORS ONLINE",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);
    final profile = ref.watch(userProfileProvider).value;
    final notificationState = ref.watch(notificationProvider);
    final unreadCount = notificationState.inbox.where((n) => !n.isRead).length;
    final isOnline = ref.watch(isOnlineProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTapDown: (_) => setState(() => _isAvatarPressed = true),
            onTapUp: (_) {
              setState(() => _isAvatarPressed = false);
              AppDialogLayout.show(
                context: context,
                child: const ProfileDialog(),
              );
            },
            onTapCancel: () => setState(() => _isAvatarPressed = false),
            child: AnimatedScale(
              scale: _isAvatarPressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isAvatarPressed
                            ? AppColors.primaryCyan.withValues(alpha: 0.5)
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          backgroundImage: profile?.photoURL != null
                              ? NetworkImage(profile!.photoURL!)
                              : null,
                          child: profile?.photoURL == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: AppStatusBadge(isOnline: isOnline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    profile?.displayName ?? displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _buildNotificationIcon(context, unreadCount),
              const SizedBox(width: 12),
              _buildHeaderIcon(
                context,
                Icons.settings,
                onTap: () {
                  Navigator.push(
                    context,
                    FadeThroughPageRoute(page: const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context, int count) {
    final hasUnread = count > 0;

    return GestureDetector(
      onTap: () {
        AppDialogLayout.show(
          context: context,
          child: const NotificationInboxDialog(),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: hasUnread
                  ? AppColors.primaryCyan.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: hasUnread
                    ? AppColors.primaryCyan.withValues(alpha: 0.2)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Icon(
              hasUnread ? Icons.notifications_active : Icons.notifications,
              color: hasUnread ? AppColors.primaryCyan : Colors.white70,
              size: 20,
            ),
          )
              .animate(
                target: hasUnread ? 1 : 0,
                onPlay: (c) => c.repeat(reverse: true),
              )
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 1.5.seconds,
                curve: Curves.easeInOut,
              )
              .shimmer(duration: 3.seconds, color: Colors.white24),
          if (hasUnread)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.systemBackground,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCyan.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(
    BuildContext context,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _footerLink(Icons.settings_outlined, "Settings", () {
          Navigator.push(
            context,
            FadeThroughPageRoute(page: const SettingsScreen()),
          );
        }),
        const _FooterDivider(),
        _footerLink(Icons.balance_outlined, "About & Fairness", () {
          Navigator.push(
            context,
            FadeThroughPageRoute(page: const AboutScreen()),
          );
        }),
      ],
    );
  }

  Widget _footerLink(IconData icon, String text, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: Colors.white38),
      label: Text(
        text,
        style: const TextStyle(color: Colors.white60, fontSize: 13),
      ),
    );
  }

  Widget _buildCommunityNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.rocket_launch_outlined,
              color: AppColors.primaryCyan.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Thanks for supporting us early on! Players might be few now, but we'll get there together.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
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
