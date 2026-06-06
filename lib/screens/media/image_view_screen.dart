import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageViewScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String tag;
  final bool isViewOnce;
  final VoidCallback? onClose;

  const ImageViewScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    required this.tag,
    this.isViewOnce = false,
    this.onClose,
  });

  @override
  State<ImageViewScreen> createState() => _ImageViewScreenState();
}

class _ImageViewScreenState extends State<ImageViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _hasBeenViewed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentUrl => widget.imageUrls[_currentIndex];

  Future<void> _downloadImage() async {
    try {
      final url = _currentUrl;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download image')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final ext = url.split('.').last.split('?').first;
      final file = File('${dir.path}/image_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  void _shareImage() {
    Clipboard.setData(ClipboardData(text: _currentUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  void _handleClose() {
    if (widget.isViewOnce && !_hasBeenViewed) {
      _hasBeenViewed = true;
      widget.onClose?.call();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final heroTag = index == widget.initialIndex
                      ? widget.tag
                      : '${widget.tag}_${index}_viewer';
                  return Hero(
                    tag: heroTag,
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrls[index],
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white54,
                                  size: 64,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_showControls) ...[
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _handleClose,
                        iconSize: 28,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black26,
                        ),
                      ),
                      const Spacer(),
                      if (widget.imageUrls.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.imageUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (widget.isViewOnce)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View Once',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _controlButton(
                        icon: Icons.download_rounded,
                        onPressed: _downloadImage,
                      ),
                      const SizedBox(width: 24),
                      _controlButton(
                        icon: Icons.share_rounded,
                        onPressed: _shareImage,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        iconSize: 24,
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}
