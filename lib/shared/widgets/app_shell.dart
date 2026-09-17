import 'package:flutter/material.dart';
import 'app_background_wrapper.dart';

/// 全局根导航外壳。
///
/// 遵循新版现代化设计规范：全平台（桌面端与移动端）统一采用极简沉浸式单屏布局，
/// 由顶栏大标题唤起的导航弹窗（ScopeSwitcherSheet）承载全部范围与清单切换，
/// 彻底废弃旧式常驻侧边栏。
/// 同时承载应用级全局壁纸渲染（AppBackgroundWrapper）。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  /// Page body content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppBackgroundWrapper(child: child);
  }
}
