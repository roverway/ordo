import 'package:flutter/material.dart';

import '../../core/utils/app_breakpoints.dart';
import 'app_background_wrapper.dart';
import 'app_drawer.dart';

/// 全局根导航外壳。
///
/// 响应式双模架构：
/// - 窄屏/移动端（< 600dp）：纯净单屏直通，不加载侧边栏，由顶栏标题呼起 ScopeSwitcherSheet；
/// - 宽屏/桌面端（>= 600dp）：常驻左侧导航栏（AppSidebar，复用 ScopeNavContent），右侧为页面主体。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  /// Page body content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isNarrow(context)) {
      return AppBackgroundWrapper(child: child);
    }

    return AppBackgroundWrapper(
      child: Row(
        children: [
          const AppSidebar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
