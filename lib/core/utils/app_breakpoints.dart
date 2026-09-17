import 'package:flutter/widgets.dart';

/// 断点工具（30-architecture.md §5，50-ui-ux.md §4）。
///
/// 布局断点统一收敛于此，禁止在页面中散落宽度魔法值。
abstract final class AppBreakpoints {
  /// 导航断点（dp）：<600 使用底部 NavigationBar/单列，≥600 使用宽屏模式。
  static const double navigationBreakpoint = 600;

  /// 手册/复杂页面双栏分栏断点（dp）：≥900 使用目录+正文双栏，<900 使用浮动目录抽屉。
  static const double dualPaneBreakpoint = 900;

  /// 当前是否窄屏（<600dp）。
  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < navigationBreakpoint;

  /// 当前是否宽屏（≥600dp）。
  static bool isWide(BuildContext context) => !isNarrow(context);

  /// 当前是否双栏/大屏分栏（≥900dp）。
  static bool isDualPane(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= dualPaneBreakpoint;
}
