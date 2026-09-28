import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Linear 风格快捷 Prompt 胶囊组件。
///
/// 具备圆角药丸轮廓（[AppTokens.radiusPill]）、微光边框与轻柔按压动效。
class AiPromptCapsule extends StatelessWidget {
  const AiPromptCapsule({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  /// 胶囊提示文案
  final String label;

  /// 前置装饰图标（可选）
  final IconData? icon;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    final backgroundColor = isDark
        ? AppTokens.surfaceCardDark
        : AppTokens.surfaceSubtleLight;

    final foregroundColor = isDark
        ? AppTokens.textPrimaryDark
        : AppTokens.textPrimaryLight;

    final iconColor = isDark
        ? AppTokens.textMutedDark
        : AppTokens.textMutedLight;

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceSm,
            vertical: AppTokens.spaceXs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppTokens.expandArrowSizeRow,
                  color: iconColor,
                ),
                const SizedBox(width: AppTokens.spaceXxs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTokens.textFootnoteSize,
                  fontWeight: AppTokens.textFootnoteWeight,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
