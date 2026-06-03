import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  @override
  void dispose() {
    try {
      context.read<AuthProvider>().removeListener(_onAuthLoaded);
    } catch (_) {}
    super.dispose();
  }

  void _checkAuth() {
    try {
      final authProvider = context.read<AuthProvider>();

      if (authProvider.isLoading) {
        authProvider.addListener(_onAuthLoaded);
      } else {
        _navigate(authProvider.isAuthenticated);
      }
    } catch (e) {
      if (mounted) {
        _navigate(false);
      }
    }
  }

  void _onAuthLoaded() {
    try {
      final authProvider = context.read<AuthProvider>();
      if (!authProvider.isLoading) {
        authProvider.removeListener(_onAuthLoaded);
        if (mounted) {
          _navigate(authProvider.isAuthenticated);
        }
      }
    } catch (e) {
      if (mounted) {
        _navigate(false);
      }
    }
  }

  void _navigate(bool isAuthenticated) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isAuthenticated ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.green.shade100,
              child: const Icon(
                Icons.chat,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chat App',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.green),
          ],
        ),
      ),
    );
  }
}
