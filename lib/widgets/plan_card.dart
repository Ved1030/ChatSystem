import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants/app_colors.dart';

enum PlanPriority { low, medium, high }

class PlanCard extends StatelessWidget {
  final String id;
  final String title;
  final String deadline;
  final PlanPriority priority;
  final bool completed;
  final double progress;
  final VoidCallback? onToggle;
  final int index;

  const PlanCard({
    super.key,
    required this.id,
    required this.title,
    required this.deadline,
    this.priority = PlanPriority.medium,
    this.completed = false,
    this.progress = 0.0,
    this.onToggle,
    this.index = 0,
  });

  Color get _priorityColor {
    switch (priority) {
      case PlanPriority.high:
        return AppColors.error;
      case PlanPriority.medium:
        return AppColors.secondary;
      case PlanPriority.low:
        return AppColors.success;
    }
  }

  String get _priorityLabel {
    switch (priority) {
      case PlanPriority.high:
        return 'High Priority';
      case PlanPriority.medium:
        return 'Medium Priority';
      case PlanPriority.low:
        return 'Low Priority';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child:
          Container(
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
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: onToggle,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: completed
                                    ? AppColors.success
                                    : Colors.transparent,
                                border: Border.all(
                                  color: completed
                                      ? AppColors.success
                                      : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: completed
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _priorityColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _priorityLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: _priorityColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 12,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      deadline,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: completed
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                    decoration: completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (progress > 0 && !completed) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: AppColors.border,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppColors.primary,
                                          ),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: completed ? 1.0 : 0.0,
                            child: const Icon(
                              Icons.celebration_rounded,
                              color: AppColors.secondary,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: (index * 80).ms)
              .slideX(begin: 0.05, duration: 400.ms, delay: (index * 80).ms),
    );
  }
}
