import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants/app_colors.dart';
import '../models/album_model.dart';
import '../repositories/chat_repository.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ChatRepository _chatRepository = ChatRepository();
  List<AlbumModel> _albums = [];
  bool _loading = true;
  StreamSubscription? _albumsSub;

  late DateTime _selectedDate;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _currentMonth = DateTime(now.year, now.month, 1);
    _listen();
  }

  @override
  void dispose() {
    _albumsSub?.cancel();
    super.dispose();
  }

  void _listen() {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    _albumsSub = _chatRepository.albumsStream(currentUid).listen((albums) {
      if (mounted) {
        setState(() {
          _albums = albums;
          _loading = false;
        });
      }
    });
  }

  List<AlbumModel> get _selectedDateAlbums {
    return _albums.where((a) {
      return a.createdAt.year == _selectedDate.year &&
          a.createdAt.month == _selectedDate.month &&
          a.createdAt.day == _selectedDate.day;
    }).toList();
  }

  bool _hasAlbumOnDay(DateTime day) {
    return _albums.any((a) {
      return a.createdAt.year == day.year &&
          a.createdAt.month == day.month &&
          a.createdAt.day == day.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildCalendar(),
                  Expanded(child: _buildSelectedDay()),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 38),
            child: Text(
              'Our memories in time',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              Text(
                '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                      1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdayLabels.map((label) {
              return SizedBox(
                width: 36,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(((firstWeekday + daysInMonth) / 7).ceil(), (
            weekIndex,
          ) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (dayIndex) {
                  final dayNum = weekIndex * 7 + dayIndex - firstWeekday + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox(width: 36, height: 36);
                  }

                  final date = DateTime(
                    _currentMonth.year,
                    _currentMonth.month,
                    dayNum,
                  );
                  final isSelected =
                      date.day == _selectedDate.day &&
                      date.month == _selectedDate.month &&
                      date.year == _selectedDate.year;
                  final hasAlbum = _hasAlbumOnDay(date);

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = date);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (hasAlbum && !isSelected)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSelectedDay() {
    final albums = _selectedDateAlbums;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (albums.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No memories on this day',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: albums.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return _DayAlbumCard(album: album, index: index);
                },
              ),
            ),
        ],
      ),
    );
  }

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdayLabels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];
}

class _DayAlbumCard extends StatelessWidget {
  final AlbumModel album;
  final int index;

  const _DayAlbumCard({required this.album, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.albumColors[index % AppColors.albumColors.length];

    return Container(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${album.photoCount} ${album.photoCount == 1 ? 'photo' : 'photos'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (album.isPrivate)
                const Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 80).ms)
        .slideX(begin: 0.03, duration: 300.ms, delay: (index * 80).ms);
  }
}
