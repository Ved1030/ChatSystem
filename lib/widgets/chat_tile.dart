import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';
import '../models/user_model.dart';
import 'profile_avatar.dart';

class ChatTile extends StatelessWidget {
  final UserModel user;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? nickname;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.user,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.nickname,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ProfileAvatar(
                photoUrl: user.photoUrl,
                name: user.name,
                radius: 28,
                showOnlineDot: true,
                isOnline: user.isOnline,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          nickname ?? user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (nickname != null)
                          Text(
                            ' ~ ${user.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        if (lastMessageTime != null)
                          Text(
                            DateFormatter.formatChatListTime(lastMessageTime),
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (lastMessage != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
