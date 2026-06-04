import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

class PresenceService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirestoreService _firestoreService = FirestoreService();

  DatabaseReference? _userStatusRef;
  DatabaseReference? _connectionsRef;

  void init() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userStatusRef = _database.ref('status/${user.uid}');
    _connectionsRef = _database.ref('.info/connected');

    _connectionsRef!.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (!connected) return;

      _userStatusRef!.onDisconnect().update({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      });

      _userStatusRef!.update({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      _firestoreService.updateOnlineStatus(user.uid, true);
    });
  }

  Future<void> setOnline(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_userStatusRef == null) {
      _userStatusRef = _database.ref('status/${user.uid}');
    }

    await _userStatusRef!.update({
      'isOnline': isOnline,
      'lastSeen': ServerValue.timestamp,
    });

    await _firestoreService.updateOnlineStatus(user.uid, isOnline);
  }

  void dispose() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _userStatusRef == null) return;

    _userStatusRef!.update({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });

    _firestoreService.updateOnlineStatus(user.uid, false);
  }
}
