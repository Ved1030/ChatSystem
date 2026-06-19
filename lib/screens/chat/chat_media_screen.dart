import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/media_model.dart';
import '../../repositories/chat_repository.dart';
import '../media/image_view_screen.dart';

class ChatMediaScreen extends StatefulWidget {
  final String chatRoomId;

  const ChatMediaScreen({super.key, required this.chatRoomId});

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> {
  final ChatRepository _chatRepository = ChatRepository();

  List<MediaItem> _mediaItems = [];
  bool _loading = true;
  StreamSubscription? _sub;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _loadMedia();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    final uid = _currentUid;
    if (uid == null) return;
    _sub = _chatRepository.chatMediaStream(widget.chatRoomId, uid).listen((items) {
      if (mounted) {
        setState(() {
          _mediaItems = items;
          _loading = false;
        });
      }
    });
  }

  List<String> get _imageUrls => _mediaItems.map((e) => e.url).toList();

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
          'Shared Media',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mediaItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_rounded,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No shared media',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    final item = _mediaItems[index];
                    return GestureDetector(
                      onTap: () => _viewImage(index),
                      onLongPress: () => _onMediaLongPress(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: item.url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.shimmer,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.border,
                            child: const Icon(
                              Icons.broken_image,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _viewImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewScreen(
          imageUrls: _imageUrls,
          initialIndex: index,
          tag: 'media_grid_${_mediaItems[index].url}',
        ),
      ),
    );
  }

  Future<void> _onMediaLongPress(MediaItem item) async {
    final uid = _currentUid;
    if (uid == null) return;

    final isMyMedia = item.senderId == uid;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyMedia)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text('Delete for Everyone'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteForEveryone(item);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for Me'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteForMe(item);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteForEveryone(MediaItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete for Everyone'),
        content: const Text('This photo will be deleted for everyone.'),
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
      await _chatRepository.deleteChatImageForEveryone(
        widget.chatRoomId,
        item.messageId,
        item.url,
      );
    }
  }

  Future<void> _deleteForMe(MediaItem item) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _chatRepository.deleteMessageForMe(
      widget.chatRoomId,
      item.messageId,
      uid,
    );
  }
}
