import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../../shared/widgets/desktop_hover_container.dart';
import '../../tasks/task_providers.dart';

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
    final projectColor = Color(widget.project.color);

    final uncompleted = ref.watch(
      projectUncompletedCountProvider(widget.project.id),
    );
    final projectProgress = ref.watch(
      projectProgressProvider(widget.project.id),
    );
    final tasksAsync = ref.watch(projectTasksProvider(widget.project.id));
    final totalCount = tasksAsync.when(
      data: (tasks) => tasks.length,
      loading: () => 0,
      error: (_, _) => 0,
    );

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
                // Color indicator — soft dot.
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: projectColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
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
                            minHeight: 3,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
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
                      vertical: AppTokens.spaceXxs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                    ),
                    child: Text(
                      '$totalCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
