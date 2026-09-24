import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'scope_nav_content.dart';

/// 移动端侧边栏抽屉。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * AppTokens.drawerWidthRatio,
      child: const AppSidebarContent(isDrawer: true),
    );
  }
}

/// 桌面端/宽屏常驻侧边栏（全平台 Windows / Linux / macOS 通用）。
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, this.width = AppTokens.sidebarWidth});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: const Material(
        color: Colors.transparent,
        child: AppSidebarContent(isDrawer: false),
      ),
    );
  }
}

/// 侧边栏通用内容区（抽屉模式与固定常驻模式共用统一的 ScopeNavContent）。
class AppSidebarContent extends StatelessWidget {
  const AppSidebarContent({super.key, required this.isDrawer});

  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ScopeNavContent(isModal: isDrawer, showHeader: true),
    );
  }
}
