import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../../core/utils/view_rules.dart' as view_rules;
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../projects/project_providers.dart';
import '../tasks/task_edit_page.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_create_sheet.dart';
import 'calendar_providers.dart';

/// 现代高质感日历视图（FR-VIEW-02）。
///
/// 架构设计：
/// 1. 顶栏：紧凑单行 Header（年月选择 + 今天胶囊 + 月/周折叠 + 搜索入口）。
/// 2. 日历视口（上部）：统一矩阵格 + 项目色彩微标（Dots）+ 左右滑动手势翻月/周 + 上下折叠手势。
/// 3. 当日议程列表（下部）：实时联动展示选中日期的任务清单，支持勾选、进度环、优先级与点击编辑。
/// 4. 快捷新建（FAB / 内联）：一键唤起创建表单，自动预填选中日期 09:00。
/// 5. 宽屏适配：桌面/平板下自动启用左侧日历 + 右侧任务流水双栏分栏布局。
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isNarrow = AppBreakpoints.isNarrow(context);
    final state = ref.watch(calendarStateProvider);
    final bucketsAsync = ref.watch(calendarBucketsProvider);
    final allTasks = ref.watch(allActiveTasksProvider).value ?? const <Task>[];
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final projectsMap = {for (final p in projects) p.id: p};

    return Scaffold(
      drawer: isNarrow ? const AppDrawer() : null,
      appBar: AppBar(
        leading: isNarrow
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: l10n.openDrawer,
                  icon: const Icon(Icons.menu, size: 22),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        automaticallyImplyLeading: false,
        title: _buildAppBarTitle(context, ref, state),
        actions: [
          // 回到今天快捷胶囊
          _buildTodayButton(context, ref, state),
          // 月 / 周模式切换
          IconButton(
            tooltip: state.mode == CalendarMode.month
                ? l10n.viewWeek
                : l10n.viewMonth,
            icon: Icon(
              state.mode == CalendarMode.month
                  ? Icons.calendar_view_week_outlined
                  : Icons.calendar_view_month_outlined,
              size: 22,
            ),
            onPressed: () =>
                ref.read(calendarStateProvider.notifier).toggleView(),
          ),
          // 搜索
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search, size: 22),
            onPressed: () => context.push('/search'),
          ),
          const SizedBox(width: AppTokens.spaceXs),
        ],
      ),
      body: bucketsAsync.when(
        data: (buckets) => isNarrow
            ? _buildNarrowLayout(
                context,
                ref,
                buckets,
                allTasks,
                projectsMap,
                state,
              )
            : _buildWideLayout(
                context,
                ref,
                buckets,
                allTasks,
                projectsMap,
                state,
              ),
        loading: () => const LoadingView(),
        error: (e, st) {
          logAsyncError(e, st);
          return ErrorView(
            onRetry: () => ref.invalidate(calendarBucketsProvider),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.newTask,
        onPressed: () => _createTaskOnDay(context, ref, state.selectedDate),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── AppBar 标题组件 ──────────────────────────────────────────────────

  Widget _buildAppBarTitle(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
  ) {
    final theme = Theme.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final formatted = isZh
        ? intl.DateFormat('y年M月').format(state.selectedDate)
        : intl.DateFormat('MMMM yyyy').format(state.selectedDate);

    return Text(
      formatted,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildTodayButton(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isCurrentDay =
        state.selectedDate.year == now.year &&
        state.selectedDate.month == now.month &&
        state.selectedDate.day == now.day;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: isCurrentDay
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          foregroundColor: isCurrentDay
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
            side: isCurrentDay
                ? BorderSide.none
                : BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
          ),
        ),
        onPressed: () => ref.read(calendarStateProvider.notifier).goToToday(),
        child: Text(
          l10n.today,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── 窄屏布局（上下联动）───────────────────────────────────────────────

  Widget _buildNarrowLayout(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    List<Task> allTasks,
    Map<String, Project> projectsMap,
    CalendarState state,
  ) {
    return Column(
      children: [
        _buildCalendarCard(
          context,
          ref,
          buckets,
          projectsMap,
          state,
          isNarrow: true,
        ),
        Expanded(
          child: _buildAgendaList(context, ref, buckets, allTasks, state),
        ),
      ],
    );
  }

  // ── 宽屏布局（左右分栏）───────────────────────────────────────────────

  Widget _buildWideLayout(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    List<Task> allTasks,
    Map<String, Project> projectsMap,
    CalendarState state,
  ) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 440,
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            child: _buildCalendarCard(
              context,
              ref,
              buckets,
              projectsMap,
              state,
              isNarrow: false,
            ),
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        Expanded(
          child: _buildAgendaList(context, ref, buckets, allTasks, state),
        ),
      ],
    );
  }

  // ── 日历视口卡片组件 ──────────────────────────────────────────────────

  Widget _buildCalendarCard(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    Map<String, Project> projectsMap,
    CalendarState state, {
    required bool isNarrow,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: isNarrow
          ? const EdgeInsets.fromLTRB(
              AppTokens.spaceSm,
              AppTokens.spaceXs,
              AppTokens.spaceSm,
              AppTokens.spaceXs,
            )
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        boxShadow: isDark
            ? AppTokens.cardShadowDarkList
            : AppTokens.cardShadowLight,
        border: Border.all(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleLight,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -150) {
            // 向左滑动 -> 下一周期
            ref.read(calendarStateProvider.notifier).nextPeriod();
          } else if (velocity > 150) {
            // 向右滑动 -> 上一周期
            ref.read(calendarStateProvider.notifier).prevPeriod();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶层月份快速导航栏（左右小箭头 + 周期文案）
            _buildCalendarRibbonHeader(context, ref, state),
            const SizedBox(height: AppTokens.spaceXxs),
            // 星期表头（一至日）
            _buildWeekdayRow(context),
            const SizedBox(height: AppTokens.spaceXxs),
            // 日期格网
            _buildDaysGrid(context, ref, buckets, projectsMap, state),
            // 底部折叠/展开指示柄（窄屏下提供视觉手势暗示）
            if (isNarrow)
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppTokens.radiusCard),
                ),
                onTap: () =>
                    ref.read(calendarStateProvider.notifier).toggleView(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.25,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 日历小顶栏 ───────────────────────────────────────────────────────

  Widget _buildCalendarRibbonHeader(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = calendarRangeFor(state);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    String subTitle;
    if (state.mode == CalendarMode.month) {
      subTitle = isZh
          ? intl.DateFormat('y年M月').format(state.selectedDate)
          : intl.DateFormat('MMMM yyyy').format(state.selectedDate);
    } else {
      subTitle = isZh
          ? '${intl.DateFormat('M月d日').format(range.start)} – ${intl.DateFormat('M月d日').format(range.end)}'
          : '${intl.DateFormat('MMM d').format(range.start)} – ${intl.DateFormat('MMM d').format(range.end)}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceSm,
        AppTokens.spaceXs,
        AppTokens.spaceSm,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: l10n.prevPeriod,
            icon: const Icon(Icons.chevron_left, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                ref.read(calendarStateProvider.notifier).prevPeriod(),
          ),
          Text(
            subTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          IconButton(
            tooltip: l10n.nextPeriod,
            icon: const Icon(Icons.chevron_right, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                ref.read(calendarStateProvider.notifier).nextPeriod(),
          ),
        ],
      ),
    );
  }

  // ── 星期表头 ─────────────────────────────────────────────────────────

  Widget _buildWeekdayRow(BuildContext context) {
    final theme = Theme.of(context);
    // 2026-08-10 恰为周一，仅用于生成星期名称序列
    final monday = DateTime(2026, 8, 10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXs),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  intl.DateFormat(
                    'E',
                  ).format(DateTime(monday.year, monday.month, monday.day + i)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: i >= 5
                        ? theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          )
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 日期网格 ─────────────────────────────────────────────────────────

  Widget _buildDaysGrid(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    Map<String, Project> projectsMap,
    CalendarState state,
  ) {
    final selected = state.selectedDate;
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final days = state.mode == CalendarMode.month
        ? _monthGridDays(selected)
        : _weekDays(selected);

    final weeks = (days.length / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceXs,
        0,
        AppTokens.spaceXs,
        AppTokens.spaceXs,
      ),
      child: Column(
        children: [
          for (var w = 0; w < weeks; w++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: _DayCell(
                        day: days[w * 7 + c],
                        selectedDate: selected,
                        todayDate: todayKey,
                        isMonthMode: state.mode == CalendarMode.month,
                        tasks: tasksForDay(buckets, days[w * 7 + c]),
                        projectsMap: projectsMap,
                        onTap: () {
                          ref
                              .read(calendarStateProvider.notifier)
                              .selectDate(days[w * 7 + c]);
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 当日议程与任务列表（下半部）───────────────────────────────────────

  Widget _buildAgendaList(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    List<Task> allTasks,
    CalendarState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = state.selectedDate;
    final tasks = tasksForDay(buckets, selected);
    final childrenIndex = indexChildrenByParent(allTasks);

    final now = DateTime.now();
    final isToday =
        selected.year == now.year &&
        selected.month == now.month &&
        selected.day == now.day;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    final dateHeader = isZh
        ? (isToday
              ? '${intl.DateFormat('M月d日').format(selected)} · ${l10n.today}'
              : intl.DateFormat('M月d日 EEEE').format(selected))
        : (isToday
              ? '${intl.DateFormat('MMM d').format(selected)} · ${l10n.today}'
              : intl.DateFormat('EEEE, MMM d').format(selected));

    final countText = tasks.isEmpty ? '' : l10n.tasksCount(tasks.length);

    return CustomScrollView(
      slivers: [
        // 当日概览 Sticky / Header 栏
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceMd,
              AppTokens.spaceSm,
              AppTokens.spaceMd,
              AppTokens.spaceXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateHeader,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (countText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceXs,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                    ),
                    child: Text(
                      countText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(width: AppTokens.spaceSm),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.newTask),
                  onPressed: () => _createTaskOnDay(context, ref, selected),
                ),
              ],
            ),
          ),
        ),
        if (tasks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.spaceXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: AppTokens.emptyIconSize,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.45,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    Text(
                      l10n.emptyCalendar,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceMd),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusButton,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addTask),
                      onPressed: () => _createTaskOnDay(context, ref, selected),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceMd,
              0,
              AppTokens.spaceMd,
              88, // 留出 FAB 底部防遮挡安全边距
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final task = tasks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: CalendarTaskTile(
                    task: task,
                    children: childrenIndex[task.id] ?? const <Task>[],
                    allTasks: allTasks,
                    onTap: () => openTaskEdit(context, taskId: task.id),
                  ),
                );
              }, childCount: tasks.length),
            ),
          ),
      ],
    );
  }

  // ── 日期计算辅助 ─────────────────────────────────────────────────────

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

  List<DateTime> _weekDays(DateTime selected) {
    final monday = DateTime(
      selected.year,
      selected.month,
      selected.day - (selected.weekday - DateTime.monday),
    );
    return [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
  }

  // ── 新建任务预填当日 09:00 ──────────────────────────────────────────

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
}

// ── 单个精致日期方格组件 ─────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selectedDate,
    required this.todayDate,
    required this.isMonthMode,
    required this.tasks,
    required this.projectsMap,
    required this.onTap,
  });

  final DateTime day;
  final DateTime selectedDate;
  final DateTime todayDate;
  final bool isMonthMode;
  final List<Task> tasks;
  final Map<String, Project> projectsMap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isToday =
        day.year == todayDate.year &&
        day.month == todayDate.month &&
        day.day == todayDate.day;
    final isSelected =
        day.year == selectedDate.year &&
        day.month == selectedDate.month &&
        day.day == selectedDate.day;
    final inMonth = !isMonthMode || day.month == selectedDate.month;
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    // 选中 / 今天 / 正常状态视觉颜色分配
    Color numColor;
    FontWeight numWeight = FontWeight.w400;
    BoxDecoration? numDeco;

    if (isSelected && isToday) {
      numColor = colorScheme.onPrimary;
      numWeight = FontWeight.w700;
      numDeco = BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      );
    } else if (isSelected) {
      numColor = colorScheme.onPrimaryContainer;
      numWeight = FontWeight.w700;
      numDeco = BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      numColor = colorScheme.primary;
      numWeight = FontWeight.w700;
      numDeco = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.primary, width: 1.5),
      );
    } else if (!inMonth) {
      numColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    } else if (isWeekend) {
      numColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.75);
    } else {
      numColor = colorScheme.onSurface;
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 日期圆圈 / 数字
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: numDeco,
                  child: Text(
                    '${day.day}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: numWeight,
                      color: numColor,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // 任务色彩微标小点（Event Dots）
                _buildEventDots(tasks),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventDots(List<Task> tasks) {
    if (tasks.isEmpty) {
      return const SizedBox(height: 5);
    }

    final displayTasks = tasks.take(3).toList();
    final hasMore = tasks.length > 3;

    return SizedBox(
      height: 5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final task in displayTasks) _buildDot(task),
          if (hasMore)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: const BoxDecoration(
                color: AppTokens.colorCancelled,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDot(Task task) {
    final project = projectsMap[task.projectId];
    final color = project != null ? Color(project.color) : AppTokens.seedColor;
    final isDone = task.status == TaskStatus.done;

    return Container(
      width: 4.5,
      height: 4.5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: isDone ? color.withValues(alpha: 0.35) : color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── 任务列表项（复用 SimpleTaskTile）──────────────────────────────────

/// 日历议程任务列表项组件（复用 [SimpleTaskTile]）。
///
/// 独立抽离为 [ConsumerWidget]，将 [taskTagsProvider] 监听边界隔离在单个 Tile 内，
/// 避免标签变动向上传染导致 [CalendarPage] 与 42 个日期格网全局级联 Rebuild。
class CalendarTaskTile extends ConsumerWidget {
  const CalendarTaskTile({
    super.key,
    required this.task,
    required this.children,
    required this.allTasks,
    this.onTap,
  });

  final Task task;
  final List<Task> children;
  final List<Task> allTasks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasChildren = children.isNotEmpty;
    final effective = hasChildren ? derivedStatus(task, children) : task.status;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final isOverdue = view_rules.isOverdue(task, effective, todayStart);
    final tags = ref.watch(taskTagsProvider(task.id)).value ?? const <Tag>[];

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
      // 状态切换失败由数据流自动回滚，静默处理
    }
  }
}
