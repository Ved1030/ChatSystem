import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/message_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/media_cleanup_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../services/typing_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/online_status.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/typing_indicator.dart';
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
  final SupabaseStorageService _storageService = SupabaseStorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final MediaCleanupService _cleanupService = MediaCleanupService();

  String? _chatRoomId;
  String? _receiverUsername;
  bool _isInitialized = false;
  bool _isNearBottom = true;
  DateTime? _clearedAt;
  bool _hasMarkedRead = false;
  String? _wallpaper;
  String? _nickname;
  bool _isSending = false;

  List<MessageModel> _messages = [];
  final Set<String> _processedStatusIds = {};
  StreamSubscription<List<MessageModel>>? _messagesSub;
  StreamSubscription<DocumentSnapshot>? _roomSub;
  StreamSubscription<DocumentSnapshot>? _userSub;

  final TypingService _typingService = TypingService();
  bool _isOtherTyping = false;
  StreamSubscription<bool>? _typingSub;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialize();
    _cleanupService.startPeriodicCleanup();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSub?.cancel();
    _roomSub?.cancel();
    _userSub?.cancel();
    _typingSub?.cancel();
    _typingService.dispose();
    _typingDebounce?.cancel();
    _cleanupService.stopCleanup();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final isNearBottom = distanceFromBottom < 200;
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
        _setupTypingListener();

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
    final wasNearBottom = _isNearBottom;

    _messagesSub?.cancel();
    _messagesSub = _chatRepository
        .messagesStream(_chatRoomId!, currentUid, clearedAt: _clearedAt)
        .listen((messages) {
          final wasEmpty = _messages.isEmpty;
          final prevLastMsgId = _messages.isNotEmpty ? _messages.last.id : null;

          if (!mounted) return;
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
                    setDeliveredAt: true,
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

          final shouldScroll = wasEmpty && messages.isNotEmpty ||
              (messages.isNotEmpty &&
                  messages.last.id != prevLastMsgId &&
                  wasNearBottom);

          if (shouldScroll) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
  }

  void _setupTypingListener() {
    if (_chatRoomId == null) return;
    _typingSub?.cancel();
    _typingSub = _typingService
        .typingStream(_chatRoomId!, widget.receiverId)
        .listen((isTyping) {
      if (mounted) {
        setState(() => _isOtherTyping = isTyping);
      }
    });
  }

  void _onMessageTextChanged(String value) {
    if (_chatRoomId == null) return;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    if (value.isNotEmpty) {
      _typingService.startTyping(_chatRoomId!, currentUid);
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        _typingService.stopTyping(_chatRoomId!, currentUid);
      });
    } else {
      _typingService.stopTyping(_chatRoomId!, currentUid);
      _typingDebounce?.cancel();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatRoomId == null || _isSending) return;

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
    if (_chatRoomId != null) {
      _typingService.stopTyping(_chatRoomId!, FirebaseAuth.instance.currentUser!.uid);
    }

    if (mounted) setState(() => _isSending = true);

    await _chatRepository.sendMessage(
      chatRoomId: _chatRoomId!,
      senderId: currentUid,
      receiverId: widget.receiverId,
      text: text,
    );

    NotificationService().notifyBackend(
      senderId: currentUid,
      receiverId: widget.receiverId,
      roomId: _chatRoomId!,
      message: text,
      messageType: 'text',
    );

    if (mounted) setState(() => _isSending = false);

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

  Future<void> _showAttachmentSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Send Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachmentOption(
                    ctx,
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    value: 'camera',
                    color: AppColors.primary,
                  ),
                  _attachmentOption(
                    ctx,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    value: 'gallery',
                    color: const Color(0xFFF0B5B5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;

    final XFile? picked = await _imagePicker.pickImage(
      source: result == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (picked == null || !mounted) return;

    _showSendAsOptions(picked.path);
  }

  Widget _attachmentOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSendAsOptions(String imagePath) async {
    if (!mounted) return;

    final mode = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Send As',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.image_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('Normal Image'),
                subtitle: const Text('Never auto deletes'),
                onTap: () => Navigator.pop(ctx, 'normal'),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: Colors.orange,
                  ),
                ),
                title: const Text('Delete After 36 Hours'),
                subtitle: const Text('Auto removes after 36 hours'),
                onTap: () => Navigator.pop(ctx, 'temporary'),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.visibility_off_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text('View Once'),
                subtitle: const Text('Disappears after viewing'),
                onTap: () => Navigator.pop(ctx, 'view_once'),
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

    if (mode == null || !mounted || _chatRoomId == null) return;

    setState(() => _isSending = true);

    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();

      final mediaUrl = await _storageService.uploadChatImage(
        _chatRoomId!,
        messageId,
        imagePath,
      );

      DateTime? expiresAt;
      if (mode == 'temporary') {
        expiresAt = DateTime.now().add(const Duration(hours: 36));
      }

      await _chatRepository.sendMessage(
        chatRoomId: _chatRoomId!,
        senderId: currentUid,
        receiverId: widget.receiverId,
        text: mode == 'view_once' ? 'View Once Image' : 'Image',
        messageType: 'image',
        imageMode: mode,
        mediaUrl: mediaUrl,
        expiresAt: expiresAt,
      );

      NotificationService().notifyBackend(
        senderId: currentUid,
        receiverId: widget.receiverId,
        roomId: _chatRoomId!,
        message: mode == 'view_once' ? 'View Once Image' : 'Image',
        messageType: 'image',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
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
              if (isMyMessage && !message.isViewOnce)
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
                'Delivered',
                message.deliveredAt != null
                    ? DateFormatter.formatSeenTime(message.deliveredAt!)
                    : (message.status == 'delivered' || message.status == 'read'
                        ? 'Delivered'
                        : 'Not yet delivered'),
              ),
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

  Future<void> _handleViewOnceOpened(MessageModel message) async {
    if (_chatRoomId == null || message.id == null || message.mediaUrl == null) {
      return;
    }

    try {
      await _cleanupService.handleViewOnceImageOpened(
        chatRoomId: _chatRoomId!,
        messageId: message.id!,
        mediaUrl: message.mediaUrl!,
      );
    } catch (_) {}
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
              _buildSubtitle(),
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

  Widget _buildSubtitle() {
    if (_isOtherTyping) {
      return TypingIndicator(
        userName: _nickname ?? widget.receiverName,
        isTyping: true,
      );
    }
    return _OnlineStatusWidget(receiverId: widget.receiverId);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
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
        Expanded(
          child: Stack(
            children: [
              _buildMessagesList(),
              if (_messages.isNotEmpty && !_isNearBottom)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _scrollToBottom,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
          return MessageBubble(
            message: msg,
            isMe: msg.senderId == currentUid,
            onLongPress: () => _onMessageLongPress(msg),
            onViewOnceOpened: () => _handleViewOnceOpened(msg),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                onPressed: _isSending ? null : _showAttachmentSheet,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.add_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
              ),
            ),
            const SizedBox(width: 8),
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
                  onChanged: _onMessageTextChanged,
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
                onPressed: _isSending ? null : _sendMessage,
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
