import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import 'app_drawer.dart';

/// Adaptive navigation shell (30-architecture.md §5, 55-ui-redesign §3)。
///
/// - Narrow (<600dp): 纯净无底栏（由抽屉侧边栏统一承载全部导航：系统组 + 项目分组 + 设置）
/// - Wide (≥600dp): 全高 AppSidebar（全桌面端固定常驻完整侧边栏）+ 右侧主内容区
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  /// Page body content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final narrow = AppBreakpoints.isNarrow(context);

    if (narrow) {
      return child;
    }

    // 宽屏模式（≥600dp）：ShellRoute 根节点常驻
    // 左侧：全高 AppSidebar（挂载一次，永久物理静止）
    // 右侧：Expanded(child: child)，由子页面自主承载其自身 Scaffold
    return Material(
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(width: AppTokens.sidebarWidth),
          Expanded(child: child),
        ],
      ),
    );
  }
}
