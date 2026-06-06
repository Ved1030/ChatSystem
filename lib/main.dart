import 'package:firebase_core/firebase_core.dart';
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

final PresenceService presenceService = PresenceService();
final MediaCleanupService mediaCleanupService = MediaCleanupService();
final NotificationService notificationService = NotificationService();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  debugPrint('[STARTUP] Firebase apps count before init: ${Firebase.apps.length}');

  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('[STARTUP] Firebase initialized successfully');
    } catch (e, s) {
      debugPrint('[STARTUP] Firebase init error: $e');
      debugPrint('[STARTUP] Firebase init stack trace: $s');
    }
  } else {
    debugPrint('[STARTUP] Firebase app already exists in Dart context');
  }

  debugPrint('[STARTUP] Firebase apps count after init: ${Firebase.apps.length}');

  debugPrint('[STARTUP] Supabase initialization start');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  debugPrint('[STARTUP] Supabase initialization end');

  debugPrint('[STARTUP] OneSignal initialization start');
  await notificationService.init(navigatorKey);
  debugPrint('[STARTUP] OneSignal initialization end');

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
