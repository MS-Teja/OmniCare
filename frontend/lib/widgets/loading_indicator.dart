import 'package:flutter/material.dart';
import '../theme/omnicare_theme.dart';

/// A warm, non-clinical loading indicator.
///
/// Shows a soft pulsing animation with a friendly message
/// instead of a cold spinning wheel.
class LoadingIndicator extends StatefulWidget {
  final String message;

  const LoadingIndicator({
    super.key,
    this.message = 'One moment...',
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _animation,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: OmniCareTheme.emerald,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniCareTheme.slate500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
