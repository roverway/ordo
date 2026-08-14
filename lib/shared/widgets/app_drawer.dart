import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/projects/project_providers.dart';
import '../../features/projects/widgets/folder_name_dialog.dart';
import '../../features/projects/widgets/project_form_dialog.dart';
import '../../features/tasks/task_providers.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// 移动端侧边栏抽屉（55-ui-redesign-proposal.md §3.1，D1，批 2-A；
/// 62-folder-nav.md §6.1 批 3 文件夹化）。
///
/// - 顶部：应用名（无账号体系，不做头像）。
/// - 系统组（无分隔线）：今日 / 收集箱 / 日历 / 标签。
/// - 细分隔线 + 项目区（62-folder-nav.md §6.1）：
///   - 文件夹组（每个文件夹一行 + 其内项目行，展开/折叠）；
///   - 未分组区（小标题 + 平铺项目行；收件箱仍排除）；
/// - 细分隔线 + 底部「新建文件夹」+「新建项目」+ 设置。
///
/// 拖拽（62-folder-nav.md §6.2，复用 task_tree 的 LongPressDraggable +
/// DragTarget 模式）：
/// - 项目行（data = 前缀 `p:` + 项目 id）：拖到文件夹行入夹 / 拖到未分组区出夹 /
///   拖到同组项目行组内重排；折叠的文件夹行作为目标时自动展开；
/// - 文件夹行（data = 前缀 `f:` + 文件夹 id）：拖到另一文件夹行重排顺序。
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

  // ── 拖拽状态（62-folder-nav.md §6.2，复用 task_tree 模式）──

  /// 拖拽数据前缀：区分项目（p:）与文件夹（f:）。
  static const String _projectDragPrefix = 'p:';
  static const String _folderDragPrefix = 'f:';

  /// 未分组区落点的唯一目标 key（非真实行 id）。
  static const String _ungroupedTargetKey = '_ungrouped';

  /// 当前被拖拽项（`p:` 或 `f:` 前缀 + id），null = 无拖拽。
  String? _draggingData;

  /// 当前高亮目标行 key（`p:` / `f:` 前缀 + id / [_ungroupedTargetKey]）。
  String? _dragTargetKey;

  /// 当前目标是否为非法落点（自身/错误类型），红色高亮。
  bool _invalidDragTarget = false;

  void _clearDragState() {
    _draggingData = null;
    _dragTargetKey = null;
    _invalidDragTarget = false;
  }

  /// 目标行高亮底色（合法 = primaryContainer 浅染，非法 = errorContainer）。
  Color? _targetColor(BuildContext context, bool isTarget, bool isInvalid) {
    if (!isTarget) return null;
    final colorScheme = Theme.of(context).colorScheme;
    return isInvalid
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer.withValues(alpha: 0.5);
  }

  /// 拖拽反馈浮层（半透明 + 阴影，复用 task_tree 视觉）。
  Widget _dragFeedback(Widget leading, String label) {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.8,
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.6,
          padding: const EdgeInsets.all(AppTokens.spaceSm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusList),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppTokens.spaceXs),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 仓库操作失败提示。
  ///
  /// 拖拽移动失败用「移动失败」包装（与 task_tree 一致）；文件夹
  /// 新建/重命名/删除的 Repository 异常消息本身就是面向用户的中文文案
  /// （TaskFormNotifier.save 同款直接展示模式），直接展示。
  void _showRepoError(BuildContext context, Object e, {bool isMove = false}) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isMove ? l10n.moveFailed(e.toString()) : '$e')),
    );
  }

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
                  // ── 项目区（文件夹组 + 未分组区，62-folder-nav.md §6.1）──
                  ..._buildProjectArea(context, l10n),
                ],
              ),
            ),
            const Divider(),
            // ── 底部：「新建文件夹」+「新建项目」（并列）+ 设置 ──
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
                    child: _bottomAction(
                      context,
                      icon: Icons.create_new_folder_outlined,
                      label: l10n.newFolder,
                      onTap: () => _showNewFolderDialog(context, ref),
                    ),
                  ),
                  Expanded(
                    child: _bottomAction(
                      context,
                      icon: Icons.add,
                      label: l10n.newProject,
                      onTap: () => _showNewProjectDialog(context, ref),
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

  /// 底部并排入口（图标 + 文字，62-folder-nav.md §6.3）。
  Widget _bottomAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceSm,
            vertical: AppTokens.spaceSm,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppTokens.expandArrowSize,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppTokens.spaceXs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: AppTokens.textTitleWeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────── 项目区（62-folder-nav.md §6.1） ───────────────────────

  /// 项目区内容：文件夹组（各含项目行）→ 未分组区。
  ///
  /// 未分组区在有文件夹时**始终**渲染（空行也可作为「出夹」拖拽落点，
  /// §6.2）；无文件夹时仅在有未分组项目时渲染（保持旧平铺视觉）。
  List<Widget> _buildProjectArea(BuildContext context, AppLocalizations l10n) {
    final groupingAsync = ref.watch(projectsByFolderProvider);
    final expandState =
        ref.watch(folderExpandProvider).value ?? const <String, bool>{};

    return groupingAsync.when(
      data: (grouping) {
        final children = <Widget>[];
        for (final folder in grouping.folders) {
          final expanded = expandState[folder.id] ?? true;
          children.add(
            _buildFolderRow(context, l10n, grouping, folder, expanded),
          );
          if (expanded) {
            for (final project
                in grouping.folderProjects[folder.id] ?? const <Project>[]) {
              children.add(
                _buildProjectRow(
                  context,
                  l10n,
                  project,
                  grouping,
                  indent: AppTokens.folderIndent,
                ),
              );
            }
          }
        }
        final showUngrouped =
            grouping.folders.isNotEmpty || grouping.ungrouped.isNotEmpty;
        if (showUngrouped) {
          children.add(_buildUngroupedHeader(context, l10n, grouping));
          for (final project in grouping.ungrouped) {
            children.add(
              _buildProjectRow(context, l10n, project, grouping, indent: 0),
            );
          }
        }
        return children;
      },
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
              onRetry: () => ref.invalidate(projectsByFolderProvider),
            ),
          ),
        ];
      },
    );
  }

  /// 文件夹汇总未完成数 = 其内项目未完成数之和（恒为真实值，D8）。
  ///
  /// 统计口径与项目行一致（projectUncompletedCountProvider，派生状态语义）。
  int _folderUncompleted(WidgetRef ref, String folderId) {
    final grouping = ref.watch(projectsByFolderProvider).value;
    final projects = grouping?.folderProjects[folderId] ?? const <Project>[];
    var sum = 0;
    for (final p in projects) {
      sum += ref.watch(projectUncompletedCountProvider(p.id));
    }
    return sum;
  }

  /// 文件夹行：[展开/折叠箭头] [文件夹图标] 名称 [汇总未完成数] [⋯ 菜单]。
  ///
  /// - 点击行切换展开/折叠（62-folder-nav.md §6.1）；
  /// - 行尾菜单：重命名 / 删除（§6.3）；
  /// - 拖拽（§6.2）：文件夹行自身可拖拽排序；同时作为**项目入夹**与
  ///   **文件夹重排**的落点；折叠时作为项目落点自动展开。
  Widget _buildFolderRow(
    BuildContext context,
    AppLocalizations l10n,
    ProjectGrouping grouping,
    Folder folder,
    bool expanded,
  ) {
    final folderKey = '$_folderDragPrefix${folder.id}';
    final isDragTarget = _dragTargetKey == folderKey;
    final isInvalid = _invalidDragTarget && isDragTarget;
    final isDragging = _draggingData == folderKey;

    return LongPressDraggable<String>(
      data: folderKey,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => setState(() => _draggingData = folderKey),
      onDragEnd: (_) => setState(_clearDragState),
      feedback: _dragFeedback(
        Icon(
          Icons.folder_outlined,
          size: AppTokens.expandArrowSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        folder.name,
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _folderRowContent(context, l10n, grouping, folder, expanded),
      ),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          // 自身不能拖到自身。
          if (data == folderKey) {
            setState(() {
              _dragTargetKey = folderKey;
              _invalidDragTarget = true;
            });
            return false;
          }
          if (data.startsWith(_projectDragPrefix)) {
            // 折叠的文件夹作为项目落点：**自动展开**再接受（§6.2）。
            if (!expanded) {
              ref.read(folderExpandProvider.notifier).toggle(folder.id);
            }
            setState(() {
              _dragTargetKey = folderKey;
              _invalidDragTarget = false;
            });
            return true;
          }
          if (data.startsWith(_folderDragPrefix)) {
            setState(() {
              _dragTargetKey = folderKey;
              _invalidDragTarget = false;
            });
            return true;
          }
          return false;
        },
        onAcceptWithDetails: (details) async {
          final data = details.data;
          final repo = ref.read(todoRepositoryProvider);
          try {
            if (data.startsWith(_projectDragPrefix)) {
              // 入夹：追加到该文件夹项目末尾。
              await repo.moveProjectToFolder(
                data.substring(_projectDragPrefix.length),
                folderId: folder.id,
                newIndex: grouping.countInFolder(folder.id),
              );
            } else if (data.startsWith(_folderDragPrefix)) {
              // 文件夹重排：插到目标行位置（sortOrder 即文件夹列表索引）。
              await repo.moveFolder(
                data.substring(_folderDragPrefix.length),
                newIndex: folder.sortOrder,
              );
            }
          } catch (e) {
            if (context.mounted) _showRepoError(context, e, isMove: true);
          }
          if (mounted) setState(_clearDragState);
        },
        onLeave: (_) {
          setState(() {
            _dragTargetKey = null;
            _invalidDragTarget = false;
          });
        },
        builder: (context, candidateData, rejectedData) {
          return _folderRowContent(
            context,
            l10n,
            grouping,
            folder,
            expanded,
            isDragTarget: isDragTarget,
            isInvalidDragTarget: isInvalid,
            isDragging: isDragging,
          );
        },
      ),
    );
  }

  /// 文件夹行内容（拖拽反馈高亮 / 半透明由参数控制）。
  Widget _folderRowContent(
    BuildContext context,
    AppLocalizations l10n,
    ProjectGrouping grouping,
    Folder folder,
    bool expanded, {
    bool isDragTarget = false,
    bool isInvalidDragTarget = false,
    bool isDragging = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final highlight = _targetColor(context, isDragTarget, isInvalidDragTarget);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceXs,
        vertical: 2,
      ),
      child: Material(
        color: highlight ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          onTap: () =>
              ref.read(folderExpandProvider.notifier).toggle(folder.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceSm,
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: AppTokens.expandArrowSize,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.spaceXxs),
                Icon(
                  Icons.folder_outlined,
                  size: AppTokens.expandArrowSize,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    folder.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                // 汇总未完成数（恒为真实值，D8）。
                Text(
                  '${_folderUncompleted(ref, folder.id)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                // 行尾菜单：重命名 / 删除（§6.3）。
                PopupMenuButton<String>(
                  tooltip: l10n.folderActions,
                  icon: Icon(
                    Icons.more_vert,
                    size: AppTokens.expandArrowSizeRow,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (action) =>
                      _handleFolderMenu(context, l10n, folder, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l10n.renameFolder),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.deleteFolder),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 项目行：色点 + 名称 + 未完成数（文件夹下缩进 [indent]）。
  ///
  /// 拖拽（§6.2）：项目行可拖拽（入夹/出夹/组内重排），同时作为同组
  /// 项目行的重排落点（跨组落点同样按目标组内索引插入）。
  Widget _buildProjectRow(
    BuildContext context,
    AppLocalizations l10n,
    Project project,
    ProjectGrouping grouping, {
    required double indent,
  }) {
    final projectKey = '$_projectDragPrefix${project.id}';
    final isDragTarget = _dragTargetKey == projectKey;
    final isInvalid = _invalidDragTarget && isDragTarget;
    final isDragging = _draggingData == projectKey;

    return LongPressDraggable<String>(
      data: projectKey,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => setState(() => _draggingData = projectKey),
      onDragEnd: (_) => setState(_clearDragState),
      feedback: _dragFeedback(
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Color(project.color),
            shape: BoxShape.circle,
          ),
        ),
        project.name,
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _projectRowContent(
          context,
          l10n,
          project,
          indent: indent,
          isDragging: true,
        ),
      ),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          // 仅接受项目拖拽；自身不能拖到自身。
          if (!data.startsWith(_projectDragPrefix)) return false;
          if (data == projectKey) {
            setState(() {
              _dragTargetKey = projectKey;
              _invalidDragTarget = true;
            });
            return false;
          }
          setState(() {
            _dragTargetKey = projectKey;
            _invalidDragTarget = false;
          });
          return true;
        },
        onAcceptWithDetails: (details) async {
          final data = details.data;
          if (!data.startsWith(_projectDragPrefix)) return;
          final draggedId = data.substring(_projectDragPrefix.length);
          final repo = ref.read(todoRepositoryProvider);
          try {
            // 组内重排（含跨组入夹到目标组内指定位置）：newIndex 取目标
            // 项目在其所属组**全量**列表中的索引（§6.2 语义与 task_tree 一致）。
            await repo.moveProjectToFolder(
              draggedId,
              folderId: project.folderId,
              newIndex: grouping.indexInGroup(
                project,
                folderId: project.folderId,
              ),
            );
          } catch (e) {
            if (context.mounted) _showRepoError(context, e, isMove: true);
          }
          if (mounted) setState(_clearDragState);
        },
        onLeave: (_) {
          setState(() {
            _dragTargetKey = null;
            _invalidDragTarget = false;
          });
        },
        builder: (context, candidateData, rejectedData) {
          return _projectRowContent(
            context,
            l10n,
            project,
            indent: indent,
            isDragTarget: isDragTarget,
            isInvalidDragTarget: isInvalid,
            isDragging: isDragging,
          );
        },
      ),
    );
  }

  /// 项目行内容（复用 [_DrawerTile]；拖拽状态经参数传入）。
  Widget _projectRowContent(
    BuildContext context,
    AppLocalizations l10n,
    Project project, {
    required double indent,
    bool isDragTarget = false,
    bool isInvalidDragTarget = false,
    bool isDragging = false,
  }) {
    final path = GoRouterState.of(context).uri.path;
    return _DrawerTile(
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      selected: path == '/projects/${project.id}',
      onTap: () => _go(context, '/projects/${project.id}'),
      indent: indent,
      dragHighlightColor: _targetColor(
        context,
        isDragTarget,
        isInvalidDragTarget,
      ),
    );
  }

  /// 未分组区小标题（同时也是「出夹」拖拽落点，§6.2）。
  Widget _buildUngroupedHeader(
    BuildContext context,
    AppLocalizations l10n,
    ProjectGrouping grouping,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDragTarget = _dragTargetKey == _ungroupedTargetKey;
    final isInvalid = _invalidDragTarget && isDragTarget;
    final highlight = _targetColor(context, isDragTarget, isInvalid);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (!details.data.startsWith(_projectDragPrefix)) return false;
        setState(() {
          _dragTargetKey = _ungroupedTargetKey;
          _invalidDragTarget = false;
        });
        return true;
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        if (!data.startsWith(_projectDragPrefix)) return;
        final repo = ref.read(todoRepositoryProvider);
        try {
          // 出夹：folderId 置 null，追加到未分组末尾。
          await repo.moveProjectToFolder(
            data.substring(_projectDragPrefix.length),
            folderId: null,
            newIndex: grouping.ungroupedCount,
          );
        } catch (e) {
          if (context.mounted) _showRepoError(context, e, isMove: true);
        }
        if (mounted) setState(_clearDragState);
      },
      onLeave: (_) {
        setState(() {
          _dragTargetKey = null;
          _invalidDragTarget = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceMd,
            AppTokens.spaceSm,
            AppTokens.spaceMd,
            AppTokens.spaceXxs,
          ),
          child: Material(
            color: highlight ?? Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs,
                vertical: AppTokens.spaceXxs,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.ungrouped,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 文件夹行尾菜单：重命名 / 删除（删除确认明示「项目将回到未分组」，D3）。
  Future<void> _handleFolderMenu(
    BuildContext context,
    AppLocalizations l10n,
    Folder folder,
    String action,
  ) async {
    final repo = ref.read(todoRepositoryProvider);
    switch (action) {
      case 'rename':
        final name = await showFolderNameDialog(
          context: context,
          initialName: folder.name,
        );
        if (name != null && context.mounted) {
          try {
            await repo.renameFolder(folder.id, name: name);
          } catch (e) {
            if (context.mounted) _showRepoError(context, e);
          }
        }
      case 'delete':
        final confirmed = await showConfirmDialog(
          context: context,
          title: l10n.deleteFolder,
          message:
              '${l10n.deleteFolderConfirm(folder.name)}\n${l10n.deleteFolderWarning}',
          confirmLabel: l10n.delete,
          confirmColor: Theme.of(context).colorScheme.error,
        );
        if (confirmed && context.mounted) {
          try {
            await repo.deleteFolder(folder.id);
          } catch (e) {
            if (context.mounted) _showRepoError(context, e);
          }
        }
    }
  }

  // ─────────────────────────── 弹窗与导航 ───────────────────────────

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

  Future<void> _showNewFolderDialog(BuildContext context, WidgetRef ref) async {
    final name = await showFolderNameDialog(context: context);
    if (name != null && context.mounted) {
      try {
        await ref.read(todoRepositoryProvider).createFolder(name: name);
      } catch (e) {
        if (context.mounted) _showRepoError(context, e);
      }
    }
  }
}

/// 抽屉行：leading（图标/颜色圆点）+ 标题 + 可选 trailing（未完成数）。
///
/// 选中态：secondaryContainer 浅色药丸 + 圆角（colorScheme 派生，不硬编码）。
/// [indent]：文件夹下项目行的缩进（62-folder-nav.md §6.1）；
/// [dragHighlightColor]：拖拽悬停目标时的高亮底色（非 null 覆盖选中态底色）。
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.indent = 0,
    this.dragHighlightColor,
  });

  final Widget leading;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  /// 额外左缩进（文件夹下项目行）。
  final double indent;

  /// 拖拽目标高亮（合法/非法由调用方决定颜色）。
  final Color? dragHighlightColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTokens.spaceXs + indent,
        AppTokens.spaceXxs - 2,
        AppTokens.spaceXs,
        AppTokens.spaceXxs - 2,
      ),
      child: Material(
        color:
            dragHighlightColor ??
            (selected ? colorScheme.secondaryContainer : Colors.transparent),
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
