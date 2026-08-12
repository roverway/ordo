import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import 'app_drawer.dart';

/// Adaptive navigation shell (30-architecture.md §5, 55-ui-redesign §3)。
///
/// - Narrow (<600dp): 侧边栏抽屉承载清单导航（系统组 + 项目组 + 新建项目，
///   55-ui-redesign §3.1 D1）+ AppBar 汉堡入口 + 底部 NavigationBar（3 系统入口）
/// - Wide (≥600dp): top AppBar + left NavigationRail（5 目的地不变，批 2-A 不动）
///
/// 抽屉选中态由当前路由路径推导；路由表不变，仅入口位置变化。
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

  /// 窄屏底部 NavigationBar 3 个系统入口（收集箱与项目移入抽屉，§3.1）。
  static const List<String> _barPaths = ['/today', '/calendar', '/tags'];

  /// 当前路由是否命中窄屏底栏的某个入口。
  ///
  /// 未命中（如 /inbox、/projects/:id、/search、/settings）时底栏**无选中**：
  /// NavigationBar 的 selectedIndex 必须为合法值（断言 0 ≤ i < n），故传 0，
  /// 但用局部 Theme 把指示器置透明、选中态样式对齐未选中，实现视觉「无选中」。
  /// 此语义仅底栏需要；宽屏 Rail 的 fallback 0 = 收件箱（索引 0，launch 首页为
  /// /today 后仍保持收件箱高亮——未命中路由时 Rail 同样无对应目的地）。
  static bool _hasBarMatch(String path) => _barPaths.contains(path);

  /// Derive destination index from route path; fall back to 0.
  static int _selectedIndexIn(List<String> paths, String path) {
    final index = paths.indexOf(path);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final narrow = AppBreakpoints.isNarrow(context);
    final path = GoRouterState.of(context).uri.path;
    final hasBarMatch = _hasBarMatch(path);
    final railIndex = _selectedIndexIn(_railPaths, path);
    final barIndex = hasBarMatch ? _barPaths.indexOf(path) : 0;

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

    // 窄屏底部 NavigationBar 3 系统入口（今日/日历/标签）。
    //
    // icon 与 selectedIcon 使用同一 outlined 图标：选中态靠 indicator 药丸 +
    // 图标/文字颜色区分（滴答式），而非切换 filled 变体。这样未命中路由时
    // 才能做到视觉「无选中」——若依赖形状切换，selectedIndex 传合法值
    // （0）会强制第一个目的地渲染 filled 图标，无法完全抑制。
    final barDestinations = <({String label, IconData icon})>[
      (label: l10n.navToday, icon: Icons.today_outlined),
      (label: l10n.navCalendar, icon: Icons.calendar_today_outlined),
      (label: l10n.navTags, icon: Icons.label_outline),
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
      bottomNavigationBar: narrow
          ? Theme(
              // 未命中底栏路由：无选中。选中 index 传 0 满足合法断言，但把
              // indicator 置透明、选中态（icon/label）样式对齐未选中，
              // 视觉上无任何高亮（修复评审问题 1：inbox 首页不再误亮「今日」）。
              data: hasBarMatch
                  ? theme
                  : theme.copyWith(
                      navigationBarTheme: theme.navigationBarTheme.copyWith(
                        indicatorColor: Colors.transparent,
                        iconTheme: WidgetStateProperty.resolveWith(
                          (states) => IconThemeData(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        labelTextStyle: WidgetStateProperty.resolveWith(
                          (states) => theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
              child: NavigationBar(
                selectedIndex: barIndex,
                onDestinationSelected: (index) => context.go(_barPaths[index]),
                destinations: [
                  for (final d in barDestinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.icon),
                      label: d.label,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}
