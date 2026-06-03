import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/chat_tile.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: _ChatRoomsList(currentUid: currentUser.uid),
    );
  }
}

class _ChatRoomsList extends StatefulWidget {
  final String currentUid;

  const _ChatRoomsList({required this.currentUid});

  @override
  State<_ChatRoomsList> createState() => _ChatRoomsListState();
}

class _ChatRoomsListState extends State<_ChatRoomsList> {
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

  void _listen() {
    _roomsSub = _chatRepository.chatRoomsStream(widget.currentUid).listen((rooms) {
      if (mounted) {
        setState(() {
          _allRooms = rooms;
          _loading = false;
        });
      }
    });

    _userSub = _userRepository.userStream(widget.currentUid).listen((user) {
      if (mounted) {
        setState(() {
          _blockedUsers = user.blockedUsers;
        });
      }
    });
  }

  List<ChatRoomModel> get _filteredRooms {
    return _allRooms.where((room) {
      final otherUid = room.participants.firstWhere((id) => id != widget.currentUid);
      return !_blockedUsers.contains(otherUid);
    }).toList();
  }

  Future<void> _deleteChat(ChatRoomModel room) async {
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatRepository.deleteChatForMe(room.id, widget.currentUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rooms = _filteredRooms;

    if (rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for users to start chatting',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return _ChatRoomTile(
            key: ValueKey(room.id),
            room: room,
            currentUid: widget.currentUid,
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
  final UserRepository _userRepository = UserRepository();
  UserModel? _otherUser;

  @override
  void initState() {
    super.initState();
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final otherUid =
        widget.room.participants.firstWhere((id) => id != widget.currentUid);
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_otherUser == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: const ListTile(
            contentPadding: EdgeInsets.all(12),
            leading: CircleAvatar(radius: 28),
            title: Text('Loading...'),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: ChatTile(
        user: _otherUser!,
        lastMessage: widget.room.lastMessage,
        lastMessageTime: widget.room.lastMessageTime,
        onTap: _openChat,
      ),
    );
  }
}
