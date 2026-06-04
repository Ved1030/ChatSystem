import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/presence_service.dart';

final PresenceService presenceService = PresenceService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
  }

  @override
  void dispose() {
    presenceService.dispose();
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
      debugShowCheckedModeBanner: false,
      title: 'Conversations',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
