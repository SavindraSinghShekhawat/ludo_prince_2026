import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import 'package:ludo_prince/services/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_screen.dart';
import 'package:ludo_prince/ui/screens/lobby_screen.dart';
import 'package:ludo_prince/ui/dialogs/join_by_code_dialog.dart';
import '../widgets/shared_ui.dart';
import 'package:ludo_prince/services/social_service.dart';
import 'package:ludo_prince/services/matchmaking_service.dart';
import 'package:ludo_prince/services/firebase_service.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart'
    show GameMode;
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import 'package:ludo_prince/providers/auth_provider.dart';
import 'package:ludo_prince/ui/dialogs/notification_inbox_dialog.dart';
import 'package:ludo_prince/ui/dialogs/friend_requests_dialog.dart';
import 'package:ludo_prince/models/friend_request.dart';
import 'package:ludo_prince/core/constants/firebase_paths.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UserProfile> _allFriends = [];
  List<UserProfile> _filteredFriends = [];
  List<UserProfile> _searchResults = [];
  final Set<String> _sentRequests = {};
  bool _isSearching = false;
  Timer? _debounce;
  StreamSubscription? _friendsSubscription;
  String? _subscribedUid;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      _setupFriendsSubscription(currentUser.uid);
    }
  }

  void _setupFriendsSubscription(String? uid, {bool force = false}) {
    if (!force && uid == _subscribedUid && _friendsSubscription != null) {
      return;
    }
    _subscribedUid = uid;
    _friendsSubscription?.cancel();
    _friendsSubscription = null;

    if (uid != null) {
      _friendsSubscription = profileService.getFriends(uid).listen((friends) {
        if (mounted) {
          setState(() {
            _allFriends = friends;
            _filterFriends(_searchController.text);
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _allFriends = [];
          _filteredFriends = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
            .where(
              (f) => (f.displayName ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
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
              (r) => r.uid != currentUser?.uid && !friendIds.contains(r.uid),
            )
            .toList();
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      final newUser = next.value ?? FirebaseAuth.instance.currentUser;
      if (newUser != null && !newUser.isAnonymous) {
        _setupFriendsSubscription(newUser.uid, force: true);
      } else {
        _setupFriendsSubscription(null);
      }
    });

    final authUser = ref.watch(authStateProvider).value;
    final user = authUser ?? FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;
    final unreadCount =
        ref.watch(notificationProvider).inbox.where((n) => !n.isRead).length;

    final requestsAsync = user != null && !isGuest
        ? ref.watch(friendRequestsProvider(user.uid))
        : null;
    final incomingRequests = requestsAsync?.value ?? <FriendRequest>[];

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('FRIENDS'),
          actions: [
            if (incomingRequests.isNotEmpty)
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Pending Requests',
                    icon: const Icon(
                      Icons.person_add_alt_1_outlined,
                      color: AppColors.primaryCyan,
                    ),
                    onPressed: () {
                      AppDialogLayout.show(
                        context: context,
                        child: const FriendRequestsDialog(),
                      );
                    },
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.crimsonVelvet,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        incomingRequests.length > 9
                            ? '9+'
                            : incomingRequests.length.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined),
                  onPressed: () {
                    AppDialogLayout.show(
                      context: context,
                      child: const NotificationInboxDialog(),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.crimsonVelvet,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
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
                if (incomingRequests.isNotEmpty) ...[
                  _buildSectionHeader(
                    'PENDING REQUESTS (${incomingRequests.length})',
                    Icons.person_add_alt_1,
                    highlightColor: AppColors.primaryCyan,
                  ),
                  _buildIncomingRequestsList(incomingRequests),
                ],
                _buildSectionHeader('YOUR FRIENDS', Icons.people_outline),
                _buildFriendsList(),
                if (_searchController.text.length >= 2) ...[
                  _buildSectionHeader('GLOBAL SEARCH', Icons.public),
                  _buildGlobalResults(incomingRequests),
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
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    bool isPressed = false;
    return StatefulBuilder(
      builder: (context, setCardState) {
        return GestureDetector(
          onTapDown: (_) => setCardState(() => isPressed = true),
          onTapUp: (_) {
            setCardState(() => isPressed = false);
            onTap();
          },
          onTapCancel: () => setCardState(() => isPressed = false),
          child: AnimatedContainer(
            duration: 150.ms,
            curve: Curves.easeOut,
            transform: Matrix4.diagonal3Values(
              isPressed ? 0.95 : 1.0,
              isPressed ? 0.95 : 1.0,
              1.0,
            ),
            transformAlignment: Alignment.center,
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
          ),
        );
      },
    );
  }

  void _handleCreateRoom() {
    Navigator.push(
      context,
      ScaleFadePageRoute(
        page: const LobbyScreen(isQuickMatch: false, isHost: true),
      ),
    );
  }

  void _handleJoinRoom() {
    // We will implement JoinByCodeDialog later
    AppDialogLayout.show(context: context, child: const JoinByCodeDialog());
  }

  Widget _buildGuestNudge() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.lock_person_outlined,
              color: AppColors.imperialJade,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'LINK ACCOUNT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Link your account to add persistent friends and chat with them anytime!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            AppButton(
              text: 'LINK NOW',
              isSmall: true,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
                if (mounted) {
                  await FirebaseAuth.instance.currentUser?.reload();
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null && !user.isAnonymous) {
                    _setupFriendsSubscription(user.uid, force: true);
                  }
                  setState(() {});
                }
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
            focusNode: _searchFocusNode,
            style: const TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by Name or Ludo ID...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.imperialJade),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white54, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    Color? highlightColor,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Icon(icon, color: highlightColor ?? Colors.white38, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: highlightColor ?? Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequestsList(List<FriendRequest> requests) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildIncomingRequestCard(requests[index]),
          childCount: requests.length,
        ),
      ),
    );
  }

  Widget _buildIncomingRequestCard(FriendRequest request) {
    final profile = request.fromProfile;
    final displayName = profile?.displayName ??
        (request.fromUid.length >= 4
            ? 'Player ${request.fromUid.substring(0, 4)}'
            : 'Player');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        borderRadius: 20,
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.15),
              backgroundImage: profile?.photoURL != null
                  ? NetworkImage(profile!.photoURL!)
                  : null,
              child: profile?.photoURL == null
                  ? const Icon(
                      Icons.person,
                      color: AppColors.primaryCyan,
                      size: 26,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'wants to be your friend',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildSmallActionButton(
              label: 'ACCEPT',
              icon: Icons.check,
              color: AppColors.imperialJade,
              onTap: () async {
                try {
                  await profileService.acceptFriendRequest(request);
                  ref
                      .read(notificationProvider.notifier)
                      .markAsRead(request.id);
                  if (mounted) {
                    AppSnackBar.show(
                      context,
                      message: 'Friend request accepted!',
                      isSuccess: true,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackBar.show(
                      context,
                      message: 'Failed to accept: $e',
                      isError: true,
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 8),
            _buildSmallActionButton(
              label: 'DECLINE',
              icon: Icons.close,
              color: AppColors.crimsonVelvet,
              onTap: () async {
                try {
                  await profileService.declineFriendRequest(request.id);
                  ref
                      .read(notificationProvider.notifier)
                      .markAsRead(request.id);
                  if (mounted) {
                    AppSnackBar.show(
                      context,
                      message: 'Friend request declined.',
                    );
                  }
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.08, end: 0);
  }

  Widget _buildFriendsList() {
    if (_filteredFriends.isEmpty && _searchController.text.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: Colors.white24,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your friend list is empty.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find players by name or ID to add them to your friends list.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'SEARCH PLAYERS',
                isSmall: true,
                onTap: () {
                  _searchFocusNode.requestFocus();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredFriends.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            'No matching friends found.',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
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

  Widget _buildGlobalResults(List<FriendRequest> incomingRequests) {
    if (_searchResults.isEmpty && !_isSearching) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            'No new players found matching your search.',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final targetUser = _searchResults[index];
            FriendRequest? incomingReq;
            for (final r in incomingRequests) {
              if (r.fromUid == targetUser.uid) {
                incomingReq = r;
                break;
              }
            }
            return _buildUserCard(
              targetUser,
              isFriend: false,
              incomingRequest: incomingReq,
            );
          },
          childCount: _searchResults.length,
        ),
      ),
    );
  }

  Widget _buildUserCard(
    UserProfile user, {
    required bool isFriend,
    FriendRequest? incomingRequest,
  }) {
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
                  backgroundColor: AppColors.imperialJade.withValues(
                    alpha: 0.1,
                  ),
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.imperialJade,
                          size: 30,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'Player',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: AppColors.imperialAmber,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${user.gamesWon} WINS',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: socialService.watchUserStatus(user.uid),
                        builder: (context, snapshot) {
                          final status = snapshot.data?['status'] ?? 'offline';
                          if (status == 'offline') {
                            return const SizedBox.shrink();
                          }

                          final isInGame = status == 'inGame';
                          final isInLobby = status == 'inLobby';

                          String statusText = 'Online';
                          Color statusColor = Colors.greenAccent;
                          if (isInGame) {
                            statusText = 'In Game';
                            statusColor = Colors.orangeAccent;
                          } else if (isInLobby) {
                            statusText = 'In Lobby';
                            statusColor = Colors.orangeAccent;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusText.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isFriend) ...[
              _buildSmallPlatinumButton(
                'CHALLENGE',
                () => _handleChallenge(user),
              ),
            ] else if (incomingRequest != null) ...[
              _buildSmallActionButton(
                label: 'ACCEPT',
                icon: Icons.check,
                color: AppColors.imperialJade,
                onTap: () async {
                  try {
                    await profileService.acceptFriendRequest(incomingRequest);
                    ref
                        .read(notificationProvider.notifier)
                        .markAsRead(incomingRequest.id);
                    if (mounted) {
                      AppSnackBar.show(
                        context,
                        message:
                            'Friend request from ${user.displayName ?? "Player"} accepted!',
                        isSuccess: true,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.show(
                        context,
                        message: 'Failed to accept: $e',
                        isError: true,
                      );
                    }
                  }
                },
              ),
            ] else ...[
              _buildSmallPlatinumButton(
                _sentRequests.contains(user.uid) ? 'SENT' : 'ADD',
                _sentRequests.contains(user.uid)
                    ? () {}
                    : () async {
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser != null) {
                          setState(() => _sentRequests.add(user.uid));
                          await profileService.sendFriendRequest(
                            currentUser.uid,
                            user.uid,
                          );
                          if (mounted) {
                            AppSnackBar.show(
                              context,
                              message:
                                  'Friend request sent to ${user.displayName}!',
                              isSuccess: true,
                            );
                          }
                        }
                      },
                isEnabled: !_sentRequests.contains(user.uid),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSmallActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChallenge(UserProfile target) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading indicator
    AppSnackBar.show(
      context,
      message: 'Creating private room...',
      icon: Icons.hourglass_empty,
    );

    try {
      // 1. Create a private game
      final playerName = ref.read(displayNameProvider);
      final gameId = await matchmakingService.createGame(
        maxPlayers: 2,
        isPrivate: true,
        gameMode: GameMode.classic,
        playerName: playerName,
      );

      // 2. Look up the joining code
      final gameSnap = await firebaseService.database
          .ref()
          .child(FirebasePaths.session('ludo', gameId))
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
        ScaleFadePageRoute(
          page: LobbyScreen(
            initialGameId: gameId,
            isHost: true,
            isQuickMatch: false,
          ),
        ),
      );

      AppSnackBar.show(
        context,
        message: 'Challenge sent to ${target.displayName}!',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Error sending challenge: $e',
        isError: true,
      );
    }
  }

  Widget _buildSmallPlatinumButton(
    String label,
    VoidCallback onTap, {
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.starPlatinum
              : AppColors.starPlatinum.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.white12,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isEnabled
                ? AppColors.systemBackground
                : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
