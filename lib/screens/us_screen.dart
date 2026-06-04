import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants/app_colors.dart';
import '../models/user_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/user_repository.dart';
import '../widgets/stat_card.dart';
import 'shared_journal_screen.dart';

class UsScreen extends StatefulWidget {
  const UsScreen({super.key});

  @override
  State<UsScreen> createState() => _UsScreenState();
}

class _UsScreenState extends State<UsScreen> {
  final ChatRepository _chatRepository = ChatRepository();
  final UserRepository _userRepository = UserRepository();

  UserModel? _otherUser;
  UserModel? _currentUser;
  int _messageCount = 0;
  int _albumCount = 0;
  bool _loading = true;
  StreamSubscription? _albumsSub;
  StreamSubscription? _messagesSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _albumsSub?.cancel();
    _messagesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    _currentUser = await _userRepository.getUser(currentUid);

    final rooms = await _chatRepository.chatRoomsStream(currentUid).first;
    String? otherUid;
    String? chatRoomId;
    if (rooms.isNotEmpty) {
      final room = rooms.first;
      chatRoomId = room.id;
      otherUid = room.participants.firstWhere((id) => id != currentUid);
      _otherUser = await _userRepository.getUser(otherUid);
    }

    if (otherUid != null && chatRoomId != null) {
      _messagesSub = _chatRepository
          .messagesStream(chatRoomId, currentUid)
          .listen((messages) {
            if (mounted) {
              setState(() => _messageCount = messages.length);
            }
          });
    }

    _albumsSub = _chatRepository.albumsStream(currentUid).listen((albums) {
      if (mounted) {
        setState(() {
          _albumCount = albums.length;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    _buildConnectionBanner(),
                    _buildStats(),
                    _buildQuickLinks(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final currentName = _currentUser?.name ?? '';
    final otherName = _otherUser?.name ?? 'Them';
    final currentInitial = currentName.isNotEmpty ? currentName[0] : 'U';
    final otherInitial = otherName.isNotEmpty ? otherName[0] : 'T';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Us',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ProfileCircle(
                    initial: currentInitial,
                    color: AppColors.primary,
                    name: currentName.isNotEmpty
                        ? currentName.split(' ').first
                        : 'You',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ProfileCircle(
                    initial: otherInitial,
                    color: AppColors.secondary,
                    name: otherName.split(' ').first,
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.8, 0.8), duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    final joinedDate = _currentUser?.createdAt;
    final daysSince = joinedDate != null
        ? DateTime.now().difference(joinedDate).inDays
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child:
          Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '$daysSince',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      daysSince == 1 ? 'Day Connected' : 'Days Connected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (joinedDate != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Since ${joinedDate.month}/${joinedDate.day}/${joinedDate.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(begin: 0.1, duration: 400.ms, delay: 200.ms),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  value: _formatCount(_messageCount),
                  label: 'Messages Sent',
                  icon: Icons.chat_bubble_rounded,
                  color: AppColors.primary,
                  index: 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  value: _formatCount(_albumCount),
                  label: 'Albums',
                  icon: Icons.photo_library_rounded,
                  color: AppColors.secondary,
                  index: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  value: '0',
                  label: 'Plans Completed',
                  icon: Icons.flag_rounded,
                  color: AppColors.success,
                  index: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  value:
                      '${_currentUser?.createdAt != null ? DateTime.now().difference(_currentUser!.createdAt!).inDays : 0}',
                  label: 'Days Connected',
                  icon: Icons.favorite_rounded,
                  color: AppColors.error,
                  index: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Our Space',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.menu_book_rounded,
                  label: 'Shared Journal',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SharedJournalScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Wishlist',
                  color: AppColors.success,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.psychology_rounded,
                  label: 'Daily Question',
                  color: AppColors.error,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickLinkCard(
                  icon: Icons.favorite_rounded,
                  label: 'Anniversary',
                  color: AppColors.secondary,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _ProfileCircle extends StatelessWidget {
  final String initial;
  final Color color;
  final String name;

  const _ProfileCircle({
    required this.initial,
    required this.color,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
