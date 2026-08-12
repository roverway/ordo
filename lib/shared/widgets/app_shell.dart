import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import 'app_drawer.dart';
import 'compact_bottom_bar.dart';

/// Adaptive navigation shell (30-architecture.md §5, 55-ui-redesign §3)。
///
/// - Narrow (<600dp): 侧边栏抽屉承载清单导航（系统组 + 项目组 + 新建项目，
///   55-ui-redesign §3.1 D1）+ AppBar 汉堡入口 + 紧凑底栏（今日/日历 2 项，
///   57-task-page-polish §4.1 D5）
/// - Wide (≥600dp): top AppBar + left NavigationRail（5 目的地不变）
///
/// 抽屉/底栏选中态由当前路由路径推导；路由表不变，仅入口位置变化。
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  /// Page title (from ARB, passed by each feature page).
  final String title;

  /// Page body content.
  final Widget child;

  /// 追加在搜索/设置图标**之后**的 AppBar actions（如项目作用域的编辑/删除）。
  /// null = 仅默认搜索/设置（现有调用方兼容，56-task-scope-page.md §3.3）。
  final List<Widget>? actions;

  /// 宽屏 NavigationRail 5 个目的地（keep in sync with router.dart）。
  static const List<String> _railPaths = [
    '/inbox',
    '/today',
    '/calendar',
    '/projects',
    '/tags',
  ];

  /// 窄屏紧凑底栏目的地路径（57-task-page-polish §4.1 D5：今日/日历 2 项，
  /// 标签移入抽屉）。**将来新增功能按钮在此追加**（与 barDestinations 同步）。
  static const List<String> _barPaths = ['/today', '/calendar'];

  /// 当前路由是否命中窄屏底栏的某个入口。
  ///
  /// 未命中（如 /inbox、/projects/:id、/search、/settings）时底栏**无选中**：
  /// 自绘 [CompactBottomBar] 的 selectedIndex 传 `-1`（视觉全未选中，
  /// 无 NavigationBar 的合法索引断言限制）。
  static bool _hasBarMatch(String path) => _barPaths.contains(path);

  /// Derive destination index from route path; fall back to 0.
  static int _selectedIndexIn(List<String> paths, String path) {
    final index = paths.indexOf(path);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrow = AppBreakpoints.isNarrow(context);
    final path = GoRouterState.of(context).uri.path;
    final hasBarMatch = _hasBarMatch(path);
    final railIndex = _selectedIndexIn(_railPaths, path);
    // -1 = 无选中（inbox/项目/搜索/设置等非底栏路径）。
    final barIndex = hasBarMatch ? _barPaths.indexOf(path) : -1;

    // 宽屏 Rail 5 目的地（不变）。
    final railDestinations =
        <({String label, IconData icon, IconData selectedIcon})>[
          (
            label: l10n.navInbox,
            icon: Icons.inbox_outlined,
            selectedIcon: Icons.inbox,
          ),
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

    // 窄屏紧凑底栏 2 系统入口（今日/日历；标签移入抽屉，57-task-page-polish §4.1）。
    // 列表渲染可扩展：将来新增功能按钮在 _barPaths 与这里各加一项即可。
    final barDestinations =
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
        ];

    return Scaffold(
      // 窄屏抽屉：宽度（屏宽 × drawerWidthRatio）由 AppDrawer 自身提供
      //（评审问题 5：接线 0.78 令牌）；右侧遮罩点击关闭由 Scaffold scrim 提供。
      drawer: narrow ? const AppDrawer() : null,
      appBar: AppBar(
        // 仅窄屏显示汉堡入口；宽屏由 Rail 承担导航。
        leading: narrow
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: l10n.openDrawer,
                  icon: const Icon(Icons.menu, size: 22),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search, size: 22),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => context.push('/settings'),
          ),
          // 作用域专属操作（追加在尾部）。
          ...?actions,
        ],
      ),
      body: narrow
          ? child
          : Row(
              children: [
                NavigationRail(
                  // 宽度与选中态药丸高亮由 AppTheme.navigationRailTheme 提供
                  // （railWidth / indicatorColor / indicatorShape，55-ui-redesign §3.2）。
                  minWidth: AppTokens.railWidth,
                  selectedIndex: railIndex,
                  onDestinationSelected: (index) =>
                      context.go(_railPaths[index]),
                  destinations: [
                    for (final d in railDestinations)
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
      // 新建任务 FAB 布局策略见 55-ui-redesign §4.1；inbox/today/calendar 各自放置
      // （projects/tags 保留各自语义 FAB）。不在 AppShell 层挂全局 FAB，避免与
      // 页面自身 FAB 重复（widget_test 断言单 FAB）。
      // 窄屏紧凑底栏（自绘 CompactBottomBar：高 56dp，明显矮于标准
      // NavigationBar 80dp；「无选中」= selectedIndex -1，天然支持）。
      bottomNavigationBar: narrow
          ? CompactBottomBar(
              destinations: barDestinations,
              selectedIndex: barIndex,
              onSelected: (index) => context.go(_barPaths[index]),
            )
          : null,
    );
  }
}
