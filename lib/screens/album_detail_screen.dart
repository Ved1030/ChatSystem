import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../models/album_model.dart';
import '../repositories/chat_repository.dart';
import '../services/supabase_storage_service.dart';
import '../screens/media/image_view_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final AlbumModel album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final ChatRepository _chatRepository = ChatRepository();
  final SupabaseStorageService _storageService = SupabaseStorageService();
  final ImagePicker _imagePicker = ImagePicker();

  List<AlbumPhotoModel> _photos = [];
  bool _loading = true;
  StreamSubscription? _photosSub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _photosSub?.cancel();
    super.dispose();
  }

  void _listen() {
    if (widget.album.id == null) return;
    _photosSub = _chatRepository.albumPhotosStream(widget.album.id!).listen((
      photos,
    ) {
      if (mounted) {
        setState(() {
          _photos = photos;
          _loading = false;
        });
      }
    });
  }

  Future<void> _addPhoto() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;

      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      final albumId = widget.album.id;
      if (albumId == null) return;

      final photoId = DateTime.now().millisecondsSinceEpoch.toString();

      final imageUrl = await _storageService.uploadAlbumPhotoSupabase(
        albumId,
        photoId,
        picked.path,
      );

      final photo = AlbumPhotoModel(
        imageUrl: imageUrl,
        creatorId: currentUid,
        createdAt: DateTime.now(),
      );

      await _chatRepository.addAlbumPhoto(albumId, photo);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add photo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.album.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded),
            onPressed: _addPhoto,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_photos.isEmpty) {
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
                Icons.photo_library_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.album.description.isNotEmpty
                  ? widget.album.description
                  : 'No photos yet',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add photos',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return GestureDetector(
          onTap: () => _viewPhoto(index),
          onLongPress: () => _deletePhoto(photo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: photo.imageUrl,
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
    );
  }

  void _viewPhoto(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewScreen(
          imageUrl: _photos[index].imageUrl,
          tag: 'album_photo_${_photos[index].id}',
        ),
      ),
    );
  }

  Future<void> _deletePhoto(AlbumPhotoModel photo) async {
    if (widget.album.id == null || photo.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Delete this photo?'),
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
      await _chatRepository.deleteAlbumPhoto(widget.album.id!, photo.id!);
    }
  }
}
