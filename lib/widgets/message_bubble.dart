import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime timestamp;
  final bool isDeleted;
  final String status;
  final DateTime? readAt;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.isDeleted = false,
    this.status = 'sent',
    this.readAt,
  });

  IconData get _statusIcon {
    switch (status) {
      case 'read':
        return Icons.done_all_rounded;
      case 'delivered':
        return Icons.done_all_rounded;
      default:
        return Icons.done_rounded;
    }
  }

  Color get _statusColor {
    switch (status) {
      case 'read':
        return const Color(0xFF81C784);
      case 'delivered':
        return Colors.white.withValues(alpha: 0.7);
      default:
        return Colors.white.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
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
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              isDeleted ? 'This message was deleted' : message,
              style: TextStyle(
                color: isDeleted
                    ? (isMe ? Colors.white60 : AppColors.textSecondary)
                    : (isMe ? Colors.white : AppColors.textPrimary),
                fontSize: 15,
                fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormatter.formatTime(timestamp),
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
      ),
    );
  }
}
