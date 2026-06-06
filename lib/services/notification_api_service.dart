import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NotificationApiService {
  static Future<void> sendNotification({
    required String senderId,
    required String receiverId,
    required String roomId,
    required String message,
    required String messageType,
    required String messageId,
    required String senderName,
    required bool notificationsEnabled,
    required bool soundEnabled,
    required bool vibrationEnabled,
    required bool isMuted,
  }) async {
    final backendUrl = dotenv.env['BACKEND_URL'];
    final apiKey = dotenv.env['BACKEND_API_KEY'];

    if (backendUrl == null || backendUrl.isEmpty) return;
    if (apiKey == null || apiKey.isEmpty) return;

    try {
      await http.post(
        Uri.parse('$backendUrl/api/send-notification'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode({
          'senderId': senderId,
          'receiverId': receiverId,
          'roomId': roomId,
          'message': message,
          'messageType': messageType,
          'messageId': messageId,
          'senderName': senderName,
          'notificationsEnabled': notificationsEnabled,
          'soundEnabled': soundEnabled,
          'vibrationEnabled': vibrationEnabled,
          'isMuted': isMuted,
        }),
      );
    } catch (_) {}
  }
}
