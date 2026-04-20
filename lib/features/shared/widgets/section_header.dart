import 'package:flutter/material.dart';
import 'package:uso_id/core/theme/app_theme.dart';

/// A styled section heading used across all feature screens.
///
/// Usage:
/// ```dart
/// SectionHeader(title: 'My Units')
/// SectionHeader(title: 'Recent Sessions', action: TextButton(...))
/// ```
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
