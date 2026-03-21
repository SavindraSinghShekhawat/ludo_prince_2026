import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/shared_ui.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await profileService.searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('FRIENDS',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'MY FRIENDS'),
              Tab(text: 'ADD FRIENDS'),
            ],
            indicatorColor: Colors.deepPurpleAccent,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFriendsList(currentUser?.uid),
            _buildAddFriendsView(currentUser?.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(String? uid) {
    if (uid == null)
      return const Center(
          child: Text('Sign in to see friends',
              style: TextStyle(color: Colors.white70)));

    return StreamBuilder<List<UserProfile>>(
      stream: profileService.getFriends(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final friends = snapshot.data!;
        if (friends.isEmpty) {
          return const Center(
            child: Text('No friends yet. Add some!',
                style: TextStyle(color: Colors.white54)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return _buildUserTile(friend, isFriend: true);
          },
        );
      },
    );
  }

  Widget _buildAddFriendsView(String? uid) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by username...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              fillColor: Colors.white.withValues(alpha: 0.1),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
            onChanged: _performSearch,
          ),
        ),
        if (_isSearching)
          const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: Colors.deepPurpleAccent),
        Expanded(
          child: _searchResults.isEmpty
              ? const Center(
                  child: Text('Search for players to add',
                      style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    if (user.uid == uid) return const SizedBox.shrink();
                    return _buildUserTile(user);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserTile(UserProfile user, {bool isFriend = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.5),
            backgroundImage:
                user.photoURL != null ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName ?? 'Unknown',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Wins: ${user.gamesWon}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (!isFriend)
            IconButton(
              icon:
                  const Icon(Icons.person_add, color: Colors.deepPurpleAccent),
              onPressed: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  await profileService.sendFriendRequest(
                      currentUser.uid, user.uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend request sent!')),
                    );
                  }
                }
              },
            )
          else
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        ],
      ),
    );
  }
}
