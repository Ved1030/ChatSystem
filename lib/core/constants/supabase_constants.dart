class SupabaseConstants {
  static const String profileImagesBucket = 'profile-images';
  static const String chatImagesBucket = 'chat-images';
  static const String albumsBucket = 'albums';
  static const String voiceNotesBucket = 'voice-notes';
  static const String videosBucket = 'videos';

  static const int maxFileSize = 10 * 1024 * 1024;
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static const int imageQuality = 80;
  static const int imageMaxDimension = 1920;
  static const int temporaryExpiryHours = 36;
}
