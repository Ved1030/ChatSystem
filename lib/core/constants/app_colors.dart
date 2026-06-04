import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF8B7CF6);
  static const Color secondary = Color(0xFFDCCFFB);
  static const Color background = Color(0xFFF8F7F4);
  static const Color surface = Color(0xFFF4F2EC);
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF9C9A92);
  static const Color success = Color(0xFF8B7CF6);
  static const Color error = Color(0xFFE87373);
  static const Color online = Color(0xFF7BC67E);
  static const Color border = Color(0xFFE8E6DE);
  static const Color shimmer = Color(0xFFE8E6DE);
  static const Color cardOverlay = Color(0x1A8B7CF6);
  static const Color navBg = Color(0xE6F4F2EC);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFFA99BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<Color> albumColors = [
    Color(0xFF8B7CF6),
    Color(0xFFDCCFFB),
    Color(0xFFF0B5B5),
    Color(0xFFB5E2D4),
    Color(0xFFF5E6B8),
    Color(0xFFC4B5F0),
  ];
}
