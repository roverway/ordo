import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/utils/app_breakpoints.dart';

/// 自适应导航骨架（30-architecture.md §5，50-ui-ux.md §4）。
///
/// - 窄屏（<600dp）：顶部 AppBar（标题 + 搜索/设置入口）+ 底部 NavigationBar；
/// - 宽屏（≥600dp）：顶部 AppBar + 左侧 NavigationRail。
///
/// 当前目的地高亮由路由路径推导；搜索/设置以 push 方式进入独立页面。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.child});

  /// 页面标题（ARB 文案，由各 feature 页面传入）。
  final String title;

  /// 页面内容。
  final Widget child;

  /// 4 个一级目的地路径（与 router.dart 保持一致）。
  static const List<String> _destinationPaths = [
    '/',
    '/calendar',
    '/projects',
    '/tags',
  ];

  /// 由当前路由路径推导目的地索引；未知路径（如搜索/设置）回退到今日。
  static int _selectedIndex(String path) {
    final index = _destinationPaths.indexOf(path);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrow = AppBreakpoints.isNarrow(context);
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path);

    final destinations =
        <({String label, IconData icon, IconData selectedIcon})>[
          (
            label: l10n.navToday,
            icon: Icons.today_outlined,
            selectedIcon: Icons.today,
          ),
          (
            label: l10n.navCalendar,
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_today,
          ),
          (
            label: l10n.navProjects,
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder,
          ),
          (
            label: l10n.navTags,
            icon: Icons.label_outline,
            selectedIcon: Icons.label,
          ),
        ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: narrow
          ? child
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      context.go(_destinationPaths[index]),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: child),
              ],
            ),
      bottomNavigationBar: narrow
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  context.go(_destinationPaths[index]),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            )
          : null,
    );
  }
}
