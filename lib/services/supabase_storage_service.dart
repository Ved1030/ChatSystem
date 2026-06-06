import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';

class SupabaseStorageService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Uint8List> compressImage(String filePath, {int quality = SupabaseConstants.imageQuality}) async {
    final result = await FlutterImageCompress.compressWithFile(
      filePath,
      quality: quality,
      minWidth: SupabaseConstants.imageMaxDimension,
      minHeight: SupabaseConstants.imageMaxDimension,
    );
    return result ?? await File(filePath).readAsBytes();
  }

  void validateFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File does not exist');
    }

    final size = file.lengthSync();
    if (size > SupabaseConstants.maxFileSize) {
      throw Exception('File size exceeds 10 MB limit');
    }

    final extension = filePath.split('.').last.toLowerCase();
    if (!SupabaseConstants.allowedExtensions.contains(extension)) {
      throw Exception(
        'Invalid file type: $extension. Only jpg, jpeg, png, webp allowed.',
      );
    }
  }

  Future<String> _upload({
    required String bucket,
    required String path,
    required String filePath,
    int quality = SupabaseConstants.imageQuality,
  }) async {
    validateFile(filePath);

    final bytes = await compressImage(filePath, quality: quality);
    final extension = filePath.split('.').last.toLowerCase();
    final finalPath = extension == 'jpg' || extension == 'jpeg'
        ? '$path.jpg'
        : '$path.$extension';

    try {
      await _client.storage.from(bucket).uploadBinary(
            finalPath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$extension'),
          );
    } on StorageException catch (e) {
      if (e.message.contains('bucket')) {
        throw Exception(
          'Storage bucket "$bucket" does not exist. '
          'Run the supabase_setup.sql script in your Supabase SQL Editor to create it.',
        );
      }
      rethrow;
    }

    return _client.storage.from(bucket).getPublicUrl(finalPath);
  }

  Future<String> uploadProfilePhoto(String uid, String filePath) async {
    return _upload(
      bucket: SupabaseConstants.profileImagesBucket,
      path: uid,
      filePath: filePath,
      quality: 80,
    );
  }

  Future<String> uploadChatImage(
    String chatRoomId,
    String messageId,
    String filePath,
  ) async {
    return _upload(
      bucket: SupabaseConstants.chatImagesBucket,
      path: '$chatRoomId/$messageId',
      filePath: filePath,
      quality: 85,
    );
  }

  Future<String> uploadAlbumPhotoSupabase(
    String albumId,
    String photoId,
    String filePath,
  ) async {
    return _upload(
      bucket: SupabaseConstants.albumsBucket,
      path: '$albumId/$photoId',
      filePath: filePath,
      quality: 85,
    );
  }

  Future<String> uploadAlbumImage(
    String albumId,
    String photoId,
    String filePath,
  ) async {
    return uploadAlbumPhotoSupabase(albumId, photoId, filePath);
  }

  Future<String> uploadVoiceNote(
    String chatRoomId,
    String messageId,
    String filePath,
  ) async {
    final bytes = await File(filePath).readAsBytes();
    final path = '$chatRoomId/$messageId.m4a';

    await _client.storage.from(SupabaseConstants.voiceNotesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'audio/m4a'),
        );

    return _client.storage.from(SupabaseConstants.voiceNotesBucket).getPublicUrl(path);
  }

  Future<String> uploadVideo(
    String chatRoomId,
    String messageId,
    String filePath,
  ) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final extension = filePath.split('.').last.toLowerCase();
    final path = '$chatRoomId/$messageId.$extension';

    await _client.storage.from(SupabaseConstants.videosBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'video/$extension'),
        );

    return _client.storage.from(SupabaseConstants.videosBucket).getPublicUrl(path);
  }

  Future<String> uploadRawFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async {
    await _client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType),
        );

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {}
  }

  Future<void> deleteImage(String bucket, String path) async {
    await deleteFile(bucket, path);
  }

  Future<void> deleteExpiredImage(
    String bucket,
    String path,
  ) async {
    try {
      final files = await _client.storage.from(bucket).list(
            path: path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '',
          );
      final fileName = path.contains('/') ? path.split('/').last : path;
      final exists = files.any((f) => f.name == fileName);
      if (exists) {
        await _client.storage.from(bucket).remove([path]);
      }
    } catch (_) {}
  }

  String getPublicUrl(String bucket, String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}
