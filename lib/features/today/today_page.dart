import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../projects/project_providers.dart';
import '../tasks/widgets/task_create_sheet.dart';
import 'today_providers.dart';

/// 今日视图（FR-VIEW-01，docs/10-requirements.md §9.1/§9.3）。
///
/// 逾期组（endAt 升序）+ 今天组（startAt 升序）；组为空不显示组标题；
/// 全部为空显示 EmptyState（沿用 stub 现状）。
/// 右下角 FAB → 滴答式新建任务底部弹窗（D2 定稿，55-ui-redesign §4.1）。
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewAsync = ref.watch(todayViewProvider);

    return AppShell(
      title: l10n.navToday,
      child: Stack(
        children: [
          Positioned.fill(
            child: viewAsync.when(
              data: (view) {
                if (view.isEmpty) {
                  return EmptyState(
                    icon: Icons.today_outlined,
                    message: l10n.emptyToday,
                  );
                }
                return _buildList(context, ref, view);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
          // FAB：新建任务底部弹窗（缺省 projectId → 内置收件箱，des-3 幂等）。
          Positioned(
            right: AppTokens.spaceMd,
            bottom: AppTokens.spaceMd,
            child: FloatingActionButton(
              tooltip: l10n.newTask,
              onPressed: () => TaskCreateSheet.show(context),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, TodayViewData view) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);
    final todayHeaderColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      // 卡片行（SimpleTaskTile）不内置水平 margin，由列表提供页面留白。
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      children: [
        if (view.overdue.isNotEmpty) ...[
          _SectionHeader(title: l10n.overdue, color: AppTokens.colorOverdue),
          for (final v in view.overdue) _buildTile(context, repo, v),
        ],
        if (view.today.isNotEmpty) ...[
          _SectionHeader(title: l10n.today, color: todayHeaderColor),
          for (final v in view.today) _buildTile(context, repo, v),
        ],
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    TodoRepository repo,
    TodayTaskView view,
  ) {
    final task = view.task;
    return SimpleTaskTile(
      task: task,
      hasChildren: view.hasChildren,
      isDone: view.effectiveStatus == TaskStatus.done,
      isOverdue: view.isOverdue,
      tags: view.tags,
      progressValue: view.progressValue,
      onTap: () => context.push('/task/${task.id}'),
      onToggleDone: view.hasChildren
          ? null
          : (_) => repo.updateTask(
              task.id,
              status: view.effectiveStatus == TaskStatus.done
                  ? TaskStatus.todo
                  : TaskStatus.done,
            ),
    );
  }
}

/// 分组标题：逾期组红色（[AppTokens.colorOverdue]），今天组弱色。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceMd,
        AppTokens.spaceMd,
        AppTokens.spaceMd,
        AppTokens.spaceXs,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: AppTokens.textTitleWeight,
        ),
      ),
    );
  }
}
