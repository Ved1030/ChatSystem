import 'package:flutter/material.dart';

import '../core/utils/date_formatter.dart';
import '../models/user_model.dart';
import 'online_status.dart';
import 'profile_avatar.dart';

class ChatTile extends StatelessWidget {
  final UserModel user;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.user,
    this.lastMessage,
    this.lastMessageTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: ProfileAvatar(
            photoUrl: user.photoUrl,
            name: user.name,
            radius: 28,
            showOnlineDot: true,
            isOnline: user.isOnline,
          ),
          title: Text(
            user.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${user.username}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              if (lastMessage != null)
                Text(
                  lastMessage!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lastMessageTime != null)
                Text(
                  DateFormatter.formatChatListTime(lastMessageTime),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              const SizedBox(height: 4),
              const Icon(
                Icons.chat,
                color: Colors.green,
                size: 20,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
