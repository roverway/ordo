import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../../core/utils/view_rules.dart' as view_rules;
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/app_menu_item.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../projects/project_providers.dart';
import '../tasks/task_edit_page.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_create_sheet.dart';
import 'calendar_providers.dart';

/// 顶部三点更多菜单的操作枚举。
enum _CalendarMenuAction { today, toggleView, search }

/// 现代高质感沉浸式日历视图（FR-VIEW-02）。
///
/// 架构设计：
/// 1. 顶栏融合：周期标题（月/周）置于 AppBar，点击弹出日期快捷面板；右上角操作收拢为三点菜单。
/// 2. 日历视口（上部）：无边框沉浸式设计 + 统一矩阵格 + 项目色彩微标 + 左右滑动手势翻月/周 + 上下折叠手势。
/// 3. 当日议程列表（下部）：实时联动展示选中日期的任务清单，支持勾选、进度环、优先级与点击编辑。
/// 4. 快捷新建（FAB / 内联）：一键唤起创建表单，自动预填选中日期 09:00。
/// 5. 宽屏适配：桌面/平板下自动启用左侧日历 + 右侧任务流水双栏分栏布局。
/// 6. 全面国际化：纯正中文星期与议程星期展示，多语言无缝切换。
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isNarrow = AppBreakpoints.isNarrow(context);
    final state = ref.watch(calendarStateProvider);
    final bucketsAsync = ref.watch(calendarBucketsProvider);

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
          // 更多操作三点菜单（回到今天、月/周视图切换、搜索）
          PopupMenuButton<_CalendarMenuAction>(
            tooltip: l10n.moreOptions,
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (action) {
              switch (action) {
                case _CalendarMenuAction.today:
                  ref.read(calendarStateProvider.notifier).goToToday();
                  break;
                case _CalendarMenuAction.toggleView:
                  ref.read(calendarStateProvider.notifier).toggleView();
                  break;
                case _CalendarMenuAction.search:
                  context.push('/search');
                  break;
              }
            },
            itemBuilder: (context) => [
              AppMenuItem(
                value: _CalendarMenuAction.today,
                icon: Icons.today_outlined,
                label: l10n.goToToday,
              ),
              AppMenuItem(
                value: _CalendarMenuAction.toggleView,
                icon: state.mode == CalendarMode.month
                    ? Icons.calendar_view_week_outlined
                    : Icons.calendar_view_month_outlined,
                label: state.mode == CalendarMode.month
                    ? l10n.switchToWeekView
                    : l10n.switchToMonthView,
              ),
              AppMenuItem(
                value: _CalendarMenuAction.search,
                icon: Icons.search,
                label: l10n.search,
              ),
            ],
          ),
          const SizedBox(width: AppTokens.spaceXs),
        ],
      ),
      body: bucketsAsync.when(
        data: (buckets) => isNarrow
            ? _buildNarrowLayout(context, ref, buckets, state)
            : _buildWideLayout(context, ref, buckets, state),
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

  // ── AppBar 标题组件（支持点击弹出日期选择面板）───────────────────────────

  Widget _buildAppBarTitle(
    BuildContext context,
    WidgetRef ref,
    CalendarState state,
  ) {
    final theme = Theme.of(context);
    final range = calendarRangeFor(state);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    final formatted = formatCalendarHeader(
      selectedDate: state.selectedDate,
      isMonthMode: state.mode == CalendarMode.month,
      weekStart: range.start,
      weekEnd: range.end,
      isZh: isZh,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      onTap: () => _pickDate(context, ref, state.selectedDate),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceXs,
          vertical: AppTokens.spaceXxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatted,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ── 日期快捷选择面板 ──────────────────────────────────────────────────

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    DateTime initialDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      ref.read(calendarStateProvider.notifier).selectDate(picked);
    }
  }

  // ── 窄屏布局（上下联动）───────────────────────────────────────────────

  Widget _buildNarrowLayout(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    CalendarState state,
  ) {
    return Column(
      children: [
        _CalendarViewport(buckets: buckets, state: state, isNarrow: true),
        Expanded(child: _buildAgendaList(context, ref, buckets, state)),
      ],
    );
  }

  // ── 宽屏布局（左右分栏）───────────────────────────────────────────────

  Widget _buildWideLayout(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    CalendarState state,
  ) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppTokens.calendarPaneWidth,
          child: _CalendarViewport(
            buckets: buckets,
            state: state,
            isNarrow: false,
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        Expanded(child: _buildAgendaList(context, ref, buckets, state)),
      ],
    );
  }

  // ── 当日议程与任务列表（下半部）───────────────────────────────────────

  Widget _buildAgendaList(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    CalendarState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = state.selectedDate;
    final tasks = tasksForDay(buckets, selected);
    final allTasks = ref.watch(allActiveTasksProvider).value ?? const <Task>[];
    final childrenIndex = indexChildrenByParent(allTasks);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    final dateHeader = formatAgendaDateHeader(
      selected: selected,
      todayLabel: l10n.today,
      isZh: isZh,
    );
    final now = DateTime.now();
    final isToday =
        selected.year == now.year &&
        selected.month == now.month &&
        selected.day == now.day;

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
                        fontSize: AppTokens.textMicroSize,
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
                  // 66 §6：议程行距对齐全局组内行距 spaceXs（此前 2 过挤）。
                  padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
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

// ── 日历沉浸式无边框视口组件 ────────────────────────────────────────────

class _CalendarViewport extends ConsumerStatefulWidget {
  const _CalendarViewport({
    required this.buckets,
    required this.state,
    required this.isNarrow,
  });

  final Map<DateTime, List<Task>> buckets;
  final CalendarState state;
  final bool isNarrow;

  @override
  ConsumerState<_CalendarViewport> createState() => _CalendarViewportState();
}

class _CalendarViewportState extends ConsumerState<_CalendarViewport> {
  double _horizontalDelta = 0;
  double _verticalDelta = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final projectsMap = ref.watch(projectsMapProvider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _horizontalDelta = 0;
      },
      onHorizontalDragUpdate: (details) {
        _horizontalDelta += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -150 || _horizontalDelta < -40) {
          // 向左滑动 -> 下一周期
          ref.read(calendarStateProvider.notifier).nextPeriod();
        } else if (velocity > 150 || _horizontalDelta > 40) {
          // 向右滑动 -> 上一周期
          ref.read(calendarStateProvider.notifier).prevPeriod();
        }
        _horizontalDelta = 0;
      },
      onVerticalDragStart: (_) {
        _verticalDelta = 0;
      },
      onVerticalDragUpdate: (details) {
        _verticalDelta += details.primaryDelta ?? 0;
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -150 || _verticalDelta < -30) {
          // 向上滑动 -> 收起为周视图
          ref.read(calendarStateProvider.notifier).setMode(CalendarMode.week);
        } else if (velocity > 150 || _verticalDelta > 30) {
          // 向下滑动 -> 展开为月视图
          ref.read(calendarStateProvider.notifier).setMode(CalendarMode.month);
        }
        _verticalDelta = 0;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppTokens.spaceXs),
          // 星期表头（一至日）
          _buildWeekdayRow(context),
          const SizedBox(height: AppTokens.spaceXs),
          // 日期格网
          _buildDaysGrid(
            context,
            ref,
            widget.buckets,
            projectsMap,
            widget.state,
          ),
          // 底部折叠/展开指示柄（窄屏下提供视觉手势暗示）
          if (widget.isNarrow)
            InkWell(
              onTap: () =>
                  ref.read(calendarStateProvider.notifier).toggleView(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  // ── 星期表头（全面国际化）──────────────────────────────────────────────

  Widget _buildWeekdayRow(BuildContext context) {
    final theme = Theme.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final weekdayLabels = getWeekdayShorts(isZh: isZh);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  weekdayLabels[i],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: AppTokens.textCaptionSize,
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
        AppTokens.spaceSm,
        0,
        AppTokens.spaceSm,
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
                      fontSize: AppTokens.textFootnoteSize,
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
    } catch (e, st) {
      logAsyncError(e, st);
    }
  }
}
