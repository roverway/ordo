import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'app_frosted_container.dart';

/// 平台自适应对话框容器：限制最大宽度、最大高度、圆角、毛玻璃与内边距。
///
/// 视觉语言：
/// - 背景：全平台统一的毛玻璃半透明容器 [AppFrostedContainer]
/// - 边框：0.5dp 极细边界（深色高亮微光 / 浅色柔和收边）
/// - 阴影：柔和漫反射环境阴影
/// - 圆角：[AppTokens.radiusDialog]（20dp 连续平滑曲率）
class AppAdaptiveDialog extends StatelessWidget {
  const AppAdaptiveDialog({
    super.key,
    required this.child,
    this.maxWidth = AppTokens.dialogMaxWidth,
    this.maxHeight,
    this.padding = const EdgeInsets.all(AppTokens.spaceLg),
    this.borderRadius,
  });

  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(AppTokens.radiusDialog);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceMd,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: AppFrostedContainer(
          borderRadius: effectiveRadius,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// 呼出统一样式的毛玻璃对话框（Living Scrim + Silky Spring Transition）。
Future<T?> showAppAdaptiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    useRootNavigator: useRootNavigator,
    barrierColor: Colors.black.withValues(
      alpha: isDark ? AppTokens.alphaScrimDark : AppTokens.alphaScrimLight,
    ),
    transitionDuration: AppTokens.motionFast,
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        builder(dialogContext),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
