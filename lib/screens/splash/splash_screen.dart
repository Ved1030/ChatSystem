import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Conversations',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your private companion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
