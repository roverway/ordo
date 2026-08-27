import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Empty state widget v2: tinted icon backdrop + message + optional
/// description + optional action button.
///
/// Used across all feature pages. All text must come from ARB
/// (AGENTS.md §3-8). Calendar agenda keeps its own richer empty state
/// and is not forced through this widget.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.description,
    this.action,
  });

  /// Icon displayed inside the soft primary-tinted backdrop circle.
  final IconData icon;

  /// Primary message text (from ARB).
  final String message;

  /// Optional secondary description line (from ARB).
  final String? description;

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
            Container(
              width: AppTokens.emptyBackdropSize,
              height: AppTokens.emptyBackdropSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(
                  alpha: AppTokens.alphaTintSoft,
                ),
              ),
              child: Icon(
                icon,
                size: AppTokens.emptyBackdropIconSize,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: AppTokens.spaceLg),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              SizedBox(height: AppTokens.spaceXxs),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: AppTokens.textCaptionHeight,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
