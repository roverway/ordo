import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/repositories/todo_repository.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/projects/project_providers.dart';
import '../../features/projects/widgets/project_form_dialog.dart';
import '../../features/tasks/task_providers.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// 移动端侧边栏抽屉（55-ui-redesign-proposal.md §3.1，D1，批 2-A）。
///
/// - 顶部：应用名（无账号体系，不做头像）。
/// - 系统组（无分隔线）：今日 / 收集箱 / 日历 / 标签。
/// - 细分隔线 + 项目组（用户清单）：颜色圆点 + 项目名 + 未完成数。
/// - 细分隔线 + 底部「新建项目」入口（复用 [showProjectFormDialog]）。
/// - 当前项选中态：secondaryContainer 浅色药丸 + 圆角（colorScheme 派生，
///   不硬编码颜色）；由当前路由路径推导（路由不变，仅入口变化）。
///
/// 宽度 = 屏宽 × [AppTokens.drawerWidthRatio]（0.78，定稿 75–80% 屏宽），
/// 右侧半透明遮罩由 Scaffold 自带 scrim 提供（点击关闭）。
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  /// 防抽屉关闭动画期间（~246ms）重复点击导致的二次 pop 竞态
  /// （第二次 pop 会弹掉刚 push 的 /settings 路由）。
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final path = GoRouterState.of(context).uri.path;

    // 系统组目的地（顺序即展示顺序，55-ui-redesign §3.1）。
    final systemItems =
        <({String path, IconData icon, IconData selectedIcon, String label})>[
          (
            path: '/today',
            icon: Icons.today_outlined,
            selectedIcon: Icons.today,
            label: l10n.navToday,
          ),
          (
            path: '/inbox',
            icon: Icons.inbox_outlined,
            selectedIcon: Icons.inbox,
            label: l10n.navInbox,
          ),
          (
            path: '/calendar',
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_today,
            label: l10n.navCalendar,
          ),
          (
            path: '/tags',
            icon: Icons.label_outline,
            selectedIcon: Icons.label,
            label: l10n.navTags,
          ),
        ];

    return Drawer(
      width: MediaQuery.sizeOf(context).width * AppTokens.drawerWidthRatio,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部：应用名 / Logo 占位（无账号体系，不做头像）。
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceMd,
                AppTokens.spaceLg,
                AppTokens.spaceMd,
                AppTokens.spaceMd,
              ),
              child: Text(
                l10n.appTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: AppTokens.textHeadingWeight,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  // ── 系统组（无分隔线）──
                  for (final item in systemItems)
                    _DrawerTile(
                      leading: Icon(
                        path == item.path ? item.selectedIcon : item.icon,
                        size: AppTokens.expandArrowSize,
                        color: path == item.path
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: item.label,
                      selected: path == item.path,
                      onTap: () => _go(context, item.path),
                    ),
                  const Divider(),
                  // ── 项目组（用户清单）──
                  ...ref
                      .watch(projectsStreamProvider)
                      .when(
                        data: (projects) => [
                          // 内置收件箱由系统组 /inbox 承载，项目组不重复展示
                          //（Bug 3 用户实测：此前侧栏出现两个「收件箱」入口）。
                          for (final project in projects.where(
                            (p) => p.id != inboxProjectId,
                          ))
                            _DrawerTile(
                              leading: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Color(project.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: project.name,
                              trailing: Text(
                                '${ref.watch(projectUncompletedCountProvider(project.id))}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              selected: path == '/projects/${project.id}',
                              onTap: () =>
                                  _go(context, '/projects/${project.id}'),
                            ),
                        ],
                        loading: () => const [
                          Padding(
                            padding: EdgeInsets.all(AppTokens.spaceXs),
                            child: LoadingView(compact: true),
                          ),
                        ],
                        error: (e, st) {
                          logAsyncError(e, st);
                          return [
                            Padding(
                              padding: const EdgeInsets.all(AppTokens.spaceXs),
                              child: ErrorView(
                                compact: true,
                                onRetry: () =>
                                    ref.invalidate(projectsStreamProvider),
                              ),
                            ),
                          ];
                        },
                      ),
                ],
              ),
            ),
            const Divider(),
            // ── 底部：「新建项目」（图标 + 文字，复用项目表单对话框）
            //    右侧并排设置入口（用户打磨要求 4：设置按钮移出 AppBar，
            //    窄屏入口在抽屉底部）。
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceXs,
                AppTokens.spaceXxs,
                AppTokens.spaceXs,
                AppTokens.spaceSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusChip,
                        ),
                        onTap: () => _showNewProjectDialog(context, ref),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.spaceMd,
                            vertical: AppTokens.spaceSm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add,
                                size: AppTokens.expandArrowSize,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: AppTokens.spaceMd),
                              Text(
                                l10n.newProject,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: AppTokens.textTitleWeight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 设置入口（同高、垂直居中；先关抽屉再跳转）。
                  // 用 push 而非 go：go('/settings') 会替换整个导航栈，
                  // 设置页将无路可返（router.dart /settings 注释；Bug 2 回归）。
                  IconButton(
                    tooltip: l10n.settings,
                    icon: const Icon(Icons.settings_outlined, size: 22),
                    onPressed: () => _openSettings(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 关闭抽屉并切换到目标路由（路由不变，仅入口位置变化）。
  void _go(BuildContext context, String path) {
    if (_navigating) return;
    _navigating = true;
    Navigator.of(context).pop();
    context.go(path);
  }

  /// 关闭抽屉并推入设置页（push 保持导航栈，设置页可返回任务页）。
  void _openSettings(BuildContext context) {
    if (_navigating) return;
    _navigating = true;
    Navigator.of(context).pop();
    context.push('/settings');
  }

  Future<void> _showNewProjectDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showProjectFormDialog(context: context);
    if (result != null && context.mounted) {
      await ref
          .read(todoRepositoryProvider)
          .createProject(
            name: result.name,
            color: result.color,
            description: result.description,
          );
    }
  }
}

/// 抽屉行：leading（图标/颜色圆点）+ 标题 + 可选 trailing（未完成数）。
///
/// 选中态：secondaryContainer 浅色药丸 + 圆角（colorScheme 派生，不硬编码）。
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceXs,
        vertical: 2,
      ),
      child: Material(
        color: selected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceMd,
              vertical: AppTokens.spaceSm,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurface,
                      fontWeight: selected
                          ? AppTokens.textTitleWeight
                          : AppTokens.textBodyWeight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppTokens.spaceXs),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
