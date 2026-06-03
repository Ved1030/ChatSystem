import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/message_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/online_status.dart';
import 'chat_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverPhotoUrl;
  final String? initialChatRoomId;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhotoUrl,
    this.initialChatRoomId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _chatRepository = ChatRepository();
  final UserRepository _userRepository = UserRepository();

  String? _chatRoomId;
  String? _receiverUsername;
  bool _isInitialized = false;
  bool _isNearBottom = true;
  DateTime? _clearedAt;

  List<MessageModel> _messages = [];
  StreamSubscription<List<MessageModel>>? _messagesSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final isNearBottom = distanceFromBottom < 150;
    if (isNearBottom != _isNearBottom) {
      _isNearBottom = isNearBottom;
    }
  }

  Future<void> _initialize() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;

      String? chatRoomId = widget.initialChatRoomId;
      if (chatRoomId == null) {
        final chatRoom =
            await _chatRepository.getOrCreateChatRoom(currentUid, widget.receiverId);
        chatRoomId = chatRoom.id;
      }

      final receiverUser = await _userRepository.getUser(widget.receiverId);

      final chatRoomDoc = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .get();
      final chatRoomData = chatRoomDoc.data() as Map<String, dynamic>?;
      final clearedTs = (chatRoomData?['clearedAt'] as Timestamp?)?.toDate();

      if (mounted) {
        setState(() {
          _chatRoomId = chatRoomId;
          _receiverUsername = receiverUser?.username;
          _clearedAt = clearedTs;
          _isInitialized = true;
        });
        _listenToMessages();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  void _listenToMessages() {
    if (_chatRoomId == null) return;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    _messagesSub?.cancel();
    _messagesSub = _chatRepository
        .messagesStream(_chatRoomId!, currentUid, clearedAt: _clearedAt)
        .listen((messages) {
      final wasEmpty = _messages.isEmpty;
      final prevCount = _messages.length;

      setState(() {
        _messages = messages;
      });

      if (wasEmpty && messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      } else if (messages.length > prevCount && _isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatRoomId == null) return;

    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    final blocked = await _chatRepository.isBlocked(currentUid, widget.receiverId);
    if (blocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot send message. User is blocked.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _messageController.clear();

    await _chatRepository.sendMessage(
      chatRoomId: _chatRoomId!,
      senderId: currentUid,
      receiverId: widget.receiverId,
      text: text,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _onMessageLongPress(MessageModel message) async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final isMyMessage = message.senderId == currentUid;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (isMyMessage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete for Everyone'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteForEveryone(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for Me'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteForMe(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteForEveryone(MessageModel message) async {
    if (_chatRoomId == null || message.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete for Everyone'),
        content: const Text('This message will be deleted for everyone.'),
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
      await _chatRepository.deleteMessageForEveryone(_chatRoomId!, message.id!);
    }
  }

  Future<void> _deleteForMe(MessageModel message) async {
    if (_chatRoomId == null || message.id == null) return;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    await _chatRepository.deleteMessageForMe(_chatRoomId!, message.id!, currentUid);
  }

  Future<void> _openChatInfo() async {
    if (_chatRoomId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatInfoScreen(
          receiverId: widget.receiverId,
          receiverName: widget.receiverName,
          receiverPhotoUrl: widget.receiverPhotoUrl,
          chatRoomId: _chatRoomId!,
        ),
      ),
    );

    final chatRoomDoc = await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_chatRoomId)
        .get();
    final chatRoomData = chatRoomDoc.data() as Map<String, dynamic>?;
    final clearedTs = (chatRoomData?['clearedAt'] as Timestamp?)?.toDate();

    if (mounted && clearedTs != _clearedAt) {
      setState(() => _clearedAt = clearedTs);
      _listenToMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FC),
      appBar: _buildAppBar(),
      body: _isInitialized ? _buildBody() : const Center(child: CircularProgressIndicator()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: widget.receiverPhotoUrl != null
                ? NetworkImage(widget.receiverPhotoUrl!)
                : null,
            backgroundColor: Colors.green.shade100,
            child: widget.receiverPhotoUrl == null
                ? Text(
                    widget.receiverName.isNotEmpty
                        ? widget.receiverName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.receiverName.isNotEmpty
                    ? widget.receiverName
                    : _receiverUsername ?? 'User',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildOnlineStatus(),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _openChatInfo,
          icon: const Icon(Icons.info_outline, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildOnlineStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isOnline = data?['isOnline'] as bool? ?? false;
        final lastSeen = (data?['lastSeen'] as Timestamp?)?.toDate();
        return OnlineStatus(
          isOnline: isOnline,
          lastSeen: lastSeen,
        );
      },
    );
  }

  Widget _buildBody() {
    if (_chatRoomId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Could not load chat',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildMessagesList()),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
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
              'No messages yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hello to ${widget.receiverName.isNotEmpty ? widget.receiverName : _receiverUsername ?? 'User'}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return GestureDetector(
          onLongPress: () => _onMessageLongPress(msg),
          child: MessageBubble(
            message: msg.text,
            isMe: msg.senderId == currentUid,
            timestamp: msg.timestamp,
            isDeleted: msg.isDeleted,
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.emoji_emotions_outlined),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.attach_file),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.green,
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
