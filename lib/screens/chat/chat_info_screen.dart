import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/profile_avatar.dart';

class ChatInfoScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverPhotoUrl;
  final String chatRoomId;

  const ChatInfoScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhotoUrl,
    required this.chatRoomId,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  final UserRepository _userRepository = UserRepository();
  final ChatRepository _chatRepository = ChatRepository();
  UserModel? _receiver;
  bool _isBlocked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final receiver = await _userRepository.getUser(widget.receiverId);
    final currentUser = await _userRepository.getUser(currentUid);

    if (mounted) {
      setState(() {
        _receiver = receiver;
        _isBlocked = currentUser?.blockedUsers.contains(widget.receiverId) ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Clear all messages for you? Other participants will still have them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      await _chatRepository.clearChat(widget.chatRoomId, currentUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat cleared')),
        );
      }
    }
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      await _chatRepository.deleteChatForMe(widget.chatRoomId, currentUid);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _toggleBlock() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    if (_isBlocked) {
      await _userRepository.unblockUser(currentUid, widget.receiverId);
      if (mounted) {
        setState(() => _isBlocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.receiverName} unblocked')),
        );
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Block User'),
          content: Text('Block ${widget.receiverName}? They won\'t be able to message you.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _userRepository.blockUser(currentUid, widget.receiverId);
        if (mounted) {
          setState(() => _isBlocked = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.receiverName} blocked')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat Info',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ProfileAvatar(
                    photoUrl: widget.receiverPhotoUrl,
                    name: widget.receiverName,
                    radius: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.receiverName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_receiver != null)
                    Text(
                      '@${_receiver!.username}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 40),
                  _buildOption(
                    icon: Icons.delete_sweep_outlined,
                    color: Colors.orange,
                    title: 'Clear Chat',
                    subtitle: 'Remove all messages for you',
                    onTap: _clearChat,
                  ),
                  const SizedBox(height: 12),
                  _buildOption(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    title: 'Delete Chat',
                    subtitle: 'Remove this conversation',
                    onTap: _deleteChat,
                  ),
                  const SizedBox(height: 12),
                  _buildOption(
                    icon: _isBlocked ? Icons.block : Icons.block_flipped,
                    color: _isBlocked ? Colors.green : Colors.red,
                    title: _isBlocked ? 'Unblock User' : 'Block User',
                    subtitle: _isBlocked
                        ? 'Allow messages from this user'
                        : 'Prevent messages from this user',
                    onTap: _toggleBlock,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
