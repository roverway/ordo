import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

/// 把异步错误记录到日志（用户不可见；UI 只展示 ARB 文案，AGENTS.md §3-8）。
///
/// 各页面 `.when(error:)` 分支统一调用，异常堆栈仅进日志、不渲染到界面。
void logAsyncError(Object error, StackTrace? stackTrace) {
  developer.log(
    'AsyncValue error',
    name: 'AsyncValue',
    error: error,
    stackTrace: stackTrace,
  );
}

/// 统一错误态（50-ui-ux.md §6.3）：错误图标 + 文案 + 可选「重试」按钮。
///
/// 全页面 `.when(error:)` 分支统一使用本组件（M5 任务 1）。
/// - 文案走 ARB（[AppLocalizations.errorLoadFailed]），**不显示原始异常**；
/// - 配色用 `colorScheme.error` 图标 + `onSurfaceVariant` 正文；
/// - 「重试」按钮触控目标 ≥48dp（NFR-06），[onRetry] 为空则不渲染按钮。
///
/// 颜色/尺寸/间距一律使用 [AppTokens]/colorScheme，无魔法值。
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  /// 可选错误文案（ARB）；null 时用默认「加载失败」。
  final String? message;

  /// 重试回调（如 `ref.invalidate(provider)`）；null = 不显示重试按钮。
  final VoidCallback? onRetry;

  /// 紧凑形态：更小图标 + 横向排布（列表行内联错误，如抽屉项目组）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppTokens.errorIconSizeCompact,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: AppTokens.spaceXs),
            Flexible(
              child: Text(
                message ?? l10n.errorLoadFailed,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: AppTokens.spaceXs),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(l10n.retry),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppTokens.errorIconSize,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              message ?? l10n.errorLoadFailed,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTokens.spaceLg),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppTokens.touchTarget),
                ),
                icon: const Icon(
                  Icons.refresh,
                  size: AppTokens.expandArrowSize,
                ),
                label: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
