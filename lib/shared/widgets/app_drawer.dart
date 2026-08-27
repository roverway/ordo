import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/motion.dart';
import '../../features/custom_views/presentation/custom_view_editor_page.dart';
import '../../features/custom_views/providers/custom_view_providers.dart';
import '../../features/custom_views/widgets/icon_picker_dialog.dart';
import '../../features/projects/project_providers.dart';
import '../../features/projects/widgets/folder_name_dialog.dart';
import '../../features/projects/widgets/project_form_dialog.dart';
import '../../features/settings/widgets/settings_side_sheet.dart';
import '../../features/tasks/task_providers.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// 移动端侧边栏抽屉（55-ui-redesign-proposal.md §3.1，D1，批 2-A；
/// 62-folder-nav.md §6.1 批 3 文件夹化）。
///
/// - 顶部：应用名（无账号体系，不做头像）。
/// - 系统组（无分隔线）：今日 / 收集箱 / 日历 / 标签。
/// - 细分隔线 + 项目区（62-folder-nav.md §6.1，des-1/des-2 优化）：
///   - 文件夹组：文件夹行（**与系统组行左对齐**；图标 + 名称 + 汇总数 +
///     [⋯ 仅展开] + 展开箭头在行最右；展开/折叠**高度不变**）+ 展开时
///     树状连线缩进的项目行（自上而下由淡转浓的渐变竖线 + 圆角转角 +
///     更紧凑的行间距）；
///   - 未分组区（小标题 + 平铺项目行；收件箱仍排除）；
/// - 细分隔线 + 底部「新建文件夹」+「新建项目」+ 设置。
///
/// 行间距：系统组/文件夹行/未分组行统一 [AppTokens.drawerRowSpacing]；
/// 树状区内项目行用更紧凑的 [AppTokens.folderTreeRowSpacing]（des-2 需求 2b）。
///
/// 拖拽（62-folder-nav.md §6.2，复用 task_tree 的 LongPressDraggable +
/// DragTarget 模式）：
/// - 项目行（data = 前缀 `p:` + 项目 id）：拖到文件夹行入夹 / 拖到未分组区出夹 /
///   拖到同组项目行组内重排；折叠的文件夹行作为目标时自动展开；
/// - 文件夹行（data = 前缀 `f:` + 文件夹 id）：拖到另一文件夹行重排顺序。
///
/// 宽度 = 屏宽 × [AppTokens.drawerWidthRatio]（0.78，定稿 75–80% 屏宽），
/// 右侧半透明遮罩由 Scaffold 自带 scrim 提供（点击关闭）。
/// 移动端/窄屏侧边栏抽屉（55-ui-redesign-proposal.md §3.1，D1，批 2-A；
/// 62-folder-nav.md §6.1 批 3 文件夹化）。
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

/// 桌面端/宽屏常驻侧边栏（全平台 Windows / Linux / macOS 通用）
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
      child: const AppSidebarContent(isDrawer: false),
    );
  }
}

/// 侧边栏通用内容区（抽屉模式与固定常驻模式共用同一套内容与逻辑）
class AppSidebarContent extends ConsumerStatefulWidget {
  const AppSidebarContent({super.key, required this.isDrawer});

  final bool isDrawer;

  @override
  ConsumerState<AppSidebarContent> createState() => _AppSidebarContentState();
}

class _AppSidebarContentState extends ConsumerState<AppSidebarContent> {
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final feedbackWidth = widget.isDrawer
        ? screenWidth * 0.6
        : (AppTokens.sidebarWidth - AppTokens.spaceMd * 2);
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.8,
        child: Container(
          width: feedbackWidth,
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

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 顶部品牌区 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceMd,
              AppTokens.spaceSm,
              AppTokens.spaceMd,
              AppTokens.spaceXs,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Text(
                  'Todo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXxs),
              children: [
                // ── 系统组（无分隔线）──
                for (final item in systemItems)
                  _DrawerTile(
                    leading: Icon(
                      path == item.path ? item.selectedIcon : item.icon,
                      size: 18,
                      color: path == item.path
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: item.label,
                    selected: path == item.path,
                    onTap: () => _go(context, item.path),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, thickness: 0.6),
                ),
                // ── 自定义视图区 ──
                ..._buildCustomViewsArea(context, l10n, path),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, thickness: 0.6),
                ),
                // ── 任务分组（文件夹组 + 未分组区）──
                ..._buildProjectArea(context, l10n),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8),
          // ── 底部：「新建项目」+ 设置 ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceXs,
              vertical: AppTokens.spaceXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _bottomAction(
                    context,
                    icon: Icons.add,
                    label: l10n.newProject,
                    onTap: () => _showNewProjectDialog(context, ref),
                  ),
                ),
                // 设置入口
                IconButton(
                  tooltip: l10n.settings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: () => _openSettings(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部并排入口（图标 + 文字）。
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
        borderRadius: BorderRadius.circular(AppTokens.radiusList),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────── 自定义视图区 ───────────────────────

  List<Widget> _buildCustomViewsArea(
    BuildContext context,
    AppLocalizations l10n,
    String currentPath,
  ) {
    final customViewsAsync = ref.watch(customViewsStreamProvider);
    final theme = Theme.of(context);

    return customViewsAsync.when(
      data: (views) {
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceMd,
            AppTokens.spaceXxs,
            AppTokens.spaceXs,
            2,
          ),
          child: Row(
            children: [
              Text(
                l10n.customViews,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: AppTokens.textMicroSize,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox.square(
                dimension: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: l10n.newCustomView,
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => _openNewCustomView(context),
                ),
              ),
            ],
          ),
        );

        if (views.isEmpty) return [header];

        return [
          header,
          ...views.map((CustomView view) {
            final isSelected = currentPath == '/custom_view/${view.id}';
            return _DrawerTile(
              leading: Icon(
                getCustomViewIcon(view.icon),
                size: 18,
                color: Color(view.color),
              ),
              title: view.name,
              selected: isSelected,
              onTap: () => _go(context, '/custom_view/${view.id}'),
            );
          }),
        ];
      },
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(AppTokens.spaceXs),
          child: LoadingView(compact: true),
        ),
      ],
      error: (e, st) => const <Widget>[],
    );
  }

  // ─────────────────────── 项目区（62-folder-nav.md §6.1） ───────────────────────

  /// 项目区内容：文件夹组（各含项目行）→ 未分组区。
  List<Widget> _buildProjectArea(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final groupingAsync = ref.watch(projectsByFolderProvider);
    final expandState =
        ref.watch(folderExpandProvider).value ?? const <String, bool>{};

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceMd,
        AppTokens.spaceXxs,
        AppTokens.spaceXs,
        2,
      ),
      child: Row(
        children: [
          Text(
            l10n.taskGroups,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: AppTokens.textMicroSize,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const Spacer(),
          SizedBox.square(
            dimension: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: l10n.newFolder,
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              onPressed: () => _showNewFolderDialog(context, ref),
            ),
          ),
        ],
      ),
    );

    return groupingAsync.when(
      data: (grouping) {
        final children = <Widget>[header];
        for (final folder in grouping.folders) {
          final expanded = expandState[folder.id] ?? true;
          children.add(
            _buildFolderGroup(context, l10n, grouping, folder, expanded),
          );
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
      loading: () => [
        header,
        const Padding(
          padding: EdgeInsets.all(AppTokens.spaceXs),
          child: LoadingView(compact: true),
        ),
      ],
      error: (e, st) {
        logAsyncError(e, st);
        return [
          header,
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

  /// 文件夹整组（文件夹行 + 展开时的树状项目区）。
  Widget _buildFolderGroup(
    BuildContext context,
    AppLocalizations l10n,
    ProjectGrouping grouping,
    Folder folder,
    bool expanded,
  ) {
    final projects = grouping.folderProjects[folder.id] ?? const <Project>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFolderRow(context, l10n, grouping, folder, expanded),
        AnimatedSize(
          duration: motionNormal(context),
          curve: motionCurve(context),
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: expanded && projects.isNotEmpty
              ? _buildFolderTree(context, l10n, grouping, projects)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// 文件夹展开后的现代轻量缩进项目区。
  ///
  /// 66 号外观升级：恢复 62-folder-nav.md §6.1 的 des-2 渐变树状引导线
  /// （此前退化为纯缩进）。竖线位于缩进后内容区左缘，自上而下由淡到浓，
  /// 与任务树的贝塞尔引导线呼应同一「层级连线」母题。
  Widget _buildFolderTree(
    BuildContext context,
    AppLocalizations l10n,
    ProjectGrouping grouping,
    List<Project> projects,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTokens.folderTreeIndent),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FolderRailPainter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < projects.length; i++)
                _buildProjectRow(
                  context,
                  l10n,
                  projects[i],
                  grouping,
                  indent: 0,
                  rowSpacing: AppTokens.folderTreeRowSpacing.toDouble(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 文件夹行：[文件夹图标] 名称 [汇总未完成数] [⋯ 菜单(仅展开)] [展开微箭头]。
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
          size: 18,
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
              await repo.moveProjectToFolder(
                data.substring(_projectDragPrefix.length),
                folderId: folder.id,
                newIndex: grouping.countInFolder(folder.id),
              );
            } else if (data.startsWith(_folderDragPrefix)) {
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

  /// 文件夹行内容（紧凑行高 + 微旋转箭头）。
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
        vertical: 1.5,
      ),
      child: Material(
        color: highlight ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusList),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          onTap: () =>
              ref.read(folderExpandProvider.notifier).toggle(folder.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: 6.5,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    folder.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: AppTokens.textFootnoteSize,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                // 汇总未完成数
                _FolderUncompletedBadge(folderId: folder.id),
                if (expanded) ...[
                  const SizedBox(width: AppTokens.spaceXs),
                  SizedBox.square(
                    dimension: 18,
                    child: PopupMenuButton<String>(
                      tooltip: l10n.folderActions,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert,
                        size: 16,
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
                  ),
                ],
                const SizedBox(width: AppTokens.spaceXxs),
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_left,
                  size: AppTokens.expandArrowSize,
                  color: colorScheme.onSurfaceVariant,
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
  /// [rowSpacing]：行垂直间距（树状区用更紧凑的 [AppTokens.folderTreeRowSpacing]，
  /// 其余用全局 [AppTokens.drawerRowSpacing]）。
  /// 拖拽（§6.2）：项目行可拖拽（入夹/出夹/组内重排），同时作为同组
  /// 项目行的重排落点（跨组落点同样按目标组内索引插入）。
  Widget _buildProjectRow(
    BuildContext context,
    AppLocalizations l10n,
    Project project,
    ProjectGrouping grouping, {
    required double indent,
    double rowSpacing = AppTokens.drawerRowSpacing,
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
          rowSpacing: rowSpacing,
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
            rowSpacing: rowSpacing,
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
    double rowSpacing = 2.0,
    bool isDragTarget = false,
    bool isInvalidDragTarget = false,
    bool isDragging = false,
  }) {
    final path = GoRouterState.of(context).uri.path;
    return _DrawerTile(
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Color(project.color),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(project.color).withValues(alpha: 0.35),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      title: project.name,
      trailing: _ProjectUncompletedBadge(projectId: project.id),
      selected: path == '/projects/${project.id}',
      onTap: () => _go(context, '/projects/${project.id}'),
      indent: indent,
      rowSpacing: rowSpacing,
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
            6,
            AppTokens.spaceMd,
            2,
          ),
          child: Material(
            color: highlight ?? Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXxs,
                vertical: 2,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.ungrouped,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppTokens.textMicroSize,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
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

  /// 关闭抽屉（如果是抽屉模式）并切换到目标路由（路由不变，仅入口位置变化）。
  void _go(BuildContext context, String path) {
    if (widget.isDrawer) {
      if (_navigating) return;
      _navigating = true;
      Navigator.of(context).pop();
    }
    context.go(path);
  }

  /// 打开新建自定义视图（抽屉模式关闭抽屉后 push /custom_view/new；宽屏模式弹出右侧透明模态抽屉）。
  void _openNewCustomView(BuildContext context) {
    if (widget.isDrawer) {
      if (_navigating) return;
      _navigating = true;
      Navigator.of(context).pop();
      context.push('/custom_view/new');
    } else {
      showCustomViewEditorSideSheet(context);
    }
  }

  /// 打开设置（抽屉模式关闭抽屉后 push 全屏页；宽屏模式弹出右侧透明模态抽屉）。
  void _openSettings(BuildContext context) {
    if (widget.isDrawer) {
      if (_navigating) return;
      _navigating = true;
      Navigator.of(context).pop();
      context.push('/settings');
    } else {
      showSettingsSideSheet(context);
    }
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
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.indent = 0,
    this.rowSpacing = 2.0,
    this.dragHighlightColor,
  });

  final Widget leading;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  /// 额外左缩进（文件夹下项目行）。
  final double indent;

  /// 行垂直间距。
  final double rowSpacing;

  /// 拖拽目标高亮。
  final Color? dragHighlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final selectedBg = isDark
        ? colorScheme.primary.withValues(alpha: 0.16)
        : colorScheme.primary.withValues(alpha: 0.10);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTokens.spaceXs + indent,
        rowSpacing / 2,
        AppTokens.spaceXs,
        rowSpacing / 2,
      ),
      child: Material(
        color:
            dragHighlightColor ?? (selected ? selectedBg : Colors.transparent),
        borderRadius: BorderRadius.circular(AppTokens.radiusList),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: 6.5,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: AppTokens.textFootnoteSize,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

/// 项目未完成任务数独立轻量微型徽章（阻断侧边栏重绘传播）。
class _ProjectUncompletedBadge extends ConsumerWidget {
  const _ProjectUncompletedBadge({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(projectSummaryProvider(projectId)).uncompletedCount;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        border: Border.all(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleLight,
          width: 0.5,
        ),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: AppTokens.textMicroSize,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 文件夹汇总未完成数独立轻量微型徽章（阻断侧边栏重绘传播）。
class _FolderUncompletedBadge extends ConsumerWidget {
  const _FolderUncompletedBadge({required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouping = ref.watch(projectsByFolderProvider).value;
    final projects = grouping?.folderProjects[folderId] ?? const <Project>[];
    var sum = 0;
    for (final p in projects) {
      sum += ref.watch(projectSummaryProvider(p.id)).uncompletedCount;
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        border: Border.all(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleLight,
          width: 0.5,
        ),
      ),
      child: Text(
        '$sum',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: AppTokens.textMicroSize,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 文件夹树渐变引导线（62-folder-nav.md §6.1 des-2，66 号恢复）。
///
/// 竖向细线，自上而下 alpha 从 [AppTokens.folderTreeLineAlphaStart]
/// 渐变到 [AppTokens.folderTreeLineAlphaEnd]；圆头笔画。
class _FolderRailPainter extends CustomPainter {
  const _FolderRailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final paint = Paint()
      ..strokeWidth = AppTokens.folderTreeLineWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: AppTokens.folderTreeLineAlphaStart),
          color.withValues(alpha: AppTokens.folderTreeLineAlphaEnd),
        ],
      ).createShader(Offset.zero & size);
    final x = size.width / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _FolderRailPainter oldDelegate) =>
      oldDelegate.color != color;
}
