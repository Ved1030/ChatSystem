import 'package:intl/intl.dart';

class DateFormatter {
  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String formatChatListTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(date);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(date);
    } else {
      return DateFormat('M/d/yy').format(date);
    }
  }

  static String formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'min' : 'mins'} ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('M/d/yy').format(date);
    }
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatSeenTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'min' : 'mins'} ago';
    } else if (diff.inHours < 24) {
      return 'today at ${DateFormat('h:mm a').format(date)}';
    } else if (diff.inDays == 1) {
      return 'yesterday at ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('M/d/yy').format(date);
    }
  }
}
