import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/motion.dart';
import '../../core/utils/tree.dart';
import '../../core/utils/view_rules.dart' as view_rules;
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/page_hero_header.dart';
import '../../shared/widgets/scope_switcher_sheet.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../projects/project_providers.dart';
import '../tasks/task_edit_page.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_create_sheet.dart';
import '../tasks/widgets/task_swipe_wrapper.dart';
import '../../core/utils/calendar_day_decorator.dart';
import '../settings/settings_providers.dart';
import 'calendar_providers.dart';

/// 现代高质感沉浸式日历视图（FR-VIEW-02）。
///
/// 架构设计：
/// 1. 顶栏融合：周期标题（月/周）置于 AppBar，点击弹出日期快捷面板；右上角设「回到今天」快捷按钮。
/// 2. 日历视口（上部）：无边框沉浸式设计 + 统一矩阵格 + 项目色彩微标 + 左右滑动手势翻月/周 + 上下折叠手势。
/// 3. 当日/周/月议程列表（下部）：实时联动展示选定时间范围的任务清单，支持上下滑动手势穿透联动日历折叠/展开。
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeroHeader(
              title: l10n.navCalendar,
              onTitleTap: () => showScopeSwitcherSheet(context),
              trailing: IconButton(
                tooltip: l10n.goToToday,
                icon: const Icon(Icons.today_outlined, size: 22),
                onPressed: () {
                  ref.read(calendarStateProvider.notifier).goToToday();
                },
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            Expanded(
              child: bucketsAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: l10n.newTask,
        onPressed: () => _createTaskOnDay(context, ref, state.selectedDate),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          l10n.newTask,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }

  // ── 窄屏布局（上下联动）────────────────────────────────────────────────

  Widget _buildNarrowLayout(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    CalendarState state,
  ) {
    return Column(
      children: [
        _CalendarViewport(buckets: buckets, state: state, isNarrow: true),
        Expanded(child: _CalendarAgendaList(state: state)),
      ],
    );
  }

  // ── 宽屏布局（左右分栏）────────────────────────────────────────────────

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
        Expanded(child: _CalendarAgendaList(state: state)),
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

  // 本次网格切换方向：1 = 下一周期（新网格自右滑入）、-1 = 上一周期（自左
  // 滑入）、0 = 非水平翻页（月↔周折叠/点选柄，柔和交叉淡入淡出）。
  // 手势触发点先行写入，AnimatedSwitcher 的 transitionBuilder 在随之而来的重建中读取。
  int _slideDirection = 0;

  @override
  void didUpdateWidget(covariant _CalendarViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.mode != widget.state.mode) {
      // 视图模式切换（月↔周）时，确保重置为 0（走柔和垂直折叠/展开动画）
      _slideDirection = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final projectsMap = ref.watch(projectsMapProvider);
    final l10n = AppLocalizations.of(context);

    // 网格日期集（月 = 整月矩阵、周 = 单周行）；首日作 AnimatedSwitcher 的
    // key——翻月/翻周/月周切换时 key 变化触发过渡。
    final days = widget.state.mode == CalendarMode.month
        ? calculateMonthGridDays(widget.state.selectedDate)
        : calculateWeekDays(widget.state.selectedDate);

    // 垂直折叠/展开使用舒缓的 350ms (motionSlow) + easeInOutCubic 曲线，
    // 与下方任务列表物理弹性回弹（BouncingScrollPhysics）节奏完美协调；
    // 水平翻月/翻周保持轻快 250ms (motionNormal)。
    final isVertical = _slideDirection == 0;
    final duration = isVertical
        ? motionDuration(context, AppTokens.motionSlow)
        : motionDuration(context, AppTokens.motionNormal);
    final curve = isVertical
        ? (isReducedMotion(context) ? Curves.easeOut : Curves.easeInOutCubic)
        : motionCurve(context);

    // 当前网格唯一 Key（包含视图模式与首日，确保月↔周切换时必触发 AnimatedSwitcher）
    final currentGridKey = ValueKey(
      '${widget.state.mode.name}_${days.first.toIso8601String()}',
    );

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
          _slideDirection = 1;
          ref.read(calendarStateProvider.notifier).nextPeriod();
        } else if (velocity > 150 || _horizontalDelta > 40) {
          // 向右滑动 -> 上一周期
          _slideDirection = -1;
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
          // 向上滑动 -> 收起为周视图（非水平翻页，方向归零仅淡入）
          _slideDirection = 0;
          ref.read(calendarStateProvider.notifier).setMode(CalendarMode.week);
        } else if (velocity > 150 || _verticalDelta > 30) {
          // 向下滑动 -> 展开为月视图
          _slideDirection = 0;
          ref.read(calendarStateProvider.notifier).setMode(CalendarMode.month);
        }
        _verticalDelta = 0;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 日历头部：翻月/翻周 + 视图切换 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 2),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.prevPeriod,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: () {
                    _slideDirection = -1;
                    ref.read(calendarStateProvider.notifier).prevPeriod();
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      () {
                        final range = calendarRangeFor(widget.state);
                        final isZh =
                            Localizations.localeOf(context).languageCode ==
                            'zh';
                        return formatCalendarHeader(
                          selectedDate: widget.state.selectedDate,
                          isMonthMode: widget.state.mode == CalendarMode.month,
                          weekStart: range.start,
                          weekEnd: range.end,
                          isZh: isZh,
                        );
                      }(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        fontFeatures: AppTokens.fontTabular,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.nextPeriod,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: () {
                    _slideDirection = 1;
                    ref.read(calendarStateProvider.notifier).nextPeriod();
                  },
                ),
                const SizedBox(width: 4),
                // 视图切换分段 (月 / 周)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeSegButton(
                        context,
                        label: l10n.monthLabel,
                        isActive: widget.state.mode == CalendarMode.month,
                        onTap: () {
                          _slideDirection = 0;
                          ref
                              .read(calendarStateProvider.notifier)
                              .setMode(CalendarMode.month);
                        },
                      ),
                      _buildModeSegButton(
                        context,
                        label: l10n.weekLabel,
                        isActive: widget.state.mode == CalendarMode.week,
                        onTap: () {
                          _slideDirection = 0;
                          ref
                              .read(calendarStateProvider.notifier)
                              .setMode(CalendarMode.week);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // 星期表头（一至日）
          _buildWeekdayRow(context),
          const SizedBox(height: AppTokens.spaceXs),
          // 日期网格：上下（月↔周）的高度过渡由外层 AnimatedSize 承担
          // （周视图即同结构矩阵的 1 行，与任务树/侧边栏同一范式）；左右
          // 翻页由内层 AnimatedSwitcher 做方向性推入 + 淡入淡出。滑动位移
          // 为宽度分数（0.18），分辨率无关；reduced motion 经 motionDuration
          // 归零全部瞬时切换。
          AnimatedSize(
            duration: duration,
            curve: curve,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: curve,
              switchOutCurve: curve.flipped,
              // Stack 尺寸只取**新网格**：退场旧网格以 Positioned 叠加（不参与
              // Stack 尺寸测定）。默认 layoutBuilder 的 Stack 尺寸取最大子项，
              // 月视图（6 行）退场期间高度迟迟不塌，AnimatedSize 收起被拖到
              // 退场结束才开始——这正是上滑后"等一段时间才显示周日历"的迟滞
              // 来源；旧网格保持自然高度、随高度收起被 Stack hardEdge 裁剪。
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    for (final child in previousChildren)
                      Positioned(top: 0, left: 0, right: 0, child: child),
                    ?currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                final dir = _slideDirection;
                final isIncoming = child.key == currentGridKey;
                // 垂直切换（月↔周）：新旧网格采用「垂直平移 + 交叉淡入淡出」：
                // - 当收起为周视图时（向上手势）：入场周网格自下方 (+0.08) 向上推入入位，退场月网格向上 (-0.12) 滑出；
                // - 当展开为月视图时（向下手势）：入场月网格自上方 (-0.12) 向下滑入展开，退场周网格向下 (+0.08) 滑出；
                // 配合外层 AnimatedSize 的 350ms easeInOutCubic 曲线，与用户的上下滑动手势完美同向契合。
                if (dir == 0) {
                  if (isReducedMotion(context)) {
                    return FadeTransition(opacity: animation, child: child);
                  }
                  final isToWeek = widget.state.mode == CalendarMode.week;
                  final beginOffset = isToWeek
                      ? (isIncoming
                            ? const Offset(0, 0.08)
                            : const Offset(0, -0.12))
                      : (isIncoming
                            ? const Offset(0, -0.12)
                            : const Offset(0, 0.08));
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: beginOffset,
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                }
                final begin = isIncoming
                    ? Offset(0.18 * dir, 0)
                    : Offset(-0.18 * dir, 0);
                if (isReducedMotion(context)) {
                  return FadeTransition(opacity: animation, child: child);
                }
                return SlideTransition(
                  position: Tween(
                    begin: begin,
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: KeyedSubtree(
                key: currentGridKey,
                child: _buildDaysGrid(
                  context,
                  ref,
                  widget.buckets,
                  projectsMap,
                  widget.state,
                  days,
                ),
              ),
            ),
          ),
          // 底部折叠/展开指示柄（窄屏下提供视觉手势暗示）
          if (widget.isNarrow)
            InkWell(
              onTap: () {
                // 点选柄折叠/展开：非水平翻页，方向归零（仅淡入 + 高度过渡）。
                _slideDirection = 0;
                ref.read(calendarStateProvider.notifier).toggleView();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                alignment: Alignment.center,
                child: Container(
                  width: 34,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(3),
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

  Widget _buildModeSegButton(
    BuildContext context, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ── 星期表头（全面国际化）──────────────────────────────────────────

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

  // ── 日期网格 ────────────────────────────────────────────────────────

  Widget _buildDaysGrid(
    BuildContext context,
    WidgetRef ref,
    Map<DateTime, List<Task>> buckets,
    Map<String, Project> projectsMap,
    CalendarState state,
    List<DateTime> days,
  ) {
    final selected = state.selectedDate;
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final showLunar = ref.watch(calendarShowLunarProvider);
    final showHolidays = ref.watch(calendarShowHolidaysProvider);

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
                        showLunar: showLunar,
                        showHolidays: showHolidays,
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
}

// ── 单个精致日期方格组件 ──────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selectedDate,
    required this.todayDate,
    required this.isMonthMode,
    required this.tasks,
    required this.projectsMap,
    required this.onTap,
    this.showLunar = true,
    this.showHolidays = true,
  });

  final DateTime day;
  final DateTime selectedDate;
  final DateTime todayDate;
  final bool isMonthMode;
  final List<Task> tasks;
  final Map<String, Project> projectsMap;
  final VoidCallback onTap;
  final bool showLunar;
  final bool showHolidays;

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
    FontWeight numWeight = FontWeight.w500;
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

    final isDark = theme.brightness == Brightness.dark;
    final decoration = CalendarDayDecorator.decorate(
      date: day,
      showLunar: showLunar,
      showHolidays: showHolidays,
    );

    final hasSubText = decoration.subText != null;

    Color subTextColor;
    if (isSelected && isToday) {
      subTextColor = colorScheme.onPrimary.withValues(alpha: 0.85);
    } else if (isSelected) {
      subTextColor = colorScheme.onPrimaryContainer.withValues(alpha: 0.85);
    } else if (!inMonth) {
      subTextColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.25);
    } else if (decoration.isSpecialSubText) {
      subTextColor = colorScheme.primary;
    } else {
      subTextColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: hasSubText ? 24 : 28,
                        height: hasSubText ? 24 : 28,
                        alignment: Alignment.center,
                        decoration: numDeco,
                        child: Text(
                          '${day.day}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: hasSubText ? 14.5 : 15.5,
                            fontWeight: numWeight,
                            color: numColor,
                            fontFeatures: AppTokens.fontTabular,
                          ),
                        ),
                      ),
                      if (hasSubText) ...[
                        const SizedBox(height: 1),
                        Text(
                          decoration.subText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: decoration.isSpecialSubText
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: subTextColor,
                            height: 1.1,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      _buildEventDots(tasks),
                    ],
                  ),
                ),
              ),
              if (decoration.badgeText != null)
                Positioned(
                  top: 1,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: decoration.isRestBadge
                          ? (isDark
                              ? Colors.redAccent.withValues(alpha: 0.25)
                              : Colors.red.withValues(alpha: 0.12))
                          : (isDark
                              ? colorScheme.surfaceContainerHighest
                              : colorScheme.surfaceContainerHigh),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      decoration.badgeText!,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: decoration.isRestBadge
                            ? (isDark ? Colors.redAccent.shade100 : Colors.red.shade700)
                            : colorScheme.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
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

// ── 当日/周/月议程与任务列表（下半部）─────────────────────────────────

/// 日历任务议程列表组件。
///
/// 架构特性：
/// 1. 支持根据 [CalendarState.agendaScope] 展示当日/该周/该月的任务集合；
/// 2. 滑动手势穿透联动：列表内部优先滚动；当滑至顶部边界且继续下拉时触发展开为月视图；
///    当滑至底部边界且继续上拉时触发收起为周视图。
class _CalendarAgendaList extends ConsumerStatefulWidget {
  const _CalendarAgendaList({required this.state});

  final CalendarState state;

  @override
  ConsumerState<_CalendarAgendaList> createState() =>
      _CalendarAgendaListState();
}

class _CalendarAgendaListState extends ConsumerState<_CalendarAgendaList> {
  static const double _kMinTriggerOverscroll = 20.0;
  static const double _kFlingVelocityThreshold = 100.0;
  static const double _kFlingMinOverscroll = 5.0;

  final ScrollController _scrollController = ScrollController();
  double _overscrollTop = 0;
  bool _isDragging = false;
  double _monthDragDelta = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CalendarAgendaList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.mode != widget.state.mode &&
        widget.state.mode == CalendarMode.month) {
      if (_scrollController.hasClients && _scrollController.offset > 0) {
        _scrollController.jumpTo(0);
      }
    }
  }

  void _checkAndTriggerExpandMonth({double velocity = 0}) {
    if (!_isDragging) return;
    _isDragging = false;

    final currentOverscrollTop = _overscrollTop;
    _overscrollTop = 0;

    final shouldExpandMonth =
        currentOverscrollTop > _kMinTriggerOverscroll ||
        (velocity > _kFlingVelocityThreshold &&
            currentOverscrollTop > _kFlingMinOverscroll);

    if (shouldExpandMonth && widget.state.mode == CalendarMode.week) {
      ref.read(calendarStateProvider.notifier).setMode(CalendarMode.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = widget.state.selectedDate;
    final allTasks = ref.watch(allActiveTasksProvider).value ?? const <Task>[];
    final tasks = tasksForAgendaScope(allTasks: allTasks, state: widget.state);
    final childrenIndex = indexChildrenByParent(allTasks);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final showLunar = ref.watch(calendarShowLunarProvider);
    final showHolidays = ref.watch(calendarShowHolidaysProvider);
    final dayDecoration = CalendarDayDecorator.decorate(
      date: selected,
      showLunar: showLunar,
      showHolidays: showHolidays,
    );

    final String dateHeader;
    final bool isHighlighted;
    final now = DateTime.now();

    switch (widget.state.agendaScope) {
      case CalendarAgendaScope.day:
        dateHeader = formatAgendaDateHeader(
          selected: selected,
          todayLabel: l10n.today,
          isZh: isZh,
        );
        isHighlighted =
            selected.year == now.year &&
            selected.month == now.month &&
            selected.day == now.day;
        break;
      case CalendarAgendaScope.week:
        final range = calendarAgendaRangeFor(widget.state);
        dateHeader = formatAgendaWeekHeader(
          weekStart: range.start,
          weekEnd: range.end,
          thisWeekLabel: l10n.thisWeek,
          isZh: isZh,
        );
        isHighlighted = !now.isBefore(range.start) && !now.isAfter(range.end);
        break;
      case CalendarAgendaScope.month:
        dateHeader = formatAgendaMonthHeader(
          selected: selected,
          thisMonthLabel: l10n.thisMonth,
          isZh: isZh,
        );
        isHighlighted =
            selected.year == now.year && selected.month == now.month;
    }
    final isDark = theme.brightness == Brightness.dark;
    final isNarrow = AppBreakpoints.isNarrow(context);
    final isMonthMode = isNarrow && widget.state.mode == CalendarMode.month;

    final Widget listContent = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (isMonthMode) return false;
        if (notification is ScrollStartNotification) {
          if (notification.dragDetails != null) {
            _isDragging = true;
            _overscrollTop = 0;
          }
        } else if (notification is OverscrollNotification) {
          if (notification.dragDetails != null) {
            if (notification.overscroll < 0) {
              _overscrollTop += -notification.overscroll;
            }
          }
        } else if (notification is ScrollUpdateNotification) {
          if (notification.dragDetails != null) {
            if (notification.metrics.pixels <
                notification.metrics.minScrollExtent) {
              _overscrollTop =
                  notification.metrics.minScrollExtent -
                  notification.metrics.pixels;
            }
          } else if (_isDragging) {
            _checkAndTriggerExpandMonth();
          }
        } else if (notification is UserScrollNotification) {
          if (notification.direction == ScrollDirection.idle && _isDragging) {
            _checkAndTriggerExpandMonth();
          }
        } else if (notification is ScrollEndNotification) {
          if (_isDragging) {
            final velocity = notification.dragDetails?.primaryVelocity ?? 0;
            _checkAndTriggerExpandMonth(velocity: velocity);
          }
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: isMonthMode
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
        slivers: [
          // 概览 Sticky / Header 栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          dateHeader,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isHighlighted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (widget.state.agendaScope == CalendarAgendaScope.day &&
                            dayDecoration.agendaDescription != null)
                          Text(
                            dayDecoration.agendaDescription!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (widget.state.agendaScope == CalendarAgendaScope.day &&
                            dayDecoration.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: dayDecoration.isRestBadge
                                  ? (isDark
                                      ? Colors.redAccent.withValues(alpha: 0.25)
                                      : Colors.red.withValues(alpha: 0.12))
                                  : (isDark
                                      ? theme.colorScheme.surfaceContainerHighest
                                      : theme.colorScheme.surfaceContainerHigh),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              dayDecoration.badgeText!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: dayDecoration.isRestBadge
                                    ? (isDark ? Colors.redAccent.shade100 : Colors.red.shade700)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? AppTokens.borderSubtleDark
                            : AppTokens.borderSubtleLight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.itemCount(tasks.length),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTokens.fontTabular,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Scope Chips: 当日 | 该周 | 该月 ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  _buildScopeChip(
                    context,
                    label: l10n.calendarScopeDay,
                    isActive:
                        widget.state.agendaScope == CalendarAgendaScope.day,
                    onTap: () => ref
                        .read(calendarStateProvider.notifier)
                        .setAgendaScope(CalendarAgendaScope.day),
                  ),
                  const SizedBox(width: 8),
                  _buildScopeChip(
                    context,
                    label: l10n.calendarScopeWeek,
                    isActive:
                        widget.state.agendaScope == CalendarAgendaScope.week,
                    onTap: () => ref
                        .read(calendarStateProvider.notifier)
                        .setAgendaScope(CalendarAgendaScope.week),
                  ),
                  const SizedBox(width: 8),
                  _buildScopeChip(
                    context,
                    label: l10n.calendarScopeMonth,
                    isActive:
                        widget.state.agendaScope == CalendarAgendaScope.month,
                    onTap: () => ref
                        .read(calendarStateProvider.notifier)
                        .setAgendaScope(CalendarAgendaScope.month),
                  ),
                ],
              ),
            ),
          ),
          if (tasks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.event_available_outlined,
                accentColor: AppTokens.colorNavCalendar,
                message: l10n.emptyCalendar,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceMd,
                0,
                AppTokens.spaceMd,
                130, // 留出 FAB 底部防遮挡安全边距
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final task = tasks[index];
                  return Padding(
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
      ),
    );

    if (isMonthMode) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (_) {
          _monthDragDelta = 0;
        },
        onVerticalDragUpdate: (details) {
          _monthDragDelta += details.primaryDelta ?? 0;
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -_kFlingVelocityThreshold ||
              _monthDragDelta < -_kMinTriggerOverscroll) {
            ref.read(calendarStateProvider.notifier).setMode(CalendarMode.week);
          }
          _monthDragDelta = 0;
        },
        child: listContent,
      );
    }

    return listContent;
  }

  Widget _buildScopeChip(
    BuildContext context, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : Colors.black87)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : (isDark
                      ? AppTokens.borderSubtleDark
                      : AppTokens.borderSubtleLight),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? (isDark ? Colors.black87 : Colors.white)
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 任务列表项（复用 SimpleTaskTile）─────────────────────────────────

/// 日历议程任务列表项组件（复用 [SimpleTaskTile]）。
///
/// 独立抽离为 [ConsumerWidget]，将 [taskTagsProvider] 监听边界隔离在单个 Tile 内，
/// 避免标签变动向上传染导致 [CalendarPage] 与 42 个日期网格全局级联 Rebuild。
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
    final project = ref
        .watch(projectsStreamProvider)
        .value
        ?.where((p) => p.id == task.projectId)
        .firstOrNull;

    return TaskSwipeWrapper(
      task: task,
      hasChildren: hasChildren,
      isDone: effective == TaskStatus.done,
      child: SimpleTaskTile(
        task: task,
        hasChildren: hasChildren,
        isDone: effective == TaskStatus.done,
        isOverdue: isOverdue,
        tags: tags,
        projectName: project?.name,
        projectColor: project?.color,
        progressValue: hasChildren ? taskProgress(task, allTasks) : null,
        onTap: onTap,
        onToggleDone: hasChildren
            ? null
            : (value) => _toggleTaskDone(ref, task, value),
      ),
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
