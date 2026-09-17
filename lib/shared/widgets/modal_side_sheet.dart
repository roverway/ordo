import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

/// 在宽屏（≥600dp）下以右侧浮动抽屉（Side Sheet）形式展示模态内容（通用公共组件）。
///
/// 特性：
/// - 底层主界面 100% 清晰可见，覆盖 25% 半透明暗色遮罩；
/// - 指定宽度（默认 [AppTokens.sideSheetWidth] = 480dp / 编辑器 [AppTokens.sideSheetEditorWidth] = 520dp）从屏幕右侧平滑滑出，带 16dp 阴影；
/// - 点击左侧遮罩区域或按 ESC / 返回一键收起；
/// - 支持自定义返回泛型值。
Future<T?> showModalSideSheet<T>({
  required BuildContext context,
  required Widget child,
  double width = AppTokens.sideSheetWidth,
  Color? barrierColor,
  bool barrierDismissible = true,
  Duration transitionDuration = AppTokens.motionNormal,
}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: l10n.cancel,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: AppTokens.alphaBorderEmphasis),
    transitionDuration: transitionDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: Material(
            elevation: 16,
            color: theme.scaffoldBackgroundColor,
            child: ScaffoldMessenger(child: child),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
  );
}
