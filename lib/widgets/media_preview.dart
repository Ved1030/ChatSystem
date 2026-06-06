import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class MediaPreview extends StatelessWidget {
  final String? imageUrl;
  final String? localPath;
  final double width;
  final double height;
  final double borderRadius;
  final VoidCallback? onTap;

  const MediaPreview({
    super.key,
    this.imageUrl,
    this.localPath,
    this.width = 120,
    this.height = 120,
    this.borderRadius = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (localPath != null && localPath!.isNotEmpty) {
      return Image.file(
        File(localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _loadingPlaceholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.border,
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: AppColors.textSecondary,
          size: 32,
        ),
      ),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      color: AppColors.shimmer,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
