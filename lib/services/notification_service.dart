import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../models/notification_model.dart';
import 'firestore_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _currentToken;
  bool _isInitialized = false;

  final StreamController<NotificationData> _onNotificationTap =
      StreamController<NotificationData>.broadcast();

  Stream<NotificationData> get onNotificationTap => _onNotificationTap.stream;

  Function(String)? _onTokenChanged;

  set onTokenChanged(Function(String)? callback) {
    _onTokenChanged = callback;
  }

  String? get currentToken => _currentToken;

  String? _backendUrl;

  void setBackendUrl(String url) {
    _backendUrl = url;
  }

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (_isInitialized) return;
    _navigatorKey = navigatorKey;

    await _initLocalNotifications();
    await _requestPermissions();
    await _getToken();
    _setupListeners();
    _isInitialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  Future<String?> _getToken() async {
    try {
      _currentToken = await _messaging.getToken();
      return _currentToken;
    } catch (e) {
      return null;
    }
  }

  void _setupListeners() {
    _messaging.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _onTokenChanged?.call(newToken);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);
    _messaging.getInitialMessage().then(_handleInitialMessage);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    try {
      final roomId = data['roomId'] as String? ?? data['chatRoomId'] as String?;
      final messageId = data['messageId'] as String?;
      if (roomId != null && messageId != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final firestoreService = FirestoreService();
          final msgDoc = await FirebaseFirestore.instance
              .collection('chat_rooms')
              .doc(roomId)
              .collection('messages')
              .doc(messageId)
              .get();
          if (msgDoc.exists) {
            final msgData = msgDoc.data() as Map<String, dynamic>;
            if (msgData['receiverId'] == user.uid && msgData['status'] == 'sent') {
              await firestoreService.updateMessageStatus(
                roomId,
                messageId,
                'delivered',
                setDeliveredAt: true,
              );
            }
          }
        }
      }
    } catch (_) {}

    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(data),
    );
  }

  void _handleNotificationOpenedApp(RemoteMessage message) {
    final data = message.data;
    if (data.isNotEmpty) {
      final notificationData = NotificationData.fromMap(data);
      _onNotificationTap.add(notificationData);
      _navigateToChat(notificationData);
    }
  }

  void _handleInitialMessage(RemoteMessage? message) {
    if (message == null) return;
    final data = message.data;
    if (data.isNotEmpty) {
      final notificationData = NotificationData.fromMap(data);
      _onNotificationTap.add(notificationData);
      _navigateToChat(notificationData);
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final notificationData = NotificationData.fromMap(data);
      _onNotificationTap.add(notificationData);
      _navigateToChat(notificationData);
    } catch (_) {}
  }

  Future<void> _navigateToChat(NotificationData data) async {
    if (data.roomId.isEmpty && data.senderId.isEmpty) return;

    try {
      if (data.roomId.isNotEmpty && data.messageId != null && data.messageId!.isNotEmpty) {
        final messageId = data.messageId!;
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final firestoreService = FirestoreService();
          final msgDoc = await FirebaseFirestore.instance
              .collection('chat_rooms')
              .doc(data.roomId)
              .collection('messages')
              .doc(messageId)
              .get();
          if (msgDoc.exists) {
            final msgData = msgDoc.data() as Map<String, dynamic>;
            if (msgData['receiverId'] == user.uid && msgData['status'] == 'sent') {
              await firestoreService.updateMessageStatus(
                data.roomId,
                messageId,
                'delivered',
                setDeliveredAt: true,
              );
            }
          }
        }
      }
    } catch (_) {}

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    await navigator.pushNamedAndRemoveUntil('/home', (route) => route.isFirst);

    try {
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(data.senderId)
          .get();
      final senderData = senderDoc.data();
      final senderName = senderData?['name'] as String? ?? 'User';
      final senderPhotoUrl = senderData?['photoUrl'] as String?;

      if (navigator.mounted) {
        await navigator.pushNamed(
          '/chat',
          arguments: {
            'receiverId': data.senderId,
            'receiverName': senderName,
            'receiverPhotoUrl': senderPhotoUrl,
            'initialChatRoomId': data.roomId.isNotEmpty ? data.roomId : null,
          },
        );
      }
    } catch (_) {}
  }

  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    _currentToken = null;
  }

  Future<void> notifyBackend({
    required String senderId,
    required String receiverId,
    required String roomId,
    required String message,
    String messageType = 'text',
    String? messageId,
  }) async {
    if (_backendUrl == null || _backendUrl!.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      await http.post(
        Uri.parse('$_backendUrl/api/notifications/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'senderId': senderId,
          'receiverId': receiverId,
          'roomId': roomId,
          'message': message,
          'messageType': messageType,
          'messageId': messageId ?? '',
        }),
      );
    } catch (_) {}
  }

  void dispose() {
    _onNotificationTap.close();
  }
}
