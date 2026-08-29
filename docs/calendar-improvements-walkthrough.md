# 日历界面改进走查（Walkthrough）

本文档总结日历界面的三项功能改进实施情况与自检结果。

---

## 1. 变更总结

### 1.1 任务列表上下滑动联动日历区域（手势边界穿透）
- **实现细节**：
  - 任务列表（`_CalendarAgendaList`）内部滚动优先响应；
  - 监听滚动通知 `ScrollNotification`，记录滑到边界后的溢出位移与释放速度；
  - **下拉到顶**且继续下拉：触发 `setMode(CalendarMode.month)` 展开日历为月视图；
  - **上拉到底**且继续上拉：触发 `setMode(CalendarMode.week)` 收起日历为周视图；
  - 空列表或短列表状态下直接上下滑动亦能顺畅触发月/周模式切换。

### 1.2 「今日」按钮独立外置
- **实现细节**：
  - 在 AppBar `actions` 中，新增独立的 `IconButton`（图标 `Icons.today_outlined`，带 tooltip「回到今天」），位于三点菜单左侧；
  - 从右上角三点弹出菜单中移除了「回到今天」菜单项。

### 1.3 任务列表时间范围控制（当日 / 该周 / 该月）
- **实现细节**：
  - 在 `CalendarState` 与 `CalendarNotifier` 中引入 `CalendarAgendaScope`（`day` / `week` / `month`，默认 `day`）；
  - 右上角三点菜单中新增「当日」、「该周」、「该月」单选条目（通过 `AppMenuItem` 与 `Icons.check` 展现选中态）；
  - 任务筛选与区间交集算法：
    - `calendarAgendaRangeFor(state)` 精确计算所选范围对应的本地时间闭区间；
    - `tasksForAgendaScope` 遍历活跃任务，基于任务时间区间（`[startAt, endAt]`）与选择范围的交集判定（`inTimeRange`）过滤，并按任务时间（`startAt ?? endAt`）升序与 `updatedAt` 降序排列；
    - 列表头部标题（Header）通过 `formatAgendaDateHeader`、`formatAgendaWeekHeader`、`formatAgendaMonthHeader` 动态展示对应范围文案（如「8月11日 星期二」、「8月10日 – 16日 · 本周」、「2026年8月 · 本月」等）。

---

## 2. 代码变更文件清单

| 文件 | 变更说明 |
|---|---|
| [`lib/core/l10n/app_zh.arb`](file:///mnt/Data/Personal/04_others/My_Development/todo/lib/core/l10n/app_zh.arb) | 添加 `calendarScopeDay`、`calendarScopeWeek`、`calendarScopeMonth`、`thisWeek`、`thisMonth` 中文文案 |
| [`lib/core/l10n/app_en.arb`](file:///mnt/Data/Personal/04_others/My_Development/todo/lib/core/l10n/app_en.arb) | 添加对应的英文国际化文案 |
| [`lib/core/utils/dates.dart`](file:///mnt/Data/Personal/04_others/My_Development/todo/lib/core/utils/dates.dart) | 新增 `formatAgendaWeekHeader` 与 `formatAgendaMonthHeader` 议程标题格式化纯函数 |
| [`lib/features/calendar/calendar_providers.dart`](file:///mnt/Data/Personal/04_others/My_Development/todo/lib/features/calendar/calendar_providers.dart) | 新增 `CalendarAgendaScope`、扩展 `CalendarState`、增加 `setAgendaScope` 及 `tasksForAgendaScope` / `calendarAgendaRangeFor` |
| [`lib/features/calendar/calendar_page.dart`](file:///mnt/Data/Personal/04_others/My_Development/todo/lib/features/calendar/calendar_page.dart) | 外置今日按钮、三点菜单新增范围选项组、议程列表支持手势穿透与动态标题联动 |
| [`test/features/calendar/calendar_page_test.dart`](file:///mnt/Data/Personal/04_others/My_Development/todo/test/features/calendar/calendar_page_test.dart) | 补充与更新全套单元测试与 Widget 交互测试 |

---

## 3. 测试与验证结果

- **代码分析**：`flutter analyze` 结果为 `No issues found!`（0 错误 0 告警）。
- **代码格式化**：`dart format .` 全量格式化完成。
- **自动化测试**：`flutter test test/features/calendar/calendar_page_test.dart` 及核心纯函数测试全绿通过（10/10 passed）。
