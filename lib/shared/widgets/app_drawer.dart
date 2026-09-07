import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/preset_icons.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/motion.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../features/custom_views/presentation/custom_view_editor_page.dart';
import '../../features/custom_views/providers/custom_view_providers.dart';
import '../../features/custom_views/widgets/icon_picker_dialog.dart';
import '../../features/projects/project_providers.dart';
import '../../features/projects/widgets/create_list_folder_sheet.dart';
import '../../features/settings/widgets/settings_side_sheet.dart';
import '../../features/sync_setup/sync_setup_providers.dart';
import '../../features/tasks/task_providers.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'app_logo.dart';
import 'app_menu_item.dart';
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
        <
          ({
            String path,
            IconData icon,
            IconData selectedIcon,
            String label,
            Color accentColor,
          })
        >[
          (
            path: '/today',
            icon: Icons.today_outlined,
            selectedIcon: Icons.today,
            label: l10n.navToday,
            accentColor: AppTokens.colorNavToday,
          ),
          (
            path: '/inbox',
            icon: Icons.inbox_outlined,
            selectedIcon: Icons.inbox,
            label: l10n.navInbox,
            accentColor: AppTokens.colorNavInbox,
          ),
          (
            path: '/calendar',
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_today,
            label: l10n.navCalendar,
            accentColor: AppTokens.colorNavCalendar,
          ),
        ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 顶部品牌区 ──
          Padding(
            padding: const EdgeInsets.only(left: 24.0, top: 32.0, bottom: 20.0),
            child: Row(
              children: [
                const AppLogo(size: 36, borderRadius: 10),
                const SizedBox(width: 12),
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
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
                      color: item.accentColor,
                    ),
                    title: item.label,
                    selected: path == item.path,
                    accentColor: item.accentColor,
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
          const Divider(height: 1, thickness: 0.6),
          // ── 底部：「新建文件夹」+「新建项目」+ 设置 ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DrawerTile(
                  leading: Icon(
                    Icons.create_new_folder_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: l10n.newFolder,
                  selected: false,
                  onTap: () => _showNewFolderDialog(context, ref),
                ),
                _DrawerTile(
                  leading: Icon(
                    Icons.add,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: l10n.newProject,
                  selected: false,
                  onTap: () => _showNewProjectDialog(context, ref),
                ),
                _DrawerTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: l10n.settings,
                  selected: false,
                  onTap: () => _openSettings(context),
                ),
              ],
            ),
          ),
          // ── 同步状态栏 ──
          _buildSyncStatusBar(context),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBar(BuildContext context) {
    final syncConfigAsync = ref.watch(syncConfigProvider);
    final syncState = ref.watch(syncStateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final isSyncEnabled = syncConfigAsync.value?.enabled ?? false;
    if (!isSyncEnabled) return const SizedBox.shrink();

    Widget statusIcon;
    String statusText;
    Color textColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    switch (syncState.status) {
      case SyncStateStatus.syncing:
        statusIcon = SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colorScheme.primary,
          ),
        );
        statusText = l10n.syncStatusSyncing;
        break;
      case SyncStateStatus.error:
        statusIcon = Icon(
          Icons.error_outline,
          color: colorScheme.error,
          size: 12,
        );
        statusText = l10n.syncStatusError;
        textColor = colorScheme.error;
        break;
      case SyncStateStatus.success:
      case SyncStateStatus.idle:
        statusIcon = const Icon(Icons.check, color: Colors.green, size: 12);
        final lastSynced = syncState.lastSyncedAt;
        if (lastSynced != null) {
          final diff = DateTime.now().millisecondsSinceEpoch - lastSynced;
          if (diff < 60000) {
            statusText = l10n.syncedJustNow;
          } else if (diff < 3600000) {
            statusText = l10n.syncedMinutesAgo(diff ~/ 60000);
          } else {
            statusText = l10n.syncedAt(formatDateTime(lastSynced));
          }
        } else {
          statusText = l10n.syncStatusIdle;
        }
        break;
    }

    final protocol = syncConfigAsync.value?.type == RemoteType.s3
        ? 'S3'
        : 'WebDAV';

    return Padding(
      padding: const EdgeInsets.only(left: 24.0, bottom: 16.0, top: 4.0),
      child: Row(
        children: [
          statusIcon,
          const SizedBox(width: 6),
          Text(
            '$protocol · $statusText',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: textColor,
            ),
          ),
        ],
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
              accentColor: Color(view.color),
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
          // 三点菜单：新建文件夹 / 项目总览（用户定稿：总览入口收进组头菜单，
          // 不占系统组位；竖排三点与文件夹行菜单方向一致）。
          SizedBox.square(
            dimension: 24,
            child: PopupMenuButton<String>(
              tooltip: l10n.moreOptions,
              icon: Icon(
                Icons.more_vert,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                switch (value) {
                  case 'newFolder':
                    _showNewFolderDialog(context, ref);
                  case 'overview':
                    _go(context, '/projects');
                }
              },
              itemBuilder: (context) => [
                AppMenuItem(
                  value: 'newFolder',
                  icon: Icons.create_new_folder_outlined,
                  label: l10n.newFolder,
                ),
                AppMenuItem(
                  value: 'overview',
                  icon: Icons.dashboard_outlined,
                  label: l10n.projectsOverview,
                ),
              ],
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
          for (var i = 0; i < grouping.ungrouped.length; i++) {
            final project = grouping.ungrouped[i];
            children.add(
              _buildProjectRow(
                context,
                l10n,
                project,
                grouping,
                indent: 0,
                isLastInTree: i == grouping.ungrouped.length - 1,
                isNested: true,
              ),
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

  /// 文件夹展开后的现代轻量缩进项目区（带树状竖线）。
  Widget _buildFolderTree(
    BuildContext context,
    AppLocalizations l10n,
    ProjectGrouping grouping,
    List<Project> projects,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Container(
      margin: const EdgeInsets.only(left: 20, top: 1, bottom: 4),
      padding: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
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
              isLastInTree: i == projects.length - 1,
              isNested: true,
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
    final folderColor = folder.color != null
        ? Color(folder.color!)
        : colorScheme.primary;
    final folderIcon = getIconDataById(
      folder.icon,
      fallback: Icons.folder_outlined,
    );

    return Container(
      margin: const EdgeInsets.only(
        top: AppTokens.drawerRowSpacing,
        bottom: AppTokens.drawerRowSpacing,
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
                Icon(folderIcon, size: 18, color: folderColor),
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
                        AppMenuItem(value: 'rename', label: l10n.renameFolder),
                        AppMenuItem(
                          value: 'delete',
                          label: l10n.deleteFolder,
                          destructive: true,
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
    bool isLastInTree = false,
    bool isNested = false,
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
          isLastInTree: isLastInTree,
          isNested: isNested,
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
            isLastInTree: isLastInTree,
            isNested: isNested,
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
    bool isLastInTree = false,
    bool isNested = false,
  }) {
    final path = GoRouterState.of(context).uri.path;
    return _DrawerTile(
      leading: isNested
          ? NestedProjectLeading(
              isLast: isLastInTree,
              color: Color(project.color),
            )
          : Container(
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
      trailing: _ProjectUncompletedBadge(
        projectId: project.id,
        accentColor: Color(project.color),
      ),
      selected: path == '/projects/${project.id}',
      accentColor: Color(project.color),
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
        await showEditFolderSheet(context, folder);
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
    await showCreateListFolderSheet(
      context: context,
      initialType: CreateType.list,
    );
  }

  Future<void> _showNewFolderDialog(BuildContext context, WidgetRef ref) async {
    await showCreateListFolderSheet(
      context: context,
      initialType: CreateType.folder,
    );
  }
}

/// 抽屉行：leading（图标/颜色圆点）+ 标题 + 可选 trailing（未完成数）。
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.accentColor,
    this.trailing,
    this.indent = 0,
    this.rowSpacing = 2.0,
    this.dragHighlightColor,
  });

  final Widget leading;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;
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
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.grey[100];

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
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
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
                      color: colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
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
  const _ProjectUncompletedBadge({required this.projectId, this.accentColor});

  final String projectId;
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(projectSummaryProvider(projectId)).uncompletedCount;

    final theme = Theme.of(context);
    return Text(
      '$count',
      style: theme.textTheme.labelMedium?.copyWith(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
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
    final sum = ref.watch(folderUncompletedCountProvider(folderId));

    final theme = Theme.of(context);
    return Text(
      '$sum',
      style: theme.textTheme.labelMedium?.copyWith(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
      ),
    );
  }
}

class NestedProjectLeading extends StatelessWidget {
  const NestedProjectLeading({
    super.key,
    required this.isLast,
    required this.color,
  });

  final bool isLast;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 36,
      child: CustomPaint(
        painter: _NestedProjectLeadingPainter(
          isLast: isLast,
          bulletColor: color,
          lineColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white24
              : Colors.black12,
        ),
      ),
    );
  }
}

class _NestedProjectLeadingPainter extends CustomPainter {
  _NestedProjectLeadingPainter({
    required this.isLast,
    required this.bulletColor,
    required this.lineColor,
  });

  final bool isLast;
  final Color bulletColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final bulletPaint = Paint()
      ..color = bulletColor
      ..style = PaintingStyle.fill;

    final double startX = 9.0;
    final double endX = 22.0;
    final double centerY = size.height / 2;

    // Draw vertical line
    if (isLast) {
      canvas.drawLine(Offset(startX, 0), Offset(startX, centerY), linePaint);
    } else {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX, size.height),
        linePaint,
      );
    }

    // Draw horizontal line branch
    canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), linePaint);

    // Draw bullet dot (circle)
    canvas.drawCircle(Offset(endX, centerY), 4.0, bulletPaint);
  }

  @override
  bool shouldRepaint(covariant _NestedProjectLeadingPainter oldDelegate) {
    return oldDelegate.isLast != isLast ||
        oldDelegate.bulletColor != bulletColor ||
        oldDelegate.lineColor != lineColor;
  }
}
