import 'package:flutter/material.dart';
import '../theme/omnicare_theme.dart';

/// A large, accessible button for primary and secondary actions.
///
/// All buttons are minimum 56dp tall for elderly-friendly touch targets.
class OmniCareButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final IconData? icon;

  const OmniCareButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary ? Colors.white : OmniCareTheme.emerald,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(icon, size: 22),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            isLoading ? 'One moment...' : label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (isPrimary) {
      return ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      child: child,
    );
  }
}
