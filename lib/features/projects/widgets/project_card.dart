import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../tasks/task_providers.dart';

/// 项目卡片（50-ui-ux.md §5.3）：颜色圆点 + 名称 + 未完成任务数 + 进度条。
///
/// MIUI/HyperOS 风格：squircle 圆角 + 弹簧动效。
class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.project, this.onTap});

  final Project project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final uncompleted = ref.watch(projectUncompletedCountProvider(project.id));
    final projectProgress = ref.watch(projectProgressProvider(project.id));
    final tasksAsync = ref.watch(projectTasksProvider(project.id));
    final totalCount = tasksAsync.when(
      data: (tasks) => tasks.length,
      loading: () => 0,
      error: (_, _) => 0,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Row(
            children: [
              // 颜色圆点。
              Container(
                width: AppTokens.spaceLg,
                height: AppTokens.spaceLg,
                decoration: BoxDecoration(
                  color: Color(project.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              // 名称 + 进度信息。
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTokens.spaceXxs),
                    Text(
                      l10n.tasksRemaining(uncompleted),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceXs),
                    // 进度条。
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.spaceXxs),
                      child: LinearProgressIndicator(
                        value: projectProgress,
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          projectProgress >= 1.0
                              ? AppTokens.colorDone
                              : AppTokens.colorInProgress,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 任务总数角标。
              if (totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceXs,
                    vertical: AppTokens.spaceXxs,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                  ),
                  child: Text(
                    '$totalCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
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
}
