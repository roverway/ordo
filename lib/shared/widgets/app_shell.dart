import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import 'app_background_wrapper.dart';
import 'app_drawer.dart';
import 'floating_minimal_dock.dart';

/// 全局根导航外壳。
///
/// 响应式双模架构：
/// - 窄屏/移动端（< 600dp）：单手沉浸体验，底部居中悬浮极简胶囊坞（FloatingMinimalDock），
///   向下滚动内容时自动沉浸隐藏，向上滑动立即回弹；键盘弹起时自动隐避；
/// - 宽屏/桌面端（>= 600dp）：常驻左侧导航栏（AppSidebar，复用 ScopeNavContent），右侧为页面主体。
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  /// Page body content.
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isDockVisible = true;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isNarrow(context)) {
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      final showDock = _isDockVisible && !isKeyboardOpen;

      return AppShellScope(
        hasDock: true,
        child: AppBackgroundWrapper(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse) {
                if (_isDockVisible) {
                  setState(() => _isDockVisible = false);
                }
              } else if (notification.direction == ScrollDirection.forward) {
                if (!_isDockVisible) {
                  setState(() => _isDockVisible = true);
                }
              }
              return false;
            },
            child: Stack(
              children: [
                Positioned.fill(child: widget.child),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12 + bottomInset,
                  child: AnimatedSlide(
                    offset: showDock ? Offset.zero : const Offset(0, 1.8),
                    duration: AppTokens.motionNormal,
                    curve: AppTokens.motionSpring,
                    child: AnimatedOpacity(
                      opacity: showDock ? 1.0 : 0.0,
                      duration: AppTokens.motionFast,
                      child: const Center(child: FloatingMinimalDock()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppBackgroundWrapper(
      child: Row(
        children: [
          const AppSidebar(),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

/// 提供当前组件树是否运行于 AppShell（即底部存在 Dock 或左侧存在侧边栏）的上下文标记。
class AppShellScope extends InheritedWidget {
  const AppShellScope({super.key, this.hasDock = true, required super.child});

  final bool hasDock;

  static bool hasDockOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppShellScope>()
            ?.hasDock ??
        false;
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      hasDock != oldWidget.hasDock;
}
