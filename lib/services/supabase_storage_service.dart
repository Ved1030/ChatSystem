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

  Future<Uint8List> compressAlbumImage(String filePath, {int quality = 85}) async {
    return compressImage(filePath, quality: quality);
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
            fileOptions: FileOptions(
              contentType: 'image/$extension',
              upsert: true,
            ),
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

  Future<String> _uploadBinary({
    required String bucket,
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async {
    await _client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<String> uploadVoiceNote(
    String chatRoomId,
    String messageId,
    String filePath,
  ) async {
    final bytes = await File(filePath).readAsBytes();
    final path = '$chatRoomId/$messageId.m4a';

    return _uploadBinary(
      bucket: SupabaseConstants.voiceNotesBucket,
      path: path,
      bytes: bytes,
      contentType: 'audio/m4a',
    );
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

    return _uploadBinary(
      bucket: SupabaseConstants.videosBucket,
      path: path,
      bytes: bytes,
      contentType: 'video/$extension',
    );
  }

  Future<String> uploadRawFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async {
    return _uploadBinary(
      bucket: bucket,
      path: path,
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {}
  }

  Future<void> deleteImage(String bucket, String path) async {
    await deleteFile(bucket, path);
  }

  Future<void> deleteAlbumImage(String albumId, String photoId) async {
    final bucket = SupabaseConstants.albumsBucket;
    final path = '$albumId/$photoId';
    try {
      final files = await _client.storage.from(bucket).list(path: albumId);
      final matching = files.where((f) => f.name.startsWith(photoId));
      if (matching.isNotEmpty) {
        final fullPath = '$albumId/${matching.first.name}';
        await _client.storage.from(bucket).remove([fullPath]);
      }
    } catch (_) {}
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

  Future<void> deleteFolder(String bucket, String folderPath) async {
    try {
      final files = await _client.storage.from(bucket).list(path: folderPath);
      if (files.isEmpty) return;

      final paths = files
          .where((f) => f.name.isNotEmpty)
          .map((f) => '$folderPath/${f.name}')
          .toList();

      if (paths.isNotEmpty) {
        await _client.storage.from(bucket).remove(paths);
      }
    } catch (_) {}
  }

  Future<void> deleteAlbumFolder(String albumId) async {
    await deleteFolder(SupabaseConstants.albumsBucket, albumId);
  }

  String? extractStoragePath(String publicUrl, String bucket) {
    final prefix = '/public/$bucket/';
    final index = publicUrl.indexOf(prefix);
    if (index == -1) return null;
    return publicUrl.substring(index + prefix.length);
  }

  String? extractAlbumImagePath(String publicUrl) {
    return extractStoragePath(publicUrl, SupabaseConstants.albumsBucket);
  }

  String getPublicUrl(String bucket, String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  String getAlbumImageUrl(String albumId, String photoId) {
    return getPublicUrl(SupabaseConstants.albumsBucket, '$albumId/$photoId');
  }
}
