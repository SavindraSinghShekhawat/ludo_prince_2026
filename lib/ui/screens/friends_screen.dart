import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/shared_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _allFriends = [];
  List<UserProfile> _filteredFriends = [];
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  StreamSubscription? _friendsSubscription;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _friendsSubscription =
          profileService.getFriends(currentUser.uid).listen((friends) {
        if (mounted) {
          setState(() {
            _allFriends = friends;
            _filterFriends(_searchController.text);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _friendsSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _filterFriends(query);

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performGlobalSearch(query);
    });
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _allFriends;
      } else {
        _filteredFriends = _allFriends
            .where((f) => (f.displayName ?? '')
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _performGlobalSearch(String query) async {
    if (query.length < 2) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await profileService.searchUsers(query);
    if (mounted) {
      final currentUser = FirebaseAuth.instance.currentUser;
      setState(() {
        final friendIds = _allFriends.map((f) => f.uid).toSet();
        _searchResults = results
            .where(
                (r) => r.uid != currentUser?.uid && !friendIds.contains(r.uid))
            .toList();
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: isGuest
              ? _buildGuestRestriction()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildHeader(),
                    _buildSearchBar(),
                    if (_isSearching)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.transparent,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    _buildSectionHeader('YOUR FRIENDS', Icons.people_outline),
                    _buildFriendsList(),
                    if (_searchController.text.length >= 2) ...[
                      _buildSectionHeader('GLOBAL SEARCH', Icons.public),
                      _buildGlobalResults(),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGuestRestriction() {
    return Stack(
      children: [
        Positioned(
          top: 16,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: GlassContainer(
              padding: const EdgeInsets.all(32),
              borderRadius: 30,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_person_outlined,
                          color: Colors.cyanAccent, size: 80)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(duration: 2.seconds),
                  const SizedBox(height: 24),
                  const Text('LINK ACCOUNT',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0)),
                  const SizedBox(height: 16),
                  const Text(
                      'Connect your account to unlock Friends, Chat, and Matchmaking with players worldwide!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 32),
                  _buildLargeButton('LINK NOW', Colors.cyanAccent, () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const AuthScreen()));
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeButton(String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FRIENDS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0)),
                Text('${_allFriends.length} connected players',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
            const Spacer(),
            _buildSmallCircleButton(Icons.settings_outlined),
            const SizedBox(width: 12),
            _buildSmallCircleButton(Icons.notifications_none_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCircleButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, color: Colors.white70, size: 20),
    );
  }

  Widget _buildSearchBar() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          borderRadius: 20,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search by Name or Ludo ID...',
              hintStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(Icons.search, color: Colors.cyanAccent),
              suffixIcon: Icon(Icons.mic_none, color: Colors.white38),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Icon(icon, color: Colors.white38, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_filteredFriends.isEmpty && _searchController.text.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(
            child: Text('No friends yet. Start searching!',
                style: TextStyle(color: Colors.white30)),
          ),
        ),
      );
    }

    if (_filteredFriends.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text('No matching friends found.',
              style: TextStyle(color: Colors.white30, fontSize: 13)),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _buildUserCard(_filteredFriends[index], isFriend: true),
          childCount: _filteredFriends.length,
        ),
      ),
    );
  }

  Widget _buildGlobalResults() {
    if (_searchResults.isEmpty && !_isSearching) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text('No new players found matching your search.',
              style: TextStyle(color: Colors.white30, fontSize: 13)),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _buildUserCard(_searchResults[index], isFriend: false),
          childCount: _searchResults.length,
        ),
      ),
    );
  }

  Widget _buildUserCard(UserProfile user, {required bool isFriend}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.1),
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? const Icon(Icons.person,
                          color: Colors.cyanAccent, size: 30)
                      : null,
                ),
                if (isFriend) // Only show online status for friends (simulated)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF16162C), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName ?? 'Player',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.stars, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 4),
                      Text('Lv. ${10 + (user.gamesWon % 50)}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.white24)),
                      const SizedBox(width: 8),
                      Text(isFriend ? 'Ready for Ludo!' : 'New Player',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            if (isFriend) ...[
              _buildActionButton('CHALLENGE', Colors.cyanAccent),
            ] else ...[
              _buildAddButton(user),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildActionButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildAddButton(UserProfile user) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            await profileService.sendFriendRequest(currentUser.uid, user.uid);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Friend request sent to ${user.displayName}!'),
                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.8),
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.cyanAccent, size: 16),
              SizedBox(width: 4),
              Text('ADD',
                  style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}
