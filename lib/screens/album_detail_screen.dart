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
  bool _uploading = false;
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
    if (_uploading) return;
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;

      setState(() => _uploading = true);

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
        uploadedBy: currentUid,
        uploadedAt: DateTime.now(),
      );

      final docId = await _chatRepository.addAlbumPhoto(albumId, photo);

      if (_photos.isEmpty && docId.isNotEmpty) {
        await _chatRepository.updateAlbum(albumId, {
          'coverUrl': imageUrl,
          'coverImageUrl': imageUrl,
        });
      }

      setState(() => _uploading = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo added')));
      }
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add photo: $e')));
      }
    }
  }

  Future<void> _confirmDeleteAlbum() async {
    if (widget.album.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Album'),
        content: Text('Delete "${widget.album.title}" and all its photos?'),
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
    if (confirm == true && mounted) {
      await _chatRepository.deleteAlbumWithImages(widget.album.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.album.title),
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (!_uploading)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              onPressed: _addPhoto,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _confirmDeleteAlbum();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Album', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
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
        final isCover = photo.imageUrl == widget.album.coverUrl;
        return GestureDetector(
          onTap: () => _viewPhoto(index),
          onLongPress: () => _deletePhoto(photo),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: photo.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
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
              if (isCover)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Cover',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _viewPhoto(int index) {
    final urls = _photos.map((p) => p.imageUrl).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewScreen(
          imageUrls: urls,
          initialIndex: index,
          tag: 'album_photo_${_photos[index].id ?? index}',
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
      await _chatRepository.deleteAlbumPhotoWithImage(
        widget.album.id!,
        photo.id!,
        photo.imageUrl,
      );

      if (photo.imageUrl == widget.album.coverUrl) {
        final remainingPhotos = _photos.where((p) => p.id != photo.id).toList();
        if (remainingPhotos.isNotEmpty) {
          await _chatRepository.updateAlbum(widget.album.id!, {
            'coverUrl': remainingPhotos.first.imageUrl,
            'coverImageUrl': remainingPhotos.first.imageUrl,
          });
        } else {
          await _chatRepository.updateAlbum(widget.album.id!, {
            'coverUrl': '',
            'coverImageUrl': '',
          });
        }
      }
    }
  }
}
