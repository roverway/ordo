import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/preset_icons.dart';
import '../../features/custom_views/providers/custom_view_providers.dart';
import '../../features/custom_views/widgets/icon_picker_dialog.dart';
import '../../features/projects/project_providers.dart';
import '../../features/settings/settings_providers.dart';

/// 呼出设置任务清单按钮默认跳转目标的 Linear 风格浮动弹层。
Future<void> showDefaultTasksRouteSelectorSheet(BuildContext context) {
  return _showDefaultRouteSelectorDialog(context, isTasksGroup: true);
}

/// 呼出设置特殊视图按钮默认跳转目标的 Linear 风格浮动弹层。
Future<void> showDefaultSpecialViewsRouteSelectorSheet(BuildContext context) {
  return _showDefaultRouteSelectorDialog(context, isTasksGroup: false);
}

Future<void> _showDefaultRouteSelectorDialog(
  BuildContext context, {
  required bool isTasksGroup,
}) {
  final mediaQuery = MediaQuery.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bottomOffset = mediaQuery.padding.bottom + 68.0;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
    transitionDuration: AppTokens.motionFast,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            bottom: bottomOffset,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 380,
                  maxHeight: mediaQuery.size.height * 0.65,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTokens.surfaceCardDark.withValues(
                                  alpha: AppTokens.alphaCardFrostedDark,
                                )
                              : AppTokens.surfaceCardLight.withValues(
                                  alpha: AppTokens.alphaCardFrostedLight,
                                ),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusSheet,
                          ),
                          border: Border.all(
                            color: isDark
                                ? AppTokens.borderSubtleDark
                                : AppTokens.borderSubtleLight,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark
                                    ? AppTokens.alphaBorderEmphasis
                                    : AppTokens.alphaBorderSubtle,
                              ),
                              blurRadius: 32,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: DefaultRouteSelectorContent(
                          isTasksGroup: isTasksGroup,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      );
    },
  );
}

class DefaultRouteSelectorContent extends ConsumerStatefulWidget {
  const DefaultRouteSelectorContent({super.key, required this.isTasksGroup});

  final bool isTasksGroup;

  @override
  ConsumerState<DefaultRouteSelectorContent> createState() =>
      _DefaultRouteSelectorContentState();
}

class _DefaultRouteSelectorContentState
    extends ConsumerState<DefaultRouteSelectorContent> {
  final Set<String> _expandedFolderIds = <String>{};
  bool _foldersInitialized = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isZh = l10n.localeName.startsWith('zh');

    final title = widget.isTasksGroup
        ? (isZh ? '设置默认任务清单' : 'Set Default Task List')
        : (isZh ? '设置默认特殊视图' : 'Set Default Special View');
    final tip = isZh
        ? '长按底部按钮随时更换默认直达目标'
        : 'Long press bottom button to change default destination';

    final currentDefault = widget.isTasksGroup
        ? ref.watch(defaultTasksRouteProvider)
        : ref.watch(defaultSpecialViewsRouteProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 浮动头部提示区
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: AppTokens.textMicroSize,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
                color: colorScheme.onSurfaceVariant,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 选项列表
        Flexible(
          child: widget.isTasksGroup
              ? _buildTasksGroupTree(context, ref, currentDefault, l10n, isZh)
              : _buildViewsGroupList(context, ref, currentDefault, l10n, isZh),
        ),
      ],
    );
  }

  Widget _buildTasksGroupTree(
    BuildContext context,
    WidgetRef ref,
    String currentSelected,
    AppLocalizations l10n,
    bool isZh,
  ) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);
    final fallbackSubtitle = isZh ? '默认兜底' : 'Default fallback';

    final folders = foldersAsync.value ?? const <Folder>[];
    if (!_foldersInitialized && folders.isNotEmpty) {
      _expandedFolderIds.addAll(folders.map((f) => f.id));
      _foldersInitialized = true;
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      children: [
        // 今日 (默认兜底)
        _buildOptionTile(
          context: context,
          ref: ref,
          icon: Icons.today_rounded,
          iconColor: AppTokens.colorNavToday,
          title: l10n.navToday,
          subtitle: fallbackSubtitle,
          route: '/today',
          isSelected: currentSelected == '/today' || currentSelected == '/',
        ),
        // 收件箱
        _buildOptionTile(
          context: context,
          ref: ref,
          icon: Icons.inbox_rounded,
          iconColor: AppTokens.colorNavInbox,
          title: l10n.inbox,
          route: '/inbox',
          isSelected: currentSelected == '/inbox',
        ),

        // 文件夹与项目清单树（复用 ScopeNavContent 树状外观）
        projectsAsync.maybeWhen(
          data: (projects) {
            final regularProjects = projects
                .where((p) => p.id != inboxProjectId)
                .toList();
            if (regularProjects.isEmpty && folders.isEmpty) {
              return const SizedBox.shrink();
            }

            final ungroupedProjects = regularProjects
                .where((p) => p.folderId == null)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: Text(
                    l10n.listsSection,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // 各文件夹分组树
                for (final folder in folders) ...[
                  _buildFolderItem(
                    folder: folder,
                    projects: regularProjects
                        .where((p) => p.folderId == folder.id)
                        .toList(),
                    currentSelected: currentSelected,
                  ),
                ],

                // 未分组清单
                if (ungroupedProjects.isNotEmpty) ...[
                  if (folders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                      child: Text(
                        l10n.ungrouped,
                        style: TextStyle(
                          fontSize: AppTokens.textMicroSize,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final project in ungroupedProjects)
                    _buildOptionTile(
                      context: context,
                      ref: ref,
                      icon: getIconDataById(
                        project.icon,
                        fallback: Icons.format_list_bulleted_rounded,
                      ),
                      iconColor: Color(project.color),
                      title: project.name,
                      route: '/projects/${project.id}',
                      isSelected: currentSelected == '/projects/${project.id}',
                      indent: folders.isNotEmpty ? 12 : 0,
                    ),
                ],
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildFolderItem({
    required Folder folder,
    required List<Project> projects,
    required String currentSelected,
  }) {
    final theme = Theme.of(context);
    final isExpanded = _expandedFolderIds.contains(folder.id);
    final folderColor = folder.color != null
        ? Color(folder.color!)
        : AppTokens.colorNavInbox;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isExpanded) {
                _expandedFolderIds.remove(folder.id);
              } else {
                _expandedFolderIds.add(folder.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0.0,
                  duration: AppTokens.motionFast,
                  child: Icon(
                    Icons.arrow_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  getIconDataById(folder.icon, fallback: Icons.folder_rounded),
                  size: 16,
                  color: folderColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    folder.name,
                    style: TextStyle(
                      fontSize: AppTokens.textSecondarySize,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${projects.length}',
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          for (final project in projects)
            _buildOptionTile(
              context: context,
              ref: ref,
              icon: getIconDataById(
                project.icon,
                fallback: Icons.format_list_bulleted_rounded,
              ),
              iconColor: Color(project.color),
              title: project.name,
              route: '/projects/${project.id}',
              isSelected: currentSelected == '/projects/${project.id}',
              indent: 20,
            ),
      ],
    );
  }

  Widget _buildViewsGroupList(
    BuildContext context,
    WidgetRef ref,
    String currentSelected,
    AppLocalizations l10n,
    bool isZh,
  ) {
    final customViewsAsync = ref.watch(customViewsStreamProvider);
    final fallbackSubtitle = isZh ? '默认兜底' : 'Default fallback';

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      children: [
        // 四象限 (默认兜底)
        _buildOptionTile(
          context: context,
          ref: ref,
          icon: Icons.grid_view_rounded,
          iconColor: AppTokens.colorNavQuadrant,
          title: l10n.navQuadrant,
          subtitle: fallbackSubtitle,
          route: '/matrix',
          isSelected: currentSelected == '/matrix',
        ),
        // 日历
        _buildOptionTile(
          context: context,
          ref: ref,
          icon: Icons.calendar_month_rounded,
          iconColor: AppTokens.colorNavCalendar,
          title: l10n.navCalendar,
          route: '/calendar',
          isSelected: currentSelected == '/calendar',
        ),
        // 概览
        _buildOptionTile(
          context: context,
          ref: ref,
          icon: Icons.view_agenda_rounded,
          iconColor: Theme.of(context).colorScheme.primary,
          title: l10n.overview,
          route: '/projects',
          isSelected: currentSelected == '/projects',
        ),

        // 自定义视图列表
        customViewsAsync.maybeWhen(
          data: (views) {
            if (views.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: Text(
                    l10n.customViews,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final cv in views)
                  _buildOptionTile(
                    context: context,
                    ref: ref,
                    icon: getCustomViewIcon(cv.icon),
                    iconColor: Color(cv.color),
                    title: cv.name,
                    route: '/custom_view/${cv.id}',
                    isSelected: currentSelected == '/custom_view/${cv.id}',
                  ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required String route,
    required bool isSelected,
    double indent = 0,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        onTap: () {
          HapticFeedback.selectionClick();
          if (widget.isTasksGroup) {
            ref
                .read(defaultTasksRouteProvider.notifier)
                .setDefaultTasksRoute(route);
          } else {
            ref
                .read(defaultSpecialViewsRouteProvider.notifier)
                .setDefaultSpecialViewsRoute(route);
          }
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppTokens.textSecondarySize,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppTokens.textMicroSize,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 18, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
