import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool showOnlineDot;
  final bool isOnline;

  const ProfileAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.showOnlineDot = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _resolveImage() == null
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.8),
                      AppColors.secondary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: _resolveImage() != null
                ? Image(
                    image: _resolveImage()!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitial(),
                  )
                : _buildInitial(),
          ),
        ),
        if (showOnlineDot)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.45,
              height: radius * 0.45,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.online : AppColors.textSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: isOnline
                        ? AppColors.online.withValues(alpha: 0.3)
                        : Colors.transparent,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  ImageProvider? _resolveImage() {
    if (photoUrl == null || photoUrl!.isEmpty) return null;
    if (photoUrl!.startsWith('http')) {
      return NetworkImage(photoUrl!);
    }
    return FileImage(File(photoUrl!));
  }
}
