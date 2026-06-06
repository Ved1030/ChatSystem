import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class TypingIndicator extends StatefulWidget {
  final String userName;
  final bool isTyping;

  const TypingIndicator({
    super.key,
    required this.userName,
    required this.isTyping,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isTyping) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTyping && !oldWidget.isTyping) {
      _controller.repeat();
    } else if (!widget.isTyping && oldWidget.isTyping) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTyping) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.userName} is typing',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.online,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(3, (index) {
          return _TypingDot(
            listenable: _controller,
            index: index,
          );
        }),
      ],
    );
  }
}

class _TypingDot extends AnimatedWidget {
  final int index;

  const _TypingDot({
    required super.listenable,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final controller = listenable as AnimationController;
    final delay = index * 200;
    final cycleMs = (controller.value * 1200 - delay) % 600;
    final t = (cycleMs / 600).clamp(0.0, 1.0);
    final opacity = 0.3 + (0.7 * t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.online.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}