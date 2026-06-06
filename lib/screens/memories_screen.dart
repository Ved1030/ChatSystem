import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants/app_colors.dart';
import '../models/album_model.dart';
import '../repositories/chat_repository.dart';
import 'album_detail_screen.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final ChatRepository _chatRepository = ChatRepository();

  List<AlbumModel> _albums = [];
  bool _loading = true;
  StreamSubscription? _albumsSub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _albumsSub?.cancel();
    super.dispose();
  }

  void _listen() {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    _albumsSub = _chatRepository.albumsStream(currentUid).listen((albums) {
      if (mounted) {
        setState(() {
          _albums = albums;
          _loading = false;
        });
      }
    });
  }

  void _openAlbum(AlbumModel album) {
    if (album.isPrivate) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PinLockScreen(album: album)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAlbumDialog(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Memories',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_albums.length} albums',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_albums.isEmpty) {
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
            const Text(
              'No albums yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first album',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        return _AlbumCard(
          album: album,
          index: index,
          onTap: () => _openAlbum(album),
        );
      },
    );
  }

  void _showAddAlbumDialog() {
    showDialog(context: context, builder: (ctx) => const _AddAlbumDialog());
  }
}

class _AlbumCard extends StatelessWidget {
  final AlbumModel album;
  final int index;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.albumColors[index % AppColors.albumColors.length];

    return GestureDetector(
      onTap: onTap,
      child:
          Container(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: Container(
                          width: double.infinity,
                          color: color.withValues(alpha: 0.15),
                          child: album.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: album.coverUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _coverPlaceholder(color),
                                  errorWidget: (_, __, ___) =>
                                      _coverPlaceholder(color),
                                )
                              : _coverPlaceholder(color),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  album.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (album.isPrivate)
                                const Icon(
                                  Icons.lock_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${album.photoCount} ${album.photoCount == 1 ? 'photo' : 'photos'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms, delay: (index * 80).ms)
              .scale(
                begin: const Offset(0.95, 0.95),
                duration: 300.ms,
                delay: (index * 80).ms,
              ),
    );
  }

  Widget _coverPlaceholder(Color color) {
    return Center(
      child: Icon(
        Icons.photo_library_rounded,
        size: 40,
        color: color.withValues(alpha: 0.5),
      ),
    );
  }
}

class _AddAlbumDialog extends StatefulWidget {
  const _AddAlbumDialog();

  @override
  State<_AddAlbumDialog> createState() => _AddAlbumDialogState();
}

class _AddAlbumDialogState extends State<_AddAlbumDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isPrivate = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an album title')),
      );
      return;
    }

    if (_isPrivate && _pinController.text.trim().length != 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
      return;
    }

    Navigator.pop(context, {
      'title': title,
      'description': _descriptionController.text.trim(),
      'isPrivate': _isPrivate,
      'pin': _isPrivate ? _pinController.text.trim() : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'New Album',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Album title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Private album',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Switch(
                  value: _isPrivate,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isPrivate = v),
                ),
              ],
            ),
            if (_isPrivate) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _pinController,
                decoration: const InputDecoration(
                  hintText: '4-digit PIN',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Create Album'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PinLockScreen extends StatefulWidget {
  final AlbumModel album;

  const PinLockScreen({super.key, required this.album});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _pinController = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pinController.text.trim() == widget.album.pin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AlbumDetailScreen(album: widget.album),
        ),
      );
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                    Icons.lock_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.album.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter PIN to view this album',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  decoration: InputDecoration(
                    hintText: 'PIN',
                    border: const OutlineInputBorder(),
                    errorText: _error ? 'Incorrect PIN' : null,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
