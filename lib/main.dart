import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'routes/app_routes.dart';
import 'services/media_cleanup_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = message.data;
  final roomId = data['roomId'] as String? ?? data['chatRoomId'] as String?;
  final messageId = data['messageId'] as String?;
  final receiverId = data['receiverId'] as String?;
  if (roomId != null && messageId != null && receiverId != null) {
    try {
      final msgDoc = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .get();
      if (msgDoc.exists) {
        final msgData = msgDoc.data() as Map<String, dynamic>;
        if (msgData['receiverId'] == receiverId && msgData['status'] == 'sent') {
          await msgDoc.reference.update({
            'status': 'delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }
}

final PresenceService presenceService = PresenceService();
final MediaCleanupService mediaCleanupService = MediaCleanupService();
final NotificationService notificationService = NotificationService();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await notificationService.init(navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    presenceService.init();
    mediaCleanupService.startPeriodicCleanup();
  }

  @override
  void dispose() {
    presenceService.dispose();
    mediaCleanupService.stopCleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const _AppWithLifecycle(),
    );
  }
}

class _AppWithLifecycle extends StatefulWidget {
  const _AppWithLifecycle();

  @override
  State<_AppWithLifecycle> createState() => _AppWithLifecycleState();
}

class _AppWithLifecycleState extends State<_AppWithLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authProvider = context.read<AuthProvider>();
    if (state == AppLifecycleState.resumed) {
      presenceService.setOnline(true);
      authProvider.updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      presenceService.setOnline(false);
      authProvider.updateOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Conversations',
      theme: AppTheme.lightTheme,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
