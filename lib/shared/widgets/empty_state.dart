import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 空态组件（50-ui-ux.md §6.3）：图标 + 文案 + 可选主操作按钮。
///
/// 文案由调用方传入（必须来自 ARB，AGENTS.md §3-8）。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  /// 空态主图标。
  final IconData icon;

  /// 空态文案（ARB）。
  final String message;

  /// 可选主操作按钮（如「新建任务」）。
  final Widget? action;

  /// 空态主图标尺寸：48dp = spaceXxl × 2（由间距令牌推导，避免魔法值）。
  static const double _iconSize = AppTokens.spaceXxl * 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _iconSize, color: theme.colorScheme.outline),
            SizedBox(height: AppTokens.spaceMd),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
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
