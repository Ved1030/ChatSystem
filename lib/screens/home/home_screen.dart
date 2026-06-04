import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../chats_tab.dart';
import '../memories_screen.dart';
import '../plans_screen.dart';
import '../timeline_screen.dart';
import '../us_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  final List<Widget> _tabs = const [
    ChatsTab(),
    MemoriesScreen(),
    TimelineScreen(),
    PlansScreen(),
    UsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(index: _currentTab, children: _tabs),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: CustomBottomNav(
              currentIndex: _currentTab,
              onTap: (index) => setState(() => _currentTab = index),
            ),
          ),
        ],
      ),
    );
  }
}
