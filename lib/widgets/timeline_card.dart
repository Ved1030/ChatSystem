import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants/app_colors.dart';

class TimelineCard extends StatefulWidget {
  final String id;
  final String title;
  final String date;
  final String description;
  final IconData icon;
  final bool isFirst;
  final bool isLast;
  final int index;

  const TimelineCard({
    super.key,
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.icon,
    this.isFirst = false,
    this.isLast = false,
    this.index = 0,
  });

  @override
  State<TimelineCard> createState() => _TimelineCardState();
}

class _TimelineCardState extends State<TimelineCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Column(
              children: [
                if (!widget.isFirst)
                  Container(
                    width: 2,
                    height: 16,
                    color: AppColors.primary.withValues(alpha: 0.2),
                  )
                else
                  const SizedBox(height: 16),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 18),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 16),
              child: GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child:
                    Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _isExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.date,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedCrossFade(
                                firstChild: const SizedBox.shrink(),
                                secondChild: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    widget.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                crossFadeState: _isExpanded
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 300),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(
                          duration: 400.ms,
                          delay: (widget.index * 100).ms,
                        )
                        .slideX(
                          begin: 0.05,
                          duration: 400.ms,
                          delay: (widget.index * 100).ms,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
