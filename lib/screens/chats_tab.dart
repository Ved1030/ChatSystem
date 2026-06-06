import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';
import '../widgets/chat_tile.dart';
import 'chat/chat_screen.dart';
import 'profile/profile_screen.dart';
import 'search/search_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final ChatRepository _chatRepository = ChatRepository();
  final UserRepository _userRepository = UserRepository();

  List<ChatRoomModel> _allRooms = [];
  List<String> _blockedUsers = [];
  bool _loading = true;
  StreamSubscription? _roomsSub;
  StreamSubscription? _userSub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  final Set<String> _deliveredRoomIds = {};

  void _listen() {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    _roomsSub = _chatRepository.chatRoomsStream(currentUid).listen((rooms) {
      if (mounted) {
        setState(() {
          _allRooms = rooms;
          _loading = false;
        });
      }
      final roomIds = rooms.map((r) => r.id).toList();
      final newRooms = roomIds.where((id) => !_deliveredRoomIds.contains(id)).toList();
      if (newRooms.isNotEmpty) {
        _deliveredRoomIds.addAll(newRooms);
        _chatRepository.deliverIncomingMessages(currentUid, newRooms);
      }
    });

    _userSub = _userRepository.userStream(currentUid).listen((user) {
      if (mounted) {
        setState(() {
          _blockedUsers = user.blockedUsers;
        });
      }
    });
  }

  List<ChatRoomModel> get _filteredRooms {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    return _allRooms.where((room) {
      final otherUid = room.participants.firstWhere((id) => id != currentUid);
      return !_blockedUsers.contains(otherUid);
    }).toList();
  }

  Future<void> _deleteChat(ChatRoomModel room) async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Delete this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatRepository.deleteChatForMe(room.id, currentUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
        },
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Conversations',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.person_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rooms = _filteredRooms;

    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a new conversation',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return _ChatRoomTile(
            key: ValueKey(room.id),
            room: room,
            currentUid: FirebaseAuth.instance.currentUser!.uid,
            onLongPress: () => _deleteChat(room),
          );
        },
      ),
    );
  }
}

class _ChatRoomTile extends StatefulWidget {
  final ChatRoomModel room;
  final String currentUid;
  final VoidCallback onLongPress;

  const _ChatRoomTile({
    super.key,
    required this.room,
    required this.currentUid,
    required this.onLongPress,
  });

  @override
  State<_ChatRoomTile> createState() => _ChatRoomTileState();
}

class _ChatRoomTileState extends State<_ChatRoomTile> {
  final ChatRepository _chatRepository = ChatRepository();
  final UserRepository _userRepository = UserRepository();
  UserModel? _otherUser;
  late final String _otherUid;

  @override
  void initState() {
    super.initState();
    _otherUid = widget.room.participants.firstWhere(
      (id) => id != widget.currentUid,
    );
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final otherUid = _otherUid;
    final user = await _userRepository.getUser(otherUid);
    if (mounted) {
      setState(() => _otherUser = user);
    }
  }

  void _openChat() {
    if (_otherUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: _otherUser!.uid,
          receiverName: _otherUser!.name,
          receiverPhotoUrl: _otherUser!.photoUrl,
          initialChatRoomId: widget.room.id,
          nickname: widget.room.nicknameFor(_otherUid),
          wallpaper: widget.room.wallpaper,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_otherUser == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: AppColors.shimmer),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.shimmer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 60,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.shimmer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Dismissible(
      key: ValueKey('dismiss_${widget.room.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteChat();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: ChatTile(
          user: _otherUser!,
          lastMessage: widget.room.lastMessage,
          lastMessageTime: widget.room.lastMessageTime,
          unreadCount: widget.room.unreadCounts[widget.currentUid] ?? 0,
          nickname: widget.room.nicknameFor(_otherUid),
          onTap: _openChat,
        ),
      ),
    );
  }

  Future<void> _deleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Delete this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatRepository.deleteChatForMe(widget.room.id, widget.currentUid);
    }
  }
}
