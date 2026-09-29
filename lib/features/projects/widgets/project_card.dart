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
/// 遵循乔布斯极简与 Linear 工业质感：
/// - 细微 1px 描边与精致圆角；
/// - 微型进度条高度收缩至 2.5dp（AppTokens.radiusMicro 圆角）；
/// - 右侧直接展示完成比率与等宽数字（12/15 · 80%）。
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
    final completedCount = totalCount - uncompleted;

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
                    color: projectColor.withValues(
                      alpha: isDark
                          ? AppTokens.alphaTintStrong
                          : AppTokens.alphaBorderSubtle,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppTokens.projectBadgeRadius,
                    ),
                    border: Border.all(
                      color: projectColor.withValues(
                        alpha: isDark
                            ? AppTokens.alphaBorderEmphasis
                            : AppTokens.alphaTintStrong,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.tasksRemaining(uncompleted),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: AppTokens.textMicroSize,
                              ),
                            ),
                            Text(
                              '$completedCount/$totalCount · ${(projectProgress * 100).round()}%',
                              style: TextStyle(
                                fontFeatures: AppTokens.fontTabular,
                                fontSize: AppTokens.textMicroSize,
                                fontWeight: FontWeight.w600,
                                color: projectProgress >= 1.0
                                    ? AppTokens.colorDone
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.spaceXs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMicro,
                          ),
                          child: LinearProgressIndicator(
                            value: projectProgress,
                            minHeight: 2.5,
                            backgroundColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: AppTokens.alphaContentMuted),
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
                const SizedBox(width: AppTokens.spaceXs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.outline.withValues(
                    alpha: AppTokens.alphaBorderEmphasis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
