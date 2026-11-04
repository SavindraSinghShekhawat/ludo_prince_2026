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
import 'package:ludo_prince/games/ludo/domain/models/game_state.dart'
    show GameMode;
import 'package:ludo_prince/core/theme/app_colors.dart';
import 'package:ludo_prince/core/widgets/app_page_routes.dart';
import 'package:ludo_prince/providers/notification_provider.dart';
import 'package:ludo_prince/providers/auth_provider.dart';
import 'package:ludo_prince/ui/dialogs/notification_inbox_dialog.dart';
import 'package:ludo_prince/ui/dialogs/friend_requests_dialog.dart';
import 'package:ludo_prince/models/friend_request.dart';
import 'package:ludo_prince/ui/dialogs/friend_game_setup_dialog.dart';

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
      // 1. Instantly display cached friends with 0ms latency!
      profileService.getCachedFriends(uid).then((cached) {
        if (mounted && cached.isNotEmpty && _allFriends.isEmpty) {
          setState(() {
            _allFriends = cached;
            _filterFriends(_searchController.text);
          });
        }
      });

      // 2. Stream live updates in parallel from Firestore
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
              (r) =>
                  r.uid != currentUser?.uid &&
                  !friendIds.contains(r.uid) &&
                  !r.isAnonymous,
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

    final outgoingRequestsAsync = user != null && !isGuest
        ? ref.watch(outgoingFriendRequestsProvider(user.uid))
        : null;
    final outgoingRequests = outgoingRequestsAsync?.value ?? <FriendRequest>[];
    final outgoingSentUids = outgoingRequests.map((r) => r.toUid).toSet();

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
                _buildSectionHeader(
                  'YOUR FRIENDS (${_allFriends.length}/${ProfileService.maxFriendsLimit})',
                  Icons.people_outline,
                ),
                _buildFriendsList(),
                if (_searchController.text.length >= 2) ...[
                  _buildSectionHeader('GLOBAL SEARCH', Icons.public),
                  _buildGlobalResults(incomingRequests, outgoingSentUids),
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
                if (_allFriends.length >= ProfileService.maxFriendsLimit) {
                  AppSnackBar.show(
                    context,
                    message:
                        'Maximum limit of ${ProfileService.maxFriendsLimit} friends reached. Remove a friend to accept.',
                    isError: true,
                  );
                  return;
                }
                try {
                  final notifier = ref.read(notificationProvider.notifier);
                  await profileService.acceptFriendRequest(request);
                  notifier.markAsRead(request.id);
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
                      message: e.toString().replaceAll('Exception: ', ''),
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

  Widget _buildGlobalResults(
    List<FriendRequest> incomingRequests,
    Set<String> outgoingSentUids,
  ) {
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
            final isPendingSent = outgoingSentUids.contains(targetUser.uid);
            return _buildUserCard(
              targetUser,
              isFriend: false,
              incomingRequest: incomingReq,
              isOutgoingPending: isPendingSent,
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
    bool isOutgoingPending = false,
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
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.person_remove_outlined,
                  color: Colors.white30,
                  size: 20,
                ),
                tooltip: 'Remove Friend',
                onPressed: () => _handleRemoveFriend(user),
              ),
            ] else if (incomingRequest != null) ...[
              _buildSmallActionButton(
                label: 'ACCEPT',
                icon: Icons.check,
                color: AppColors.imperialJade,
                onTap: () async {
                  if (_allFriends.length >= ProfileService.maxFriendsLimit) {
                    AppSnackBar.show(
                      context,
                      message:
                          'Maximum limit of ${ProfileService.maxFriendsLimit} friends reached. Remove a friend to accept.',
                      isError: true,
                    );
                    return;
                  }
                  try {
                    final notifier = ref.read(notificationProvider.notifier);
                    await profileService.acceptFriendRequest(incomingRequest);
                    notifier.markAsRead(incomingRequest.id);
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
                        message: e.toString().replaceAll('Exception: ', ''),
                        isError: true,
                      );
                    }
                  }
                },
              ),
            ] else if (user.isAnonymous) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'GUEST',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ] else if (isOutgoingPending) ...[
              InkWell(
                onTap: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    await profileService.cancelFriendRequest(
                      currentUser.uid,
                      user.uid,
                    );
                    if (mounted) {
                      AppSnackBar.show(
                        context,
                        message: 'Friend request canceled.',
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        color: Colors.amberAccent,
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'SENT',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _buildSmallPlatinumButton(
                'ADD',
                () async {
                  if (_allFriends.length >= ProfileService.maxFriendsLimit) {
                    AppSnackBar.show(
                      context,
                      message:
                          'You have reached the maximum limit of ${ProfileService.maxFriendsLimit} friends.',
                      isError: true,
                    );
                    return;
                  }
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    try {
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
                    } catch (e) {
                      if (mounted) {
                        AppSnackBar.show(
                          context,
                          message:
                              e.toString().replaceAll('Exception: ', ''),
                          isError: true,
                        );
                      }
                    }
                  }
                },
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

  Future<void> _handleRemoveFriend(UserProfile target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Friend',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove ${target.displayName ?? "this player"} from your friends list?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'REMOVE',
              style: TextStyle(
                color: AppColors.crimsonVelvet,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          await profileService.removeFriend(currentUser.uid, target.uid);
          if (mounted) {
            AppSnackBar.show(
              context,
              message: '${target.displayName ?? "Player"} removed from friends.',
            );
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.show(
              context,
              message: 'Failed to remove friend: $e',
              isError: true,
            );
          }
        }
      }
    }
  }

  void _handleChallenge(UserProfile target) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final displayName = target.displayName ?? 'Friend';
    AppDialogLayout.show(
      context: context,
      child: FriendGameSetupDialog(
        title: 'CHALLENGE FRIEND',
        subtitle: 'Challenging $displayName',
        targetUids: [target.uid],
        targetNames: [displayName],
        initialMaxPlayers: 2,
        initialGameMode: GameMode.classic,
        actionButtonLabel: 'SEND CHALLENGE',
      ),
    );
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
