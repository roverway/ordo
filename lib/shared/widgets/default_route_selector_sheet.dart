import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/custom_views/widgets/icon_picker_dialog.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/preset_icons.dart';
import '../../features/custom_views/providers/custom_view_providers.dart';
import '../../features/projects/project_providers.dart';
import '../../features/settings/settings_providers.dart';

/// 呼出设置任务清单按钮默认跳转目标的 Linear 风格弹层。
Future<void> showDefaultTasksRouteSelectorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _DefaultRouteSelectorSheet(isTasksGroup: true),
  );
}

/// 呼出设置特殊视图按钮默认跳转目标的 Linear 风格弹层。
Future<void> showDefaultSpecialViewsRouteSelectorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _DefaultRouteSelectorSheet(isTasksGroup: false),
  );
}

class _DefaultRouteSelectorSheet extends ConsumerWidget {
  const _DefaultRouteSelectorSheet({required this.isTasksGroup});

  final bool isTasksGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isZh = l10n.localeName.startsWith('zh');

    final title = isTasksGroup
        ? (isZh ? '设置默认任务清单' : 'Set Default Task List')
        : (isZh ? '设置默认特殊视图' : 'Set Default Special View');
    final tip = isZh
        ? '长按底部按钮可随时更换默认直达目标'
        : 'Long press bottom button to change default destination';

    final currentDefault = isTasksGroup
        ? ref.watch(defaultTasksRouteProvider)
        : ref.watch(defaultSpecialViewsRouteProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppTokens.sheetTopBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTokens.alphaTintStrong),
            blurRadius: 36,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部抓手
            Center(
              child: Container(
                width: AppTokens.sheetGrabberWidth,
                height: AppTokens.sheetGrabberHeight,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(
                    alpha: AppTokens.alphaTintStrong,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTokens.sheetGrabberRadius,
                  ),
                ),
              ),
            ),

            // 标题与提示文案
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip,
                    style: TextStyle(
                      fontSize: AppTokens.textFootnoteSize,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 选项列表
            Flexible(
              child: isTasksGroup
                  ? _buildTasksGroupList(
                      context,
                      ref,
                      currentDefault,
                      l10n,
                      isZh,
                    )
                  : _buildViewsGroupList(
                      context,
                      ref,
                      currentDefault,
                      l10n,
                      isZh,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksGroupList(
    BuildContext context,
    WidgetRef ref,
    String currentSelected,
    AppLocalizations l10n,
    bool isZh,
  ) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final fallbackSubtitle = isZh ? '默认兜底' : 'Default fallback';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // 今日 (默认兜底)
        _buildOptionTile(
          context: context,
          ref: ref,
          icon: Icons.wb_sunny_outlined,
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
          icon: Icons.inbox_outlined,
          iconColor: AppTokens.colorNavInbox,
          title: l10n.inbox,
          route: '/inbox',
          isSelected: currentSelected == '/inbox',
        ),

        // 项目清单列表
        projectsAsync.maybeWhen(
          data: (projects) {
            final regularProjects = projects
                .where((p) => p.id != inboxProjectId)
                .toList();
            if (regularProjects.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Text(
                    l10n.listsSection,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final project in regularProjects)
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
                  ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          icon: Icons.calendar_month_outlined,
          iconColor: AppTokens.colorNavCalendar,
          title: l10n.navCalendar,
          route: '/calendar',
          isSelected: currentSelected == '/calendar',
        ),
        // 概览
        _buildOptionTile(
          context: context,
          ref: ref,
          icon: Icons.pie_chart_outline_rounded,
          iconColor: AppTokens.colorNavOverview,
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: AppTokens.alphaTintFaint)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusItem),
          onTap: () async {
            HapticFeedback.selectionClick();
            if (isTasksGroup) {
              await ref
                  .read(defaultTasksRouteProvider.notifier)
                  .setDefaultTasksRoute(route);
            } else {
              await ref
                  .read(defaultSpecialViewsRouteProvider.notifier)
                  .setDefaultSpecialViewsRoute(route);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(
                      alpha: AppTokens.alphaBorderSubtle,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusList),
                  ),
                  child: Icon(icon, color: iconColor, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: AppTokens.textMicroSize,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
