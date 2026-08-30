import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/utils/app_breakpoints.dart';

/// 自适应 AppBar Leading 导航组件（消除全应用 AppBar 前置按钮的模板代码重复）。
///
/// 行为逻辑：
/// 1. 当支持返回（路由可 pop 或提供了 [onBack] 回调）时：展示返回箭头按钮；
/// 2. 当无法返回、且处于窄屏（[AppBreakpoints.isNarrow]）、且启用了 [fallbackToDrawer] 时：
///    展示汉堡菜单（抽屉唤起）按钮；
/// 3. 其他情况（例如宽屏且不可 pop）：返回 null / 空占位。
class AdaptiveLeadingNavigation extends StatelessWidget {
  const AdaptiveLeadingNavigation({
    super.key,
    this.onBack,
    this.fallbackToDrawer = true,
  });

  /// 自定义返回操作；若为空则默认使用 `Navigator.of(context).pop()`。
  final VoidCallback? onBack;

  /// 当无法返回且处于窄屏时，是否回退为抽屉打开按钮（默认 true）。
  final bool fallbackToDrawer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canPop = (ModalRoute.of(context)?.canPop ?? false) || onBack != null;
    final isNarrow = AppBreakpoints.isNarrow(context);

    if (canPop) {
      return IconButton(
        tooltip: l10n.cancel,
        icon: const Icon(Icons.arrow_back, size: 22),
        onPressed: () {
          if (onBack != null) {
            onBack!();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      );
    }

    if (fallbackToDrawer && isNarrow) {
      return Builder(
        builder: (ctx) => IconButton(
          tooltip: l10n.openDrawer,
          icon: const Icon(Icons.menu, size: 22),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
