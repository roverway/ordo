import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Empty state widget: icon + message + optional action button.
///
/// Used across all feature pages. Design: generous spacing, subtle icon,
/// clean typography. All text must come from ARB (AGENTS.md §3-8).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  /// Icon to display above the message.
  final IconData icon;

  /// Message text (from ARB).
  final String message;

  /// Optional primary action button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppTokens.emptyIconSize,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            SizedBox(height: AppTokens.spaceMd),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              SizedBox(height: AppTokens.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
