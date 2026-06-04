import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfilePhoto(String uid, String filePath) async {
    final ref = _storage.ref().child('profile_photos/$uid.jpg');
    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }

  Future<String> uploadAlbumCover(String albumId, String filePath) async {
    final ref = _storage.ref().child('albums/${albumId}_cover.jpg');
    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }

  Future<String> uploadAlbumPhoto(
    String albumId,
    String photoId,
    String filePath,
  ) async {
    final ref = _storage.ref().child('albums/$albumId/$photoId.jpg');
    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }

  Future<String> uploadChatWallpaper(String chatRoomId, String filePath) async {
    final ref = _storage.ref().child('chat_wallpapers/$chatRoomId.jpg');
    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }
}
