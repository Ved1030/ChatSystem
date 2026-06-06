import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String search = '/search';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String settings = '/settings';
  static const String notificationSettings = '/notification-settings';

  static Map<String, WidgetBuilder> routes = {
    splash: (_) => SplashScreen(),
    login: (_) => LoginScreen(),
    register: (_) => RegisterScreen(),
    home: (_) => HomeScreen(),
    search: (_) => SearchScreen(),
    profile: (_) => ProfileScreen(),
    editProfile: (_) => EditProfileScreen(),
    settings: (_) => SettingsScreen(),
    notificationSettings: (_) => NotificationSettingsScreen(),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case chat:
        final args = routeSettings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverId: args['receiverId'] as String,
            receiverName: args['receiverName'] as String,
            receiverPhotoUrl: args['receiverPhotoUrl'] as String?,
            initialChatRoomId: args['initialChatRoomId'] as String?,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
    }
  }
}
