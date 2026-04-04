import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_screen.dart';
import 'lobby_screen.dart';
import '../dialogs/join_by_code_dialog.dart';
import '../widgets/shared_ui.dart';
import '../../services/social_service.dart';
import '../../services/matchmaking_service.dart';
import '../../services/firebase_service.dart';
import '../../models/game_state.dart' show GameMode;
import '../../utils/colors.dart';

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
        appBar: AppBar(
          title: const Text('FRIENDS'),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined),
              onPressed: () {},
            ),
          ],
        ),
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildPrivateRoomActions(),
              if (isGuest)
                SliverToBoxAdapter(child: _buildGuestNudge())
              else ...[
                _buildSearchBar(),
                if (_isSearching)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      backgroundColor: AppColors.primaryCyan,
                      color: AppColors.imperialJade,
                    ),
                  ),
                _buildSectionHeader('YOUR FRIENDS', Icons.people_outline),
                _buildFriendsList(),
                if (_searchController.text.length >= 2) ...[
                  _buildSectionHeader('GLOBAL SEARCH', Icons.public),
                  _buildGlobalResults(),
                ],
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateRoomActions() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'CREATE ROOM',
                Icons.add_circle_outline,
                AppColors.imperialJade,
                () => _handleCreateRoom(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'JOIN ROOM',
                Icons.vpn_key_outlined,
                AppColors.imperialAmber,
                () => _handleJoinRoom(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreateRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LobbyScreen(
          isQuickMatch: false,
          isHost: true,
        ),
      ),
    );
  }

  void _handleJoinRoom() {
    // We will implement JoinByCodeDialog later
    showDialog(
      context: context,
      builder: (context) => const JoinByCodeDialog(),
    );
  }

  Widget _buildGuestNudge() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.lock_person_outlined,
                color: AppColors.imperialJade, size: 48),
            const SizedBox(height: 16),
            const Text('LINK ACCOUNT',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Link your account to add persistent friends and chat with them anytime!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GameButton(
              text: 'LINK NOW',
              isSmall: true,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const AuthScreen()));
              },
            ),
          ],
        ),
      ),
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
              prefixIcon: Icon(Icons.search, color: AppColors.imperialJade),
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
                  backgroundColor:
                      AppColors.imperialJade.withValues(alpha: 0.1),
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? const Icon(Icons.person,
                          color: AppColors.imperialJade, size: 30)
                      : null,
                ),
                StreamBuilder<Map<String, dynamic>>(
                  stream: socialService.watchUserStatus(user.uid),
                  builder: (context, snapshot) {
                    final status = snapshot.data?['status'] ?? 'offline';
                    final isOnline = status == 'online';
                    final isInLobby = status == 'inLobby';
                    final isInGame = status == 'inGame';

                    return Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.greenAccent
                              : (isInLobby || isInGame)
                                  ? Colors.orangeAccent
                                  : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    );
                  },
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
                      Icon(Icons.stars,
                          color: AppColors.imperialAmber, size: 14),
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
              _buildSmallPlatinumButton(
                  'CHALLENGE', () => _handleChallenge(user)),
            ] else ...[
              _buildSmallPlatinumButton('ADD', () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  await profileService.sendFriendRequest(
                      currentUser.uid, user.uid);
                  if (mounted) {
                    CustomSnackBar.show(
                      context,
                      message: 'Friend request sent to ${user.displayName}!',
                      isSuccess: true,
                    );
                  }
                }
              }),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Future<void> _handleChallenge(UserProfile target) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading indicator
    CustomSnackBar.show(context,
        message: 'Creating private room...', icon: Icons.hourglass_empty);

    try {
      // 1. Create a private game
      final gameId = await matchmakingService.createGame(
        maxPlayers: 4,
        isPrivate: true,
        gameMode: GameMode.classic,
      );

      // 2. Look up the joining code
      final gameSnap = await firebaseService.database
          .ref()
          .child('ludogames')
          .child(gameId)
          .get();

      if (!gameSnap.exists) throw Exception("Failed to create game node");

      final gameData = Map<String, dynamic>.from(gameSnap.value as Map);
      final joiningCode = gameData['joiningCode'] as String?;

      if (joiningCode == null) throw Exception("No joining code generated");

      // 3. Send the invite
      await socialService.sendInvite(
        targetUid: target.uid,
        gameId: gameId,
        joiningCode: joiningCode,
      );

      // 4. Update own presence
      await socialService.updatePresence(UserStatus.inLobby, gameId: gameId);

      if (!mounted) return;

      // 5. Navigate to Lobby
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            initialGameId: gameId,
            isHost: true,
            isQuickMatch: false,
          ),
        ),
      );

      CustomSnackBar.show(context,
          message: 'Challenge sent to ${target.displayName}!', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context,
          message: 'Error sending challenge: $e', isError: true);
    }
  }

  Widget _buildSmallPlatinumButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.starPlatinum,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.systemBackground,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
