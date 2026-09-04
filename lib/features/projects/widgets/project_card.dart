import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../shared/widgets/desktop_hover_container.dart';
import '../../tasks/task_providers.dart';
import '../../../core/theme/preset_icons.dart';

/// Project card — clean, minimal card with color dot, name, progress.
///
/// 66 号外观升级：与任务卡/看板卡统一为「细边框 + 双层弥散阴影」的
/// [DesktopHoverContainer] 语言；保留按压 scale 微反馈（63 §5 H）。
class ProjectCard extends ConsumerStatefulWidget {
  const ProjectCard({super.key, required this.project, this.onTap});

  final Project project;
  final VoidCallback? onTap;

  @override
  ConsumerState<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<ProjectCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final projectColor = Color(widget.project.color);

    final summary = ref.watch(projectSummaryProvider(widget.project.id));
    final uncompleted = summary.uncompletedCount;
    final projectProgress = summary.progress;
    final totalCount = summary.totalCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
      child: Listener(
        onPointerDown: (_) {
          if (mounted) setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (mounted) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (mounted) setState(() => _pressed = false);
        },
        child: AnimatedScale(
          scale: _pressed ? AppTokens.cardPressScale : 1,
          duration: motionFast(context),
          curve: motionCurve(context),
          child: DesktopHoverContainer(
            onTap: widget.onTap,
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            child: Row(
              children: [
                // 彩色 Squircle 容器图标徽标
                Container(
                  width: AppTokens.projectBadgeSize,
                  height: AppTokens.projectBadgeSize,
                  decoration: BoxDecoration(
                    color: projectColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(
                      AppTokens.projectBadgeRadius,
                    ),
                    border: Border.all(
                      color: projectColor.withValues(
                        alpha: isDark ? 0.35 : 0.22,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      getIconDataById(
                        widget.project.icon,
                        fallback: Icons.format_list_bulleted_rounded,
                      ),
                      size: 20,
                      color: projectColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceMd),
                // Name + metadata.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (totalCount > 0) ...[
                        const SizedBox(height: AppTokens.spaceXxs),
                        Text(
                          l10n.tasksRemaining(uncompleted),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceXs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTokens.spaceXxs,
                          ),
                          child: LinearProgressIndicator(
                            value: projectProgress,
                            minHeight: 4,
                            backgroundColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              projectProgress >= 1.0
                                  ? AppTokens.colorDone
                                  : projectColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Task count badge.
                if (totalCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceXs,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: projectColor.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                      border: Border.all(
                        color: projectColor.withValues(
                          alpha: isDark ? 0.30 : 0.20,
                        ),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      uncompleted > 0 ? '$uncompleted' : '$totalCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: projectColor,
                        fontSize: AppTokens.textMicroSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: AppTokens.spaceXs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
