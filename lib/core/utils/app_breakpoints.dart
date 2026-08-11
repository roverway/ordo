import 'package:flutter/widgets.dart';

/// 断点工具（30-architecture.md §5，50-ui-ux.md §4）。
///
/// 布局断点统一收敛于此，禁止在页面中散落宽度魔法值。
abstract final class AppBreakpoints {
  /// 导航断点（dp）：<600 使用底部 NavigationBar，≥600 使用 NavigationRail。
  static const double navigationBreakpoint = 600;

  /// 当前是否窄屏（<600dp）。
  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < navigationBreakpoint;

  /// 当前是否宽屏（≥600dp）。
  static bool isWide(BuildContext context) => !isNarrow(context);
}
