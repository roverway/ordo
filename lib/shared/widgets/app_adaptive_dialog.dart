import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 统一响应式/居中弹窗基础容器。
///
/// 特性：
/// - 统一圆角（[AppTokens.radiusDialog] = 20）；
/// - 统一内边距裕量（[AppTokens.spaceLg] 水平 / [AppTokens.spaceMd] 垂直），防止小屏键盘弹出溢出；
/// - 统一最大宽度约束（默认 [AppTokens.dialogMaxWidth] = 440dp）。
class AppAdaptiveDialog extends StatelessWidget {
  const AppAdaptiveDialog({
    super.key,
    required this.child,
    this.maxWidth = AppTokens.dialogMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceMd,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
