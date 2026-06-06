import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/message_model.dart';
import '../screens/media/image_view_screen.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onLongPress;
  final VoidCallback? onViewOnceOpened;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onLongPress,
    this.onViewOnceOpened,
  });

  IconData get _statusIcon {
    switch (message.status) {
      case 'read':
        return Icons.done_all_rounded;
      case 'delivered':
        return Icons.done_all_rounded;
      default:
        return Icons.done_rounded;
    }
  }

  Color get _statusColor {
    switch (message.status) {
      case 'read':
        return const Color(0xFF81C784);
      case 'delivered':
        return Colors.white.withValues(alpha: 0.7);
      default:
        return Colors.white.withValues(alpha: 0.5);
    }
  }

  void _openImageView(BuildContext context) {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewScreen(
          imageUrl: message.mediaUrl!,
          tag: 'chat_image_${message.id}',
          isViewOnce: message.isViewOnce && !isMe,
          onClose: () {
            onViewOnceOpened?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: message.isImage
                ? MediaQuery.of(context).size.width * 0.7
                : MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDeleted
                ? (isMe
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border)
                : (isMe ? AppColors.primary : AppColors.surface),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe
                  ? const Radius.circular(20)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: isMe
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  bool get isDeleted => message.isDeleted;

  Widget _buildContent(BuildContext context) {
    if (isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'This message was deleted',
          style: TextStyle(
            color: isMe ? Colors.white60 : AppColors.textSecondary,
            fontSize: 15,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (message.isViewOnce && !isMe) {
      return _buildViewOnceContent(context);
    }

    if (message.isImage && message.mediaUrl != null) {
      return _buildImageContent(context);
    }

    return _buildTextContent();
  }

  Widget _buildTextContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormatter.formatTime(message.timestamp),
                style: TextStyle(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(_statusIcon, size: 14, color: _statusColor),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: () => _openImageView(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe
                  ? const Radius.circular(20)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(20),
            ),
            child: Hero(
              tag: 'chat_image_${message.id}',
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: isMe
                      ? AppColors.primary.withValues(alpha: 0.7)
                      : AppColors.border,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.border,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormatter.formatTime(message.timestamp),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                if (message.isTemporary)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.timer_outlined,
                      size: 12,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(_statusIcon, size: 14, color: _statusColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewOnceContent(BuildContext context) {
    return GestureDetector(
      onTap: () => _openImageView(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.visibility_off_rounded,
                color: isMe ? Colors.white70 : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isMe ? 'You sent a View Once Image' : 'View Once Image',
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe)
                  Text(
                    'Tap to view',
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppColors.primary,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  DateFormatter.formatTime(message.timestamp),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(_statusIcon, size: 14, color: _statusColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
