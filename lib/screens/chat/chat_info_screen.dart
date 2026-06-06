import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/storage_service.dart';
import '../../widgets/profile_avatar.dart';
import '../memories_screen.dart';
import 'chat_media_screen.dart';

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
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  UserModel? _receiver;
  bool _isBlocked = false;
  bool _isLoading = true;
  String? _currentWallpaper;
  String? _currentNickname;
  bool _isMuted = false;
  bool _isUploading = false;

  static const List<_WallpaperOption> _wallpapers = [
    _WallpaperOption('default', 'Default', Color(0xFFF8F7F4)),
    _WallpaperOption('lavender', 'Soft Lavender', Color(0xFFE8E0FF)),
    _WallpaperOption('beige', 'Beige Aesthetic', Color(0xFFF5F0E8)),
    _WallpaperOption('floral', 'Floral', Color(0xFFFFF0F0)),
    _WallpaperOption('gradient', 'Minimal Gradient', Color(0xFFE0F0FF)),
    _WallpaperOption('custom', 'Custom Image', Color(0xFF2C2C2C)),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final receiver = await _userRepository.getUser(widget.receiverId);
    final currentUser = await _userRepository.getUser(currentUid);
    final room = await _chatRepository.getChatRoom(widget.chatRoomId);

    if (mounted) {
      setState(() {
        _receiver = receiver;
        _isBlocked =
            currentUser?.blockedUsers.contains(widget.receiverId) ?? false;
        _currentWallpaper = room?.wallpaper;
        _currentNickname = room?.nicknames[widget.receiverId];
        final mutedUntil = room?.mutedUntil[currentUid];
        _isMuted = room?.mutedBy.contains(currentUid) ?? false ||
            (mutedUntil != null && mutedUntil.isAfter(DateTime.now()));
        _isLoading = false;
      });
    }
  }

  Future<void> _setWallpaper(String? wallpaper) async {
    await _chatRepository.updateChatRoom(widget.chatRoomId, {
      'wallpaper': wallpaper,
    });
    if (mounted) {
      setState(() => _currentWallpaper = wallpaper);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wallpaper updated')));
    }
  }

  Future<void> _uploadWallpaperImage() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final imageUrl = await _storageService.uploadChatWallpaper(
        widget.chatRoomId,
        picked.path,
      );
      await _setWallpaper(imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
      }
    }

    if (mounted) {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _showWallpaperPicker() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change Wallpaper',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a color or upload your own image',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _uploadWallpaperImage();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _isUploading
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Upload',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Solid Colors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _wallpapers.map((wp) {
                final isSelected = _currentWallpaper == wp.id;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _setWallpaper(wp.id == 'default' ? null : wp.id);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: wp.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                                size: 28,
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wp.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNicknameDialog() async {
    final controller = TextEditingController(text: _currentNickname ?? '');
    final result = await showDialog<String>(
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
                'Set Nickname',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Give a cute name for ${widget.receiverName}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nickname',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      final data = <String, dynamic>{
        'nicknames.${widget.receiverId}': result.isEmpty ? null : result,
      };
      if (result.isEmpty) {
        data['nicknames'] = FieldValue.delete();
      }
      await _chatRepository.updateChatRoom(widget.chatRoomId, {
        if (result.isEmpty)
          'nicknames.${widget.receiverId}': FieldValue.delete()
        else
          'nicknames.${widget.receiverId}': result,
      });
      if (mounted) {
        setState(() => _currentNickname = result.isEmpty ? null : result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isEmpty ? 'Nickname removed' : 'Nickname set to $result',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showMuteOptions() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final room = await _chatRepository.getChatRoom(widget.chatRoomId);
    final mutedBy = List<String>.from(room?.mutedBy ?? []);
    final mutedUntil = Map<String, DateTime>.from(room?.mutedUntil ?? {});
    final mutedUntilDate = mutedUntil[currentUid];
    final isCurrentlyMuted = mutedBy.contains(currentUid) ||
        (mutedUntilDate != null && mutedUntilDate.isAfter(DateTime.now()));

    if (isCurrentlyMuted) {
      await _unmuteChat(currentUid);
      return;
    }

    if (!mounted) return;

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
              const SizedBox(height: 16),
              const Text(
                'Mute Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will not receive notifications for this chat',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.timer_outlined,
                      color: Color(0xFF4CAF50)),
                ),
                title: const Text('8 Hours'),
                onTap: () => Navigator.pop(ctx, '8h'),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      const Icon(Icons.timer_outlined, color: Color(0xFFFF9800)),
                ),
                title: const Text('24 Hours'),
                onTap: () => Navigator.pop(ctx, '24h'),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.calendar_today_outlined,
                      color: Color(0xFF2196F3)),
                ),
                title: const Text('7 Days'),
                onTap: () => Navigator.pop(ctx, '7d'),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.all_inclusive_rounded,
                      color: Color(0xFF9C27B0)),
                ),
                title: const Text('Forever'),
                onTap: () => Navigator.pop(ctx, 'forever'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.cancel_outlined, color: Colors.grey),
                ),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;

    DateTime? until;
    switch (result) {
      case '8h':
        until = DateTime.now().add(const Duration(hours: 8));
        break;
      case '24h':
        until = DateTime.now().add(const Duration(hours: 24));
        break;
      case '7d':
        until = DateTime.now().add(const Duration(days: 7));
        break;
      case 'forever':
        break;
    }

    if (until != null) {
      await _chatRepository.updateChatRoom(widget.chatRoomId, {
        'mutedUntil.$currentUid': Timestamp.fromDate(until),
      });
    } else {
      await _chatRepository.updateChatRoom(widget.chatRoomId, {
        'mutedBy': FieldValue.arrayUnion([currentUid]),
      });
    }

    if (mounted) {
      setState(() => _isMuted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat muted')),
      );
    }
  }

  Future<void> _unmuteChat(String currentUid) async {
    final room = await _chatRepository.getChatRoom(widget.chatRoomId);
    final mutedBy = List<String>.from(room?.mutedBy ?? []);
    mutedBy.remove(currentUid);

    final updates = <String, dynamic>{
      'mutedBy': mutedBy,
      'mutedUntil.$currentUid': FieldValue.delete(),
    };

    await _chatRepository.updateChatRoom(widget.chatRoomId, updates);

    if (mounted) {
      setState(() => _isMuted = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications unmuted')),
      );
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'Clear all messages for you? Other participants will still have them.',
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
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
          content: Text(
            "Block ${widget.receiverName}? They won't be able to message you.",
          ),
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

  void _openViewMedia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatMediaScreen(chatRoomId: widget.chatRoomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat Info',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileSection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Chat Customisation'),
                  const SizedBox(height: 12),
                  _buildOption(
                    icon: Icons.wallpaper_rounded,
                    color: AppColors.primary,
                    title: 'Change Wallpaper',
                    subtitle: _getWallpaperSubtitle(),
                    onTap: _showWallpaperPicker,
                  ),
                  const SizedBox(height: 10),
                  _buildOption(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFFF0B5B5),
                    title: 'Set Nickname',
                    subtitle: _currentNickname != null
                        ? '$_currentNickname ~ ${widget.receiverName}'
                        : 'Give a cute name',
                    onTap: _showNicknameDialog,
                  ),
                  const SizedBox(height: 10),
                  _buildOption(
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFFB5E2D4),
                    title: 'View Shared Media',
                    subtitle: 'Photos and videos shared in this chat',
                    onTap: _openViewMedia,
                  ),
                  const SizedBox(height: 10),
                  _buildOption(
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFFD4B5E2),
                    title: 'View Shared Memories',
                    subtitle: 'Browse your albums together',
                    onTap: _openSharedMemories,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Notifications'),
                  const SizedBox(height: 12),
                  _buildOption(
                    icon: _isMuted
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_rounded,
                    color: _isMuted ? Colors.orange : AppColors.primary,
                    title: _isMuted ? 'Muted' : 'Mute Notifications',
                    subtitle: _isMuted
                        ? 'Notifications are silenced'
                        : 'Receive message notifications',
                    onTap: _showMuteOptions,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Privacy & Support'),
                  const SizedBox(height: 12),
                  _buildOption(
                    icon: Icons.delete_sweep_outlined,
                    color: Colors.orange,
                    title: 'Clear Chat',
                    subtitle: 'Remove all messages for you',
                    onTap: _clearChat,
                  ),
                  const SizedBox(height: 10),
                  _buildOption(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    title: 'Delete Chat',
                    subtitle: 'Remove this conversation',
                    onTap: _deleteChat,
                  ),
                  const SizedBox(height: 10),
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

  String _getWallpaperSubtitle() {
    if (_currentWallpaper == null) return 'Default wallpaper';
    if (_currentWallpaper!.startsWith('http')) return 'Custom image';
    final match = _wallpapers.where((w) => w.id == _currentWallpaper);
    return match.isNotEmpty ? match.first.label : 'Custom';
  }

  Widget _buildProfileSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ProfileAvatar(
            photoUrl: widget.receiverPhotoUrl,
            name: widget.receiverName,
            radius: 44,
          ),
          const SizedBox(height: 16),
          Text(
            _currentNickname ?? widget.receiverName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (_currentNickname != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.receiverName,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (_receiver != null) ...[
            const SizedBox(height: 4),
            Text(
              '@${_receiver!.username}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        trailing: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  void _openSharedMemories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MemoriesScreen()),
    );
  }
}

class _WallpaperOption {
  final String id;
  final String label;
  final Color color;

  const _WallpaperOption(this.id, this.label, this.color);
}
