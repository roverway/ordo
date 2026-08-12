import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

/// 统一加载态（50-ui-ux.md §6.3）：居中 spinner + 可选文案。
///
/// 全页面 `.when(loading:)` 分支统一使用本组件（M5 任务 1），
/// 文案走 ARB（[AppLocalizations.loading]），颜色/尺寸/间距走
/// [AppTokens]/colorScheme，无魔法值（AGENTS.md §3-9）。
///
/// - [compact]：紧凑形态（列表行内/抽屉内联加载），更小的指示器。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.compact = false});

  /// 可选加载文案（ARB）；null 时仅显示 spinner。
  final String? message;

  /// 紧凑形态：更小指示器 + 更紧间距。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = compact
        ? AppTokens.loadingIndicatorSizeCompact
        : AppTokens.loadingIndicatorSize;

    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: AppTokens.loadingStrokeWidth,
      ),
    );

    final content = message == null
        ? spinner
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              spinner,
              SizedBox(height: compact ? AppTokens.spaceXs : AppTokens.spaceMd),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? AppTokens.spaceSm : AppTokens.spaceXl,
        ),
        child: content,
      ),
    );
  }
}
