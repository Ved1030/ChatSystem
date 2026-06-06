import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class TypingService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Timer? _typingTimer;
  String? _currentRoomId;
  String? _currentUserId;
  Duration _timeout = const Duration(seconds: 3);

  void setTypingTimeout(Duration duration) {
    _timeout = duration;
  }

  void startTyping(String roomId, String userId) {
    _currentRoomId = roomId;
    _currentUserId = userId;
    final ref = _database.ref('typing/$roomId/$userId');
    ref.onDisconnect().set(false);
    ref.set(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(_timeout, () {
      _setTypingStatus(roomId, userId, false);
    });
  }

  void stopTyping(String roomId, String userId) {
    _typingTimer?.cancel();
    _setTypingStatus(roomId, userId, false);
  }

  void _setTypingStatus(String roomId, String userId, bool isTyping) {
    final ref = _database.ref('typing/$roomId/$userId');
    if (!isTyping) {
      ref.onDisconnect().cancel();
    }
    ref.set(isTyping);
  }

  Stream<bool> typingStream(String roomId, String otherUserId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _database
        .ref('typing/$roomId/$otherUserId')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value is bool) return value;
          return false;
        })
        .distinct();
  }

  void dispose() {
    if (_currentRoomId != null && _currentUserId != null) {
      _setTypingStatus(_currentRoomId!, _currentUserId!, false);
    }
    _typingTimer?.cancel();
  }
}
