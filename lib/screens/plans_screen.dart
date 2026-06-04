import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/plan_model.dart';
import '../repositories/chat_repository.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final ChatRepository _chatRepository = ChatRepository();

  List<PlanModel> _plans = [];
  bool _loading = true;
  StreamSubscription? _plansSub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _plansSub?.cancel();
    super.dispose();
  }

  void _listen() {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    _plansSub = _chatRepository.plansStream(currentUid).listen((plans) {
      if (mounted) {
        setState(() {
          _plans = plans;
          _loading = false;
        });
      }
    });
  }

  List<PlanModel> _plansByCategory(PlanCategory category) {
    return _plans.where((p) => p.category == category).toList();
  }

  int get _planningCount =>
      _plans.where((p) => p.status == PlanStatus.planning).length;
  int get _doneCount => _plans.where((p) => p.status == PlanStatus.done).length;
  int get _cancelledCount =>
      _plans.where((p) => p.status == PlanStatus.cancelled).length;

  Future<void> _toggleStatus(PlanModel plan) async {
    if (plan.id == null) return;
    PlanStatus newStatus;
    switch (plan.status) {
      case PlanStatus.planning:
        newStatus = PlanStatus.done;
        break;
      case PlanStatus.done:
        newStatus = PlanStatus.cancelled;
        break;
      case PlanStatus.cancelled:
        newStatus = PlanStatus.planning;
        break;
    }
    await _chatRepository.updatePlan(plan.id!, {
      'status': _statusToString(newStatus),
    });
  }

  void _addPlan() {
    showDialog(context: context, builder: (ctx) => const _AddPlanDialog());
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
                  _buildStatsRow(),
                  Expanded(child: _buildCategories()),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPlan,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plans',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _StatChip(
            label: 'Planning',
            count: _planningCount,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _StatChip(label: 'Done', count: _doneCount, color: AppColors.success),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Cancelled',
            count: _cancelledCount,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.flag_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No plans yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start planning your next adventure',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        children: [
          _CategorySection(
            category: PlanCategory.travel,
            icon: Icons.flight_takeoff_rounded,
            label: 'Travel',
            plans: _plansByCategory(PlanCategory.travel),
            onToggle: _toggleStatus,
            colorIndex: 0,
          ),
          const SizedBox(height: 12),
          _CategorySection(
            category: PlanCategory.food,
            icon: Icons.restaurant_rounded,
            label: 'Food',
            plans: _plansByCategory(PlanCategory.food),
            onToggle: _toggleStatus,
            colorIndex: 1,
          ),
          const SizedBox(height: 12),
          _CategorySection(
            category: PlanCategory.adventure,
            icon: Icons.explore_rounded,
            label: 'Adventure',
            plans: _plansByCategory(PlanCategory.adventure),
            onToggle: _toggleStatus,
            colorIndex: 2,
          ),
          const SizedBox(height: 12),
          _CategorySection(
            category: PlanCategory.movies,
            icon: Icons.movie_rounded,
            label: 'Movies',
            plans: _plansByCategory(PlanCategory.movies),
            onToggle: _toggleStatus,
            colorIndex: 3,
          ),
        ],
      ),
    );
  }

  String _statusToString(PlanStatus status) {
    switch (status) {
      case PlanStatus.done:
        return 'done';
      case PlanStatus.cancelled:
        return 'cancelled';
      case PlanStatus.planning:
        return 'planning';
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final PlanCategory category;
  final IconData icon;
  final String label;
  final List<PlanModel> plans;
  final Future<void> Function(PlanModel plan) onToggle;
  final int colorIndex;

  const _CategorySection({
    required this.category,
    required this.icon,
    required this.label,
    required this.plans,
    required this.onToggle,
    required this.colorIndex,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        AppColors.albumColors[colorIndex % AppColors.albumColors.length];

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${plans.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (plans.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...plans.map(
              (plan) => _PlanItem(plan: plan, onTap: () => onToggle(plan)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanItem extends StatelessWidget {
  final PlanModel plan;
  final VoidCallback onTap;

  const _PlanItem({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (plan.status) {
      case PlanStatus.done:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Done';
        break;
      case PlanStatus.cancelled:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Cancelled';
        break;
      case PlanStatus.planning:
        statusColor = AppColors.primary;
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'Planning';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: plan.status == PlanStatus.cancelled
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration: plan.status == PlanStatus.cancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPlanDialog extends StatefulWidget {
  const _AddPlanDialog();

  @override
  State<_AddPlanDialog> createState() => _AddPlanDialogState();
}

class _AddPlanDialogState extends State<_AddPlanDialog> {
  final _titleController = TextEditingController();
  PlanCategory _category = PlanCategory.travel;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plan title')),
      );
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final chatRepo = ChatRepository();

    try {
      final rooms = await chatRepo.chatRoomsStream(currentUid).first;
      final otherUid = rooms.isNotEmpty
          ? rooms.first.participants.firstWhere((id) => id != currentUid)
          : '';

      final plan = PlanModel(
        participants: otherUid.isNotEmpty
            ? [currentUid, otherUid]
            : [currentUid],
        creatorId: currentUid,
        title: title,
        category: _category,
        status: PlanStatus.planning,
        createdAt: DateTime.now(),
      );

      await chatRepo.addPlan(plan);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add plan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'New Plan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'What do you want to do?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: PlanCategory.values.map((cat) {
                final isSelected = _category == cat;
                final label = _categoryLabel(cat);
                final icon = _categoryIcon(cat);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Add Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(PlanCategory cat) {
    switch (cat) {
      case PlanCategory.travel:
        return 'Travel';
      case PlanCategory.food:
        return 'Food';
      case PlanCategory.adventure:
        return 'Adventure';
      case PlanCategory.movies:
        return 'Movies';
    }
  }

  IconData _categoryIcon(PlanCategory cat) {
    switch (cat) {
      case PlanCategory.travel:
        return Icons.flight_takeoff_rounded;
      case PlanCategory.food:
        return Icons.restaurant_rounded;
      case PlanCategory.adventure:
        return Icons.explore_rounded;
      case PlanCategory.movies:
        return Icons.movie_rounded;
    }
  }
}
