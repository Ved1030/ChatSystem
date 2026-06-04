import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/message_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/online_status.dart';
import '../../widgets/profile_avatar.dart';
import 'chat_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverPhotoUrl;
  final String? initialChatRoomId;
  final String? nickname;
  final String? wallpaper;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhotoUrl,
    this.initialChatRoomId,
    this.nickname,
    this.wallpaper,
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
  bool _hasMarkedRead = false;
  String? _wallpaper;
  String? _nickname;

  List<MessageModel> _messages = [];
  final Set<String> _processedStatusIds = {};
  StreamSubscription<List<MessageModel>>? _messagesSub;
  StreamSubscription<DocumentSnapshot>? _roomSub;
  StreamSubscription<DocumentSnapshot>? _userSub;

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
    _roomSub?.cancel();
    _userSub?.cancel();
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
        final chatRoom = await _chatRepository.getOrCreateChatRoom(
          currentUid,
          widget.receiverId,
        );
        chatRoomId = chatRoom.id;
      }

      final receiverUser = await _userRepository.getUser(widget.receiverId);

      final chatRoomDoc = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(chatRoomId)
          .get();
      final chatRoomData = chatRoomDoc.data();
      final clearedTs = (chatRoomData?['clearedAt'] as Timestamp?)?.toDate();

      if (mounted) {
        setState(() {
          _chatRoomId = chatRoomId;
          _receiverUsername = receiverUser?.username;
          _clearedAt = clearedTs;
          _isInitialized = true;
        });
        _listenToRoom();
        _listenToUser();
        _listenToMessages();

        await _chatRepository.markAllMessagesAsRead(
          chatRoomId,
          currentUid,
          widget.receiverId,
        );
        _hasMarkedRead = true;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  void _listenToRoom() {
    if (_chatRoomId == null) return;
    _roomSub?.cancel();
    _roomSub = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_chatRoomId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          final data = snapshot.data();
          if (data == null) return;
          final wallpaper = data['wallpaper'] as String?;
          final nicknames = data['nicknames'] as Map<String, dynamic>?;
          String? nickname;
          if (nicknames != null) {
            nickname = nicknames[widget.receiverId] as String?;
          }
          setState(() {
            _wallpaper = wallpaper;
            _nickname = nickname;
          });
        });
  }

  void _listenToUser() {
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.receiverId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          final data = snapshot.data();
          if (data == null) return;
          setState(() {
            _receiverUsername = data['username'] as String?;
          });
        });
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

          for (final msg in messages) {
            if (msg.senderId != currentUid && msg.id != null) {
              if (!_processedStatusIds.contains(msg.id)) {
                _processedStatusIds.add(msg.id!);
                if (msg.status == 'sent') {
                  _chatRepository.updateMessageStatus(
                    _chatRoomId!,
                    msg.id!,
                    'delivered',
                  );
                } else if (_hasMarkedRead && msg.status != 'read') {
                  _chatRepository.updateMessageStatus(
                    _chatRoomId!,
                    msg.id!,
                    'read',
                  );
                }
              }
            }
          }

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

    final blocked = await _chatRepository.isBlocked(
      currentUid,
      widget.receiverId,
    );
    if (blocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot send message. User is blocked.'),
            backgroundColor: AppColors.error,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sent: ${_formatTimestamp(message.timestamp)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.status == 'read' && message.readAt != null
                          ? 'Seen: ${_formatTimestamp(message.readAt!)}'
                          : 'Seen: Not yet seen',
                      style: TextStyle(
                        fontSize: 13,
                        color: message.status == 'read'
                            ? AppColors.online
                            : AppColors.textSecondary,
                        fontWeight: message.status == 'read'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
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
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Message Info'),
                subtitle: Text(
                  'Sent: ${DateFormatter.formatTime(message.timestamp)}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMessageInfo(message);
                },
              ),
              const ListTile(
                leading: Icon(Icons.cancel_outlined),
                title: Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inHours < 24) return 'Today at ${DateFormatter.formatTime(date)}';
    if (diff.inDays == 1)
      return 'Yesterday at ${DateFormatter.formatTime(date)}';
    return DateFormatter.formatDate(date);
  }

  void _showMessageInfo(MessageModel message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Message Info',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('Sent', DateFormatter.formatTime(message.timestamp)),
              const SizedBox(height: 8),
              _infoRow(
                'Seen',
                message.status == 'read' && message.readAt != null
                    ? DateFormatter.formatTime(message.readAt!)
                    : 'Not yet seen',
              ),
              if (message.status == 'read' && message.readAt != null) ...[
                const SizedBox(height: 8),
                _infoRow('Read', DateFormatter.formatSeenTime(message.readAt!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
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
    await _chatRepository.deleteMessageForMe(
      _chatRoomId!,
      message.id!,
      currentUid,
    );
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
    final chatRoomData = chatRoomDoc.data();
    final clearedTs = (chatRoomData?['clearedAt'] as Timestamp?)?.toDate();

    if (mounted && clearedTs != _clearedAt) {
      setState(() => _clearedAt = clearedTs);
      _listenToMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _nickname ?? widget.receiverName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(displayName),
      body: _isInitialized
          ? _buildBody()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  PreferredSizeWidget _buildAppBar(String displayName) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          ProfileAvatar(
            photoUrl: widget.receiverPhotoUrl,
            name: displayName.isNotEmpty
                ? displayName
                : _receiverUsername ?? 'U',
            radius: 20,
            showOnlineDot: false,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName.isNotEmpty
                        ? displayName
                        : _receiverUsername ?? 'User',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_nickname != null && widget.receiverName.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '~${widget.receiverName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
              _buildOnlineStatus(),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _openChatInfo,
          icon: const Icon(
            Icons.info_outline_rounded,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineStatus() {
    return _OnlineStatusWidget(receiverId: widget.receiverId);
  }

  Widget _buildBody() {
    if (_chatRoomId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Could not load chat',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
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
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hello to ${widget.receiverName.isNotEmpty ? widget.receiverName : _receiverUsername ?? 'User'}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Container(
      decoration: _wallpaper != null
          ? BoxDecoration(gradient: _wallpaperGradient(_wallpaper!))
          : null,
      child: ListView.builder(
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
              status: msg.status,
              readAt: msg.readAt,
            ),
          );
        },
      ),
    );
  }

  LinearGradient _wallpaperGradient(String wallpaper) {
    switch (wallpaper) {
      case 'lavender':
        return const LinearGradient(
          colors: [Color(0xFFE8E0FF), Color(0xFFF8F7F4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'beige':
        return const LinearGradient(
          colors: [Color(0xFFF5F0E8), Color(0xFFF8F7F4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'floral':
        return const LinearGradient(
          colors: [Color(0xFFFFF0F0), Color(0xFFF8F7F4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'gradient':
        return const LinearGradient(
          colors: [Color(0xFFE0F0FF), Color(0xFFF8F7F4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'custom':
        return const LinearGradient(
          colors: [Color(0xFF2C2C2C), Color(0xFF1A1D26)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFFF8F7F4), Color(0xFFF8F7F4)],
        );
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
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
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineStatusWidget extends StatelessWidget {
  final String receiverId;

  const _OnlineStatusWidget({required this.receiverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isOnline = data?['isOnline'] as bool? ?? false;
        final lastSeen = (data?['lastSeen'] as Timestamp?)?.toDate();
        return OnlineStatus(isOnline: isOnline, lastSeen: lastSeen);
      },
    );
  }
}
