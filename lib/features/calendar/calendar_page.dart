import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../../core/utils/view_rules.dart' as view_rules;
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../projects/project_providers.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_create_sheet.dart';
import 'calendar_providers.dart';

/// 日历视图（FR-VIEW-02，docs/10-requirements.md §9.2）。
///
/// - 顶栏：上一月/下一月 + 月份/周标题 + 月/周切换（SegmentedButton）+「今天」。
/// - 月视图：星期表头 + 7 列网格；日期格显示任务标题（≤2，超出 +n 徽标），
///   今天高亮（主色）、周末弱化、有任务的日子浅色背景 + 边框强调；整格可点。
/// - 周视图：周一至周日 7 天分区列表，每天任务行用 [SimpleTaskTile]。
/// - 点日期格：底部弹层（日期标题 + 新建入口 + 该日任务列表）。
///
/// 颜色/圆角/间距/动效一律走 AppTokens（AGENTS.md §3-9）；文案全部走 ARB。
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(calendarStateProvider);
    final bucketsAsync = ref.watch(calendarBucketsProvider);
    final allTasks = ref.watch(allActiveTasksProvider).value ?? const <Task>[];

    return AppShell(
      title: l10n.navCalendar,
      child: Column(
        children: [
          _buildToolbar(context, ref, state),
          Expanded(
            child: bucketsAsync.when(
              data: (buckets) {
                if (buckets.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_outlined,
                    message: l10n.emptyCalendar,
                  );
                }
                return state.mode == CalendarMode.month
                    ? _buildMonthGrid(context, ref, buckets, allTasks, state)
                    : _buildWeekList(context, ref, buckets, allTasks, state);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
    );
  }

  // ── 顶栏 ──────────────────────────────────────────────────────────

  Widget _buildToolbar(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = calendarRangeFor(state);
    final title = state.mode == CalendarMode.month
        ? _formatMonthTitle(context, state.selectedDate)
        : _formatWeekRange(context, range.start, range.end);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceSm,
        AppTokens.spaceXs,
        AppTokens.spaceMd,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.prevMonth,
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    ref.read(calendarStateProvider.notifier).prevMonth(),
              ),
              IconButton(
                tooltip: l10n.nextMonth,
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    ref.read(calendarStateProvider.notifier).nextMonth(),
              ),
              const SizedBox(width: AppTokens.spaceXs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppTokens.touchTarget),
                ),
                onPressed: () =>
                    ref.read(calendarStateProvider.notifier).goToToday(),
                child: Text(l10n.today),
              ),
            ],
          ),
          Row(
            children: [
              const Spacer(),
              SegmentedButton<CalendarMode>(
                segments: [
                  ButtonSegment(
                    value: CalendarMode.month,
                    label: Text(l10n.viewMonth),
                    icon: const Icon(
                      Icons.calendar_view_month_outlined,
                      size: 16,
                    ),
                  ),
                  ButtonSegment(
                    value: CalendarMode.week,
                    label: Text(l10n.viewWeek),
                    icon: const Icon(Icons.view_week_outlined, size: 16),
                  ),
                ],
                selected: {state.mode},
                onSelectionChanged: (_) =>
                    ref.read(calendarStateProvider.notifier).toggleView(),
                showSelectedIcon: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMonthTitle(BuildContext context, DateTime date) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return isZh
        ? intl.DateFormat('y年M月').format(date)
        : intl.DateFormat('MMMM yyyy').format(date);
  }

  String _formatWeekRange(BuildContext context, DateTime start, DateTime end) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final sameMonth = start.year == end.year && start.month == end.month;
    if (isZh) {
      return sameMonth
          ? '${intl.DateFormat('y年M月d日').format(start)} – '
                '${intl.DateFormat('d日').format(end)}'
          : '${intl.DateFormat('y年M月d日').format(start)} – '
                '${intl.DateFormat('y年M月d日').format(end)}';
    }
    return sameMonth
        ? '${intl.DateFormat('MMM d').format(start)} – '
              '${intl.DateFormat('d, y').format(end)}'
        : '${intl.DateFormat('MMM d, y').format(start)} – '
              '${intl.DateFormat('MMM d, y').format(end)}';
  }

  // ── 月视图 ─────────────────────────────────────────────────────────

  /// 月网格日期序列：当月 1 日前的空白格 + 当月天数，末尾补齐到整周。
  ///
  /// 越界日由 DateTime 构造器自动归一化到相邻月份（仅作占位，无任务）。
  List<DateTime> _monthGridDays(DateTime selected) {
    final first = DateTime(selected.year, selected.month, 1);
    final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final total = leading + daysInMonth;
    final padded = (total / 7).ceil() * 7;
    return [
      for (var i = 0; i < padded; i++)
        DateTime(selected.year, selected.month, i - leading + 1),
    ];
  }

  Widget _buildMonthGrid(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    List<Task> allTasks,
    CalendarState state,
  ) {
    final selected = state.selectedDate;
    final days = _monthGridDays(selected);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceXs,
        0,
        AppTokens.spaceXs,
        AppTokens.spaceMd,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = constraints.maxWidth / 7;
              // 高度随列宽缩放（窄屏 ≈ 66dp，宽屏封顶），保证触控 ≥48dp。
              final cellHeight = (cellWidth * 1.35)
                  .clamp(88.0, 112.0)
                  .toDouble();
              final weeks = (days.length / 7).ceil();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildWeekdayHeader(context, cellWidth),
                  for (var w = 0; w < weeks; w++)
                    Row(
                      children: [
                        for (var c = 0; c < 7; c++)
                          SizedBox(
                            width: cellWidth,
                            height: cellHeight,
                            child: _buildDayCell(
                              context,
                              ref,
                              days[w * 7 + c],
                              buckets,
                              allTasks,
                              selected,
                              todayKey,
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader(BuildContext context, double cellWidth) {
    final theme = Theme.of(context);
    // 2026-08-10 恰为周一，仅用于按列取星期名（与当月无关）。
    final monday = DateTime(2026, 8, 10);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          SizedBox(
            width: cellWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXs),
              child: Text(
                intl.DateFormat(
                  'E',
                ).format(DateTime(monday.year, monday.month, monday.day + i)),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: AppTokens.textTitleWeight,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    Map<DateTime, List<Task>> buckets,
    List<Task> allTasks,
    DateTime selected,
    DateTime todayKey,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tasks = tasksForDay(buckets, day);
    final hasTasks = tasks.isNotEmpty;
    final isToday = day == todayKey;
    final inMonth = day.month == selected.month;
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: hasTasks
            ? colorScheme.primaryContainer.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          onTap: () => _openDaySheet(context, ref, day, buckets, allTasks),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceXxs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusChip),
              border: Border.all(
                color: isToday
                    ? colorScheme.primary.withValues(alpha: 0.6)
                    : hasTasks
                    ? colorScheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 日期数字：今天主色圆形高亮，周末弱化，相邻月灰显。
                Center(
                  child: Container(
                    width: AppTokens.checkboxSize,
                    height: AppTokens.checkboxSize,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                        color: isToday
                            ? colorScheme.onPrimary
                            : !inMonth
                            ? colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              )
                            : isWeekend
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // 任务呈现：≤2 个标题截断，多于则 +n 计数徽标。
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final task in tasks.take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.spaceXxs,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusChip,
                              ),
                            ),
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                      if (tasks.length > 2)
                        Text(
                          '+${tasks.length - 2}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 周视图 ─────────────────────────────────────────────────────────

  Widget _buildWeekList(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    List<Task> allTasks,
    CalendarState state,
  ) {
    final range = calendarRangeFor(state);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final childrenIndex = indexChildrenByParent(allTasks);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      children: [
        for (var i = 0; i < 7; i++)
          _buildWeekDay(
            context,
            ref,
            DateTime(range.start.year, range.start.month, range.start.day + i),
            buckets,
            childrenIndex,
            todayKey,
          ),
      ],
    );
  }

  Widget _buildWeekDay(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    Map<DateTime, List<Task>> buckets,
    Map<String?, List<Task>> childrenIndex,
    DateTime todayKey,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tasks = tasksForDay(buckets, day);
    final isToday = day == todayKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分区标题：星期 + 日期，今天主色并加「今天」徽标。
        Padding(
          padding: const EdgeInsets.only(
            top: AppTokens.spaceSm,
            bottom: AppTokens.spaceXs,
          ),
          child: Row(
            children: [
              Text(
                intl.DateFormat('EEE').format(day),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isToday ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: AppTokens.textTitleWeight,
                ),
              ),
              const SizedBox(width: AppTokens.spaceXs),
              Text(
                intl.DateFormat('M/d').format(day),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: AppTokens.spaceXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceXs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                  ),
                  child: Text(
                    l10n.today,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (tasks.isEmpty)
          const SizedBox(height: AppTokens.spaceXs)
        else
          for (final task in tasks)
            buildCalendarTaskTile(
              context,
              ref,
              task,
              childrenIndex: childrenIndex,
              onTap: () => context.push('/task/${task.id}'),
            ),
        const SizedBox(height: AppTokens.spaceXs),
      ],
    );
  }

  // ── 日期格点击：底部弹层 ───────────────────────────────────────────

  void _openDaySheet(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    Map<DateTime, List<Task>> buckets,
    List<Task> allTasks,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      // 页面基底（surfacePage）：白卡片在浅灰底上保持层次（55-ui-redesign §5）。
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      builder: (sheetContext) => _DaySheet(
        day: day,
        tasks: tasksForDay(buckets, day),
        childrenIndex: indexChildrenByParent(allTasks),
      ),
    );
  }
}

/// 日期格弹层：顶部日期标题 +「新建」按钮，下方该日任务列表。
class _DaySheet extends ConsumerWidget {
  const _DaySheet({
    required this.day,
    required this.tasks,
    required this.childrenIndex,
  });

  final DateTime day;
  final List<Task> tasks;
  final Map<String?, List<Task>> childrenIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final dateTitle = isZh
        ? intl.DateFormat('y年M月d日 EEEE').format(day)
        : intl.DateFormat('EEEE, MMMM d, y').format(day);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          0,
          AppTokens.spaceMd,
          AppTokens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateTitle,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppTokens.touchTarget),
                  ),
                  onPressed: () => _createTaskOnDay(context, ref, day),
                  icon: const Icon(Icons.add, size: AppTokens.expandArrowSize),
                  label: Text(l10n.newTask),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),
            const Divider(),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTokens.spaceXl,
                ),
                child: Center(
                  child: Text(
                    l10n.emptyCalendar,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTokens.spaceXxs),
                  itemBuilder: (context, index) =>
                      _buildTaskTile(context, ref, tasks[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 新建任务：解析收件箱项目 id，预填该日 09:00（本地时间 → UTC 毫秒）。
  ///
  /// D2 定稿（55-ui-redesign §4.1）：新建走底部弹窗，替代旧的全屏 /task/new 路径。
  /// 日历保持「点日期格 → 弹层新建」的上下文入口（等价于 FAB 的今天预填），
  /// 不另加全局 FAB（避免与 projects/tags 页 FAB 重复，测试断言单 FAB）。
  Future<void> _createTaskOnDay(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
  ) async {
    final project = await ref.read(inboxProjectProvider.future);
    final startAt = DateTime(
      day.year,
      day.month,
      day.day,
      9,
    ).toUtc().millisecondsSinceEpoch;
    if (!context.mounted) return;
    TaskCreateSheet.show(
      context,
      projectId: project.id,
      initialStartAt: startAt,
    );
  }

  Widget _buildTaskTile(BuildContext context, WidgetRef ref, Task task) {
    return buildCalendarTaskTile(
      context,
      ref,
      task,
      childrenIndex: childrenIndex,
      onTap: () => context.push('/task/${task.id}'),
    );
  }
}

/// 日历任务行（周视图/日期弹层共用）：解析 tags / 派生状态 / 逾期。
///
/// 有子任务的任务勾选禁用（状态由子任务派生，AGENTS.md §3-2），
/// 无子任务时点击勾选切换 done/todo（失败由数据流自动回滚）。
Widget buildCalendarTaskTile(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  required Map<String?, List<Task>> childrenIndex,
  VoidCallback? onTap,
}) {
  final children = childrenIndex[task.id] ?? const <Task>[];
  final hasChildren = children.isNotEmpty;
  final effective = hasChildren ? derivedStatus(task, children) : task.status;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final isOverdue = view_rules.isOverdue(task, effective, todayStart);
  final tags = ref.watch(taskTagsProvider(task.id)).value ?? const <Tag>[];
  // 进度环（滴答式）：全量任务列表在 CalendarPage 顶部已订阅，此处复用计算
  // 有子任务任务的派生完成度（taskProgress 对无子任务返回 null）。
  final allTasks = ref.watch(allActiveTasksProvider).value ?? const <Task>[];

  return SimpleTaskTile(
    task: task,
    hasChildren: hasChildren,
    isDone: effective == TaskStatus.done,
    isOverdue: isOverdue,
    tags: tags,
    progressValue: hasChildren ? taskProgress(task, allTasks) : null,
    onTap: onTap,
    onToggleDone: hasChildren
        ? null
        : (value) => _toggleTaskDone(ref, task, value),
  );
}

Future<void> _toggleTaskDone(WidgetRef ref, Task task, bool? value) async {
  final repo = ref.read(todoRepositoryProvider);
  final newStatus = value == true ? TaskStatus.done : TaskStatus.todo;
  try {
    await repo.updateTask(task.id, status: newStatus);
  } catch (_) {
    // 状态切换失败由数据流自动回滚，静默处理（与收件箱/标签页一致）。
  }
}
