import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final String _appId = '2d827c01-a2bd-47fb-a9f0-36744e68a51d';

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isInitialized = false;

  final StreamController<NotificationData> _onNotificationTap =
      StreamController<NotificationData>.broadcast();

  Stream<NotificationData> get onNotificationTap => _onNotificationTap.stream;

  String? get oneSignalId => OneSignal.User.pushSubscription.id;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (_isInitialized) return;
    _navigatorKey = navigatorKey;

    await OneSignal.initialize(_appId);
    _setupListeners();
    _isInitialized = true;
  }

  Future<bool> requestNotificationPermission() async {
    return OneSignal.Notifications.requestPermission(true);
  }

  void _setupListeners() {
    OneSignal.Notifications.addClickListener(_handleNotificationTap);
    OneSignal.Notifications.addForegroundWillDisplayListener(
      _handleForegroundDisplay,
    );
  }

  void _handleNotificationTap(OSNotificationClickEvent event) {
    final data = event.notification.additionalData ?? {};
    if (data.isNotEmpty) {
      final notificationData = NotificationData.fromMap(
        data.cast<String, dynamic>(),
      );
      _onNotificationTap.add(notificationData);
      _navigateToChat(notificationData);
    }
  }

  void _handleForegroundDisplay(OSNotificationWillDisplayEvent event) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final notificationsEnabled =
              userData['notificationsEnabled'] as bool? ?? true;
          if (!notificationsEnabled) {
            event.preventDefault();
            return;
          }
        }

        final data = event.notification.additionalData;
        if (data != null) {
          final roomId =
              data['roomId'] as String? ?? data['chatRoomId'] as String?;
          if (roomId != null && roomId.isNotEmpty) {
            final roomDoc = await FirebaseFirestore.instance
                .collection('chat_rooms')
                .doc(roomId)
                .get();
            if (roomDoc.exists) {
              final roomData = roomDoc.data()!;
              final mutedBy =
                  List<String>.from(roomData['mutedBy'] as List? ?? []);
              if (mutedBy.contains(user.uid)) {
                event.preventDefault();
                return;
              }
              final mutedUntil =
                  roomData['mutedUntil'] as Map<String, dynamic>? ?? {};
              final untilTimestamp = mutedUntil[user.uid];
              if (untilTimestamp != null) {
                final until = (untilTimestamp as Timestamp).toDate();
                if (until.isAfter(DateTime.now())) {
                  event.preventDefault();
                  return;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    event.notification.display();
  }

  Future<void> login(String uid) async {
    OneSignal.login(uid);
    await _saveOneSignalId(uid);
  }

  Future<void> _saveOneSignalId(String uid) async {
    String? id = oneSignalId;
    for (int i = 0; i < 25 && id == null; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      id = oneSignalId;
    }
    if (id != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'oneSignalId': id}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'oneSignalId': null});
      }
    } catch (_) {}
    OneSignal.logout();
  }

  Future<void> _navigateToChat(NotificationData data) async {
    if (data.roomId.isEmpty && data.senderId.isEmpty) return;

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

  void dispose() {
    _onNotificationTap.close();
  }
}
