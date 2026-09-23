import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../tasks/widgets/task_create_sheet.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';
import 'quadrant_task_tile.dart';

/// 统一四象限矩阵中的单个象限单元格组件。
///
/// 遵循极简高信噪比规范与设计原型：
/// 1. 去卡片化单元格：不再包含独立的圆角、外边框与外阴影，直接由统一容器及中心两条相交直线界定；
/// 2. 紧凑头部：高度 38dp，左侧语义色条 + 强化加粗象限完整名称 + 语义色数字圆角徽标 + 右侧微型聚焦与新增按钮；
/// 3. 发丝级分割线：头部与任务列表间使用 0.5dp 细分割线；
/// 4. 任务列表：支持无边框轻量条目与独立纵向滚动；
/// 5. 跨象限拖拽交互：作为 [DragTarget] 接收其他象限拖入的任务，悬停时触发半透明语义色高亮反馈；
/// 6. 点击新增：直接调起全局 [TaskCreateSheet.show] 并预填优先级与截止日期。
class QuadrantCard extends ConsumerWidget {
  const QuadrantCard({
    super.key,
    required this.quadrantType,
    required this.tasks,
    this.onFocus,
  });

  final QuadrantType quadrantType;
  final List<QuadrantTaskView> tasks;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(quadrantFilterProvider);
    final accentColor = quadrantType.accentColor;

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: AppTokens.alphaBorderSubtle)
        : AppTokens.surfaceSubtleLight;

    return DragTarget<QuadrantTaskView>(
      onWillAcceptWithDetails: (details) =>
          details.data.quadrant != quadrantType,
      onAcceptWithDetails: (details) async {
        await ref
            .read(quadrantActionControllerProvider)
            .moveTaskToQuadrant(details.data.task, quadrantType);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        final cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 紧凑卡片头部 (38dp)
            _buildCompactHeader(
              context: context,
              ref: ref,
              colorScheme: colorScheme,
              isDark: isDark,
              l10n: l10n,
              accentColor: accentColor,
              filter: filter,
            ),

            Divider(height: 0.5, thickness: 0.5, color: dividerColor),

            // 任务列表或精炼空状态
            Expanded(
              child: tasks.isEmpty
                  ? _buildEmptyPlaceholder(
                      context: context,
                      ref: ref,
                      colorScheme: colorScheme,
                      l10n: l10n,
                      accentColor: accentColor,
                      filter: filter,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: tasks.length,
                      itemBuilder: (context, index) => QuadrantTaskTile(
                        taskView: tasks[index],
                        showDivider: index < tasks.length - 1,
                      ),
                    ),
            ),
          ],
        );

        return AnimatedContainer(
          duration: AppTokens.motionFast,
          color: isHovered
              ? accentColor.withValues(
                  alpha: isDark
                      ? AppTokens.alphaTintStrong
                      : AppTokens.alphaTintFaint,
                )
              : Colors.transparent,
          child: cardContent,
        );
      },
    );
  }

  Widget _buildCompactHeader({
    required BuildContext context,
    required WidgetRef ref,
    required ColorScheme colorScheme,
    required bool isDark,
    required AppLocalizations l10n,
    required Color accentColor,
    required QuadrantFilterState filter,
  }) {
    final title = quadrantType.title(l10n);
    final badgeBg = quadrantType.badgeBackgroundColor(context);
    final badgeText = quadrantType.badgeTextColor(context);

    return SizedBox(
      height: 38,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXxs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 纵向语义色条 (3.5x13dp)
            Container(
              width: 3.5,
              height: 13,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(
                  AppTokens.sheetGrabberRadius,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceXs),

            // 象限名称：完整展示并加粗强调
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTokens.textFootnoteSize,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppTokens.textPrimaryDark
                    : AppTokens.textPrimaryLight,
              ),
            ),
            const SizedBox(width: AppTokens.spaceXxs),

            // 紧凑圆角数量徽标
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs * 0.75,
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(AppTokens.radiusItem),
              ),
              child: Text(
                '${tasks.length}',
                style: TextStyle(
                  fontSize: AppTokens.textNanoSize,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTokens.fontTabular,
                  color: badgeText,
                ),
              ),
            ),

            const Spacer(),

            // 缩小在右侧的聚焦与添加按钮 (22x22 紧凑按钮)
            if (onFocus != null) ...[
              _buildMiniHeaderButton(
                tooltip: l10n.quadrantFocusMode,
                icon: Icons.fullscreen_outlined,
                iconSize: 15,
                color: colorScheme.onSurfaceVariant,
                onTap: onFocus!,
              ),
              const SizedBox(width: AppTokens.spaceMicro),
            ],

            _buildMiniHeaderButton(
              tooltip: l10n.quadrantAddTask,
              icon: Icons.add_rounded,
              iconSize: 16,
              color: colorScheme.onSurfaceVariant,
              onTap: () => _openCreateTask(context, filter),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniHeaderButton({
    required String tooltip,
    required IconData icon,
    required double iconSize,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
        onTap: onTap,
        child: SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder({
    required BuildContext context,
    required WidgetRef ref,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
    required Color accentColor,
    required QuadrantFilterState filter,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: AppTokens.alphaTintFaint),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.inbox_outlined, size: 16, color: accentColor),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              l10n.quadrantEmpty,
              style: TextStyle(
                fontSize: AppTokens.textMicroSize,
                color: colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTokens.alphaContentMuted,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusList),
              onTap: () => _openCreateTask(context, filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceXs,
                  vertical: AppTokens.spaceXxs,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: AppTokens.alphaBorderEmphasis,
                    ),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusList),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppTokens.spaceMicro),
                    Text(
                      l10n.quadrantAddTask,
                      style: TextStyle(
                        fontSize: AppTokens.textMicroSize,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateTask(BuildContext context, QuadrantFilterState filter) {
    final now = DateTime.now();
    TaskCreateSheet.show(
      context,
      initialPriority: quadrantType.initialPriority,
      initialEndAt: quadrantType.initialEndAt(now),
      projectId: filter.selectedProjectIds?.length == 1
          ? filter.selectedProjectIds!.first
          : null,
    );
  }
}
