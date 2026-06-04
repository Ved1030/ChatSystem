import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';

class OnlineStatus extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSeen;

  const OnlineStatus({super.key, this.isOnline = false, this.lastSeen});

  @override
  Widget build(BuildContext context) {
    if (isOnline) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: AppColors.online),
          SizedBox(width: 4),
          Text(
            'Online',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.online,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (lastSeen != null) {
      final timeStr = DateFormatter.formatLastSeen(lastSeen!);
      return Text(
        'Last seen $timeStr',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      );
    }

    return const SizedBox();
  }
}
