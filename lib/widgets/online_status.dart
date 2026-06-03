import 'package:flutter/material.dart';

import '../core/utils/date_formatter.dart';

class OnlineStatus extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSeen;

  const OnlineStatus({
    super.key,
    required this.isOnline,
    this.lastSeen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isOnline ? 'Online' : 'Last seen ${DateFormatter.formatLastSeen(lastSeen)}',
          style: TextStyle(
            color: isOnline ? Colors.green : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
