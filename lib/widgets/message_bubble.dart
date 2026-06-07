import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/message_model.dart';
import '../screens/media/image_view_screen.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onLongPress;
  final VoidCallback? onViewOnceOpened;
  final VoidCallback? onReplyTap;
  final VoidCallback? onSwipeToReply;
  final bool isHighlighted;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onLongPress,
    this.onViewOnceOpened,
    this.onReplyTap,
    this.onSwipeToReply,
    this.isHighlighted = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<Color?> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _highlightAnimation = ColorTween(
      begin: null,
      end: Colors.yellow.withValues(alpha: 0.15),
    ).animate(_highlightController);
    if (widget.isHighlighted) {
      _highlightController.forward();
    }
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isHighlighted && widget.isHighlighted) {
      _highlightController.forward().then((_) {
        _highlightController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  IconData get _statusIcon {
    switch (widget.message.status) {
      case 'read':
        return Icons.done_all_rounded;
      case 'delivered':
        return Icons.done_all_rounded;
      default:
        return Icons.done_rounded;
    }
  }

  Color get _statusColor {
    switch (widget.message.status) {
      case 'read':
        return const Color(0xFF81C784);
      case 'delivered':
        return Colors.white.withValues(alpha: 0.7);
      default:
        return Colors.white.withValues(alpha: 0.5);
    }
  }

  void _openImageView(BuildContext context) {
    if (widget.message.mediaUrl == null || widget.message.mediaUrl!.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewScreen(
          imageUrls: [widget.message.mediaUrl!],
          tag: 'chat_image_${widget.message.id}',
          isViewOnce: widget.message.isViewOnce && !isMe,
          onClose: () {
            widget.onViewOnceOpened?.call();
          },
        ),
      ),
    );
  }

  bool get isDeleted => widget.message.isDeleted;
  bool get isMe => widget.isMe;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
            widget.onSwipeToReply?.call();
          }
        },
        child: AnimatedBuilder(
          animation: _highlightAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              constraints: BoxConstraints(
                maxWidth: widget.message.isImage
                    ? MediaQuery.of(context).size.width * 0.7
                    : MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: _highlightAnimation.value ??
                    (isDeleted
                        ? (isMe
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : AppColors.border)
                        : (isMe ? AppColors.primary : AppColors.surface)),
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
              child: child,
            );
          },
          child: _buildContent(context),
        ),
      ),
    );
  }

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.message.replyToMessageId != null)
          _buildReplyBar(context),
        if (widget.message.isViewOnce && !widget.message.viewed)
          _buildViewOnceContent(context)
        else if (widget.message.isViewOnce && widget.message.viewed)
          _buildPhotoOpenedContent()
        else if (widget.message.isImage && widget.message.mediaUrl != null)
          _buildImageContent(context)
        else
          _buildTextContent(),
      ],
    );
  }

  Widget _buildReplyBar(BuildContext context) {
    final replyText = widget.message.replyToText ?? '';
    final replySender = widget.message.replyToSender ?? '';

    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white54 : AppColors.primary,
              width: 2.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replySender,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white70 : AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              replyText,
              style: TextStyle(
                fontSize: 12,
              color: isMe
                  ? Colors.white70
                  : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.text,
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
                DateFormatter.formatTime(widget.message.timestamp),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              tag: 'chat_image_${widget.message.id}',
              child: CachedNetworkImage(
                imageUrl: widget.message.mediaUrl!,
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
                  DateFormatter.formatTime(widget.message.timestamp),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                if (widget.message.isTemporary)
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
    final canTap = !isMe && !widget.message.viewed;
    return GestureDetector(
      onTap: canTap ? () => _openImageView(context) : null,
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
              'View Once Photo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isMe ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canTap)
                  Text(
                    'Tap to view',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  DateFormatter.formatTime(widget.message.timestamp),
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

  Widget _buildPhotoOpenedContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_rounded,
            size: 16,
            color: isMe
                ? Colors.white.withValues(alpha: 0.6)
                : AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            'Photo Opened',
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormatter.formatTime(widget.message.timestamp),
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
    );
  }
}
