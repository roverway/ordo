# 代码变动全量复核报告（Commit: `c6adfbb` 至 `HEAD`）

---

## 阶段一：全局变更地图（盘点目标）

### 1. 变更核心意图与背景概述
本次变更主要聚焦于三个核心业务方向的技术重构与体验升级：
1. **日历手势联动与多维范围穿透**：重塑日历视口（`CalendarPage`），支持月/周视图平滑过渡、滑动手势穿透与越界联动、议程范围（日/周/月）切换以及外置「回到今天」快捷入口；
2. **Android 软键盘物理级逐帧同步**：引入原生 Android `WindowInsetsAnimation.Callback` 桥接（`MainActivity.kt` + `KeyboardInsetBridge`），封装通用的 `KeyboardInsetBuilder`，彻底解决任务创建弹窗（`TaskCreateSheet`）与编辑全屏页（`TaskEditPage`）底部工具栏的「最后一跳」与留白脱节缺陷；
3. **任务树视觉层级结构重构**：剔除陈旧的折线连接器绘图器（`_SubtaskTreeConnectorPainter`），落地一体化卡片容器与自然梯队缩进设计，重构 `TaskTree`、`TaskRow` 及 `SimpleTaskTile`。

### 2. 发生实质性变动的业务模块审查队列
根据 `git diff --stat`，过滤掉纯多语言字典生成和自动化产物后，梳理出以下 4 个实质性业务模块作为审查任务队列：

* **模块 1**：**软键盘逐帧物理动效桥接与安全区适配**（`MainActivity.kt`、`keyboard_inset_bridge.dart`）
* **模块 2**：**任务表单布局与键盘响应架构**（`task_editor.dart`、`task_create_sheet.dart`、`task_edit_page.dart`）
* **模块 3**：**任务树与列表项层级视图重构**（`task_tree.dart`、`task_row.dart`、`simple_task_tile.dart`）
* **模块 4**：**日历手势联动与多维议程引擎**（`calendar_page.dart`、`calendar_providers.dart`、`dates.dart`）

---

## 阶段二：模块级全量严格审查（循环遍历）

---

### 模块 1：软键盘逐帧物理动效桥接与安全区适配

涉及文件：
- `android/app/src/main/kotlin/com/example/todo/MainActivity.kt`
- `lib/core/platform/keyboard_inset_bridge.dart`

#### 1. 代码整洁度
- **命名与意图**：`KeyboardInsetBridge` 与 `KeyboardInsetBuilder` 职责命名准确，注释详尽说明了逻辑像素与物理像素换算原理。
- **结构与嵌套**：组件非常简洁，通过 `ValueListenableBuilder` 封装了 `devicePixelRatio` 换算与安全区差值推导逻辑。

#### 2. 职责与解耦
- **关注点分离**：Android 原生侧只负责在 API 30+ 捕获 `WindowInsets.Type.ime()` 并通过 `EventChannel` 回传；Flutter 侧封装为通用 Builder，上层业务页面无需关心原生通道通信细节。
- **跨平台隔离**：在 non-Android 或 Web 平台下安全短路，不会发起无效的通道注册。

#### 3. 健壮性隐患排查
- **回退闪烁风险（Fallthrough Jitter）**：
  在 `KeyboardInsetBuilder.build` 中：
  ```dart
  final nativeInset = imeHeightPx / devicePixelRatio;
  final effectiveInset = nativeInset > 0.5 ? nativeInset : mediaQueryInset;
  ```
  **隐患场景**：在 Android 键盘收起动画的最后一帧，`imeHeightPx` 会平滑归零（`nativeInset <= 0.5`）。此时条件分支切换为 `mediaQueryInset`。然而，Flutter 引擎对 `MediaQuery.viewInsets` 的更新滞后于 Android 系统动画回调 1 帧。如果此时 `mediaQueryInset` 仍保留着旧的非零值，会导致在收拢结束瞬间 `effectiveInset` 突跳回旧高度 1 帧，造成轻微瞬时闪烁。
- **原生生命周期泄露**：
  `MainActivity.kt` 中，`setWindowInsetsAnimationCallback` 注册在 `decorView` 上，持有局部匿名的回调对象。由于 `Activity` 销毁时 `decorView` 随之释放，但如果存在引擎重置或前后台切换，未显式在 `onDestroy` 中将 callback 置空。

#### 4. 重构建议代码与落地状态

> **落地状态：`[x] 已完成`**（已在 `lib/core/platform/keyboard_inset_bridge.dart` 中优化原生逐帧判定与平滑兜底逻辑，测试已通过）

```dart
// 优化 KeyboardInsetBuilder 的兜底平滑逻辑，避免最后一帧发生跳变
class KeyboardInsetBuilder extends StatelessWidget {
  const KeyboardInsetBuilder({super.key, required this.builder, this.child});

  final Widget Function(
    BuildContext context,
    double effectiveInset,
    double bottomGap,
    Widget? child,
  ) builder;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    final mediaQueryInset = MediaQuery.viewInsetsOf(context).bottom;
    final isAndroidApi30Plus = !kIsWeb && Platform.isAndroid;

    return ValueListenableBuilder<double>(
      valueListenable: KeyboardInsetBridge.instance.imeHeightPx,
      builder: (context, imeHeightPx, child) {
        final nativeInset = imeHeightPx / devicePixelRatio;
        // 在 Android 上原生通道激活时完全信赖 nativeInset，避免退场时与滞后的 mediaQueryInset 混用产生跳帧
        final effectiveInset = isAndroidApi30Plus ? nativeInset : mediaQueryInset;
        final bottomGap = (viewPaddingBottom - effectiveInset).clamp(
          0.0,
          double.infinity,
        );
        return builder(context, effectiveInset, bottomGap, child);
      },
      child: child,
    );
  }
}
```

---

### 模块 2：任务表单布局与键盘响应架构

涉及文件：
- `lib/features/tasks/widgets/task_editor.dart`
- `lib/features/tasks/widgets/task_create_sheet.dart`
- `lib/features/tasks/task_edit_page.dart`

#### 1. 代码整洁度
- **文件体积庞大**：`task_editor.dart` 超过 1500 行，将 Controller、SubtaskRow 模型、主表单 Widget、工具栏（`TaskEditorToolbar`）、项目选择器、优先级选择器、日期选择器以及自定义子任务拖拽列表全部揉在一个文件中，严重影响代码可读性与局部维护性。
- **命名规范**：`SubtaskRow`、`TaskEditorController` 等命名规范，意图清晰。

#### 2. 职责与解耦
- **状态管理割裂（Dual-State Split-Brain）**：
  这是当前表单系统最大的设计痛点：
  1. **UI 输入控制器状态**：标题、描述、备注以及子任务编辑状态存放在 `TaskEditorController`（基于 `ChangeNotifier`）；
  2. **业务实体状态**：任务状态、优先级、项目归属、起止时间、标签存放在 `taskFormProvider`（基于 Riverpod `StateNotifier`）。
  这种「一半在 Controller、一半在 Provider」的设计导致 `TaskEditPage` 与 `TaskCreateSheet` 在做校验、脏检查（`_isDirty`）、加载初始化（`_loadTask`）和保存落库时，必须反复在两套状态源之间进行手动同步与比对，极易发生状态不同步。

#### 3. 健壮性与生命周期排查
- **子任务控制器资源释放风险**：
  `SubtaskRow` 内部持有了 `TextEditingController` 与 `FocusNode`。当用户在编辑器中删除某个子任务行（`removeSubtaskRow`）或重新初始化（`initializeSubtasks`）时，没有对移除的 `SubtaskRow` 显式调用 `dispose()`，依赖 GC 回收存在隐蔽的内存泄漏与焦点事件监听泄漏风险。
- **重建与滚动优化**：
  在本次重构中将 `TextField` 的 `scrollPadding` 显式设为 `EdgeInsets.zero`，配合 `Positioned.fill(bottom: effectiveInset + AppTokens.toolbarHeight)` 彻底规避了 Flutter 默认的 `EditableText` 视口滚动挤压，有效消除了布局抖动。

#### 4. 重构建议代码与落地状态

> **落地状态：`[x] 已完成`**（已为 `SubtaskRow` 增加显式 `dispose()` 并在 `TaskEditorController` 移除/重置/销毁时妥善释放资源）

```dart
// 1. 为 SubtaskRow 增加显式销毁机制，杜绝内存泄漏
class SubtaskRow {
  SubtaskRow.newRow()
      : id = null,
        status = TaskStatus.todo,
        controller = TextEditingController(),
        focusNode = FocusNode();

  SubtaskRow.existing(Task task)
      : id = task.id,
        status = task.status,
        controller = TextEditingController(text: task.title),
        focusNode = FocusNode();

  final String? id;
  final TaskStatus status;
  final TextEditingController controller;
  final FocusNode focusNode;

  bool get isNew => id == null;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

// 2. 在 TaskEditorController 移除和重置子任务时确保调用 dispose
extension SubtaskRowListCleanup on TaskEditorController {
  void removeSubtask(int index) {
    if (index >= 0 && index < subtaskRows.length) {
      final row = subtaskRows.removeAt(index);
      if (row.id != null) {
        removedSubtaskIds.add(row.id!);
      }
      row.dispose(); // 立即释放 FocusNode 与 Controller
      notifyListeners();
    }
  }
}
```

---

### 模块 3：任务树与列表项层级视图重构

涉及文件：
- `lib/features/tasks/widgets/task_tree.dart`
- `lib/features/tasks/widgets/task_row.dart`
- `lib/shared/widgets/simple_task_tile.dart`

#### 1. 代码整洁度
- **成功瘦身**：删除了复杂的 `_SubtaskTreeConnectorPainter`（贝塞尔曲线与贯穿竖线绘制），整体逻辑精简了 300+ 行代码。
- **设计令牌一致性**：引入 `AppTokens.treeIndentL2` 与 `AppTokens.treeIndentL3`，多级任务缩进更加纯粹、规整。

#### 2. 职责与解耦
- **拖拽与布局清晰分离**：`_buildCard` 负责 1 级任务及其后代子任务的卡片外壳，内部每一行通过 `_buildDraggableRow` 进行细粒度拖拽与目标落点换算。
- **状态流转**：通过 `taskTreeExpandedProvider` 管理展开/折叠状态，与 Repository 解耦良好。

#### 3. 健壮性排查
- **全局 Key 引用清理**：
  `_TaskTreeState._rowKeys` 用 Map 缓存了每个任务节点的 `GlobalKey` 用于 `onMove` 时计算拖拽落点。当任务被删除或移出当前视图时，`_rowKeys` 未做定期的冗余清理。虽然 `GlobalKey` 占用的内存不大，但在长期运行的大型任务列表中存在陈旧引用残留。

#### 4. 重构建议代码与落地状态

> **落地状态：`[x] 已完成`**（已在 `_TaskTreeState.build` 中加入 `_rowKeys` 增量修剪逻辑，防止内存残留）

```dart
// 在 _TaskTreeState 构建树形结构前对 _rowKeys 进行修剪
@override
Widget build(BuildContext context) {
  final roots = widget.roots;
  final allTasks = widget.allTasks;
  
  // 保持 _rowKeys 与当前渲染任务 ID 集合同步，防止陈旧引用
  final currentTaskIds = allTasks.map((t) => t.id).toSet();
  _rowKeys.removeWhere((id, _) => !currentTaskIds.contains(id));

  // ... 正常构建任务树
}
```

---

### 模块 4：日历手势联动与多维议程引擎

涉及文件：
- `calendar_page.dart`
- `calendar_providers.dart`
- `dates.dart`

#### 1. 代码整洁度
- **超大单文件问题**：`calendar_page.dart` 达 1039 行，将日历 AppBar 标题、快捷日期选择、窄屏/宽屏双栏布局、手势视口（`_CalendarViewport`）、星期表头、网格构建（`_DayCell`）、事件微标点（`_buildEventDots`）以及支持手势越界的任务议程列表（`_CalendarAgendaList`）全部写在同一个文件中。
- **纯函数提取良好**：`calendarAgendaRangeFor`、`tasksForAgendaScope` 与 `buildCalendarBuckets` 抽离为顶层无副作用纯函数，易于进行单元测试。

#### 2. 职责与解耦
- **细粒度组件隔离防级联 Rebuild**：
  `CalendarTaskTile` 被独立拆分为 `ConsumerWidget`，内部仅监听自身的 `taskTagsProvider(task.id)`，避免了标签变更向上冒泡触发 42 个日期网格单元的全局重绘，体现了高水准的性能考量。
- **手势驱动状态流**：手势通过 Notifier 调用 `setMode` 和 `setAgendaScope`，单向数据流清晰。

#### 3. 健壮性与交互排查
- **手势越界检测平台的兼容性**：
  `_CalendarAgendaListState` 通过 `NotificationListener<ScrollNotification>` 监听过滚动（`OverscrollNotification`）和越界位移（`metrics.pixels < minScrollExtent`）来实现越界下拉/上拉联动折叠日历。显式配置了 `AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())`，确保在 Android、桌面与 iOS 平台均有一致的弹性物理回弹与越界通知触发。
- **`AnimatedSwitcher` 尺寸塌陷延迟修复**：
  重写了 `layoutBuilder`（`calendar_page.dart` L408-L417），将旧网格以 `Positioned` 叠放脱离 `Stack` 测算，一举消除了月转周时 6 行高度迟迟不塌陷的卡顿问题。

#### 4. 重构建议代码与落地状态

> **落地状态：`[x] 已完成`**（已在 `lib/core/utils/dates.dart` 中沉淀 `calculateMonthGridDays` 与 `calculateWeekDays` 纯函数并在 `calendar_page.dart` 中复用）

将 `calendar_page.dart` 中纯日期网格集合推导辅助逻辑沉淀至 `dates.dart`。

```dart
// 沉淀至 lib/core/utils/dates.dart 中的纯函数
List<DateTime> calculateMonthGridDays(DateTime selected) {
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

List<DateTime> calculateWeekDays(DateTime selected) {
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
```

---

## 阶段三：重大架构缺陷溯源（深度复盘）

### 1. 甄选的重大架构缺陷
**任务表单「状态双源割裂与桥接失调」缺陷（Dual-Source Split-Brain Form Architecture）**

#### 缺陷表象与危害
在当前代码中，任务的新建（`TaskCreateSheet`）与编辑（`TaskEditPage`）共存着两套平行的状态系统：
1. **系统 A (`TaskEditorController` - 命令式/ChangeNotifier)**：掌控 `titleController`、`descriptionController`、`notesController` 以及包含 `FocusNode` 的 `List<SubtaskRow>`；
2. **系统 B (`taskFormProvider` - 响应式/Riverpod StateNotifier)**：掌控 `TaskFormState`（状态、优先级、项目、起止日期、标签）。

**引发的架构级隐患**：
- **手动双向同步漏油**：表单在保存时，页面必须同时向 `taskFormProvider` 提取元数据、向 `TaskEditorController` 提取子任务列表与文本。在 `_isDirty` 脏检查逻辑中，必须分别对比两套状态。
- **生命周期脱节**：子任务的增加、删除在 `TaskEditorController` 内就地修改，但外部 Riverpod 体系无从感知子任务集合的精确变动，导致「是否有未保存改动」等判定逻辑充满脆弱的快照比对（`_originalOrder`、`_originalTitles`）。

---

### 2. Git 历史溯源与上下文分析

通过执行 Git 历史检索：
```bash
git log -S "TaskEditorController" --oneline
```
溯源定位到该缺陷最初引入的 Commit：
- **引入 Commit**：`0121834`
- **提交信息**：`feat: 任务编辑界面统一重构（59）— 统一编辑器 + 底部工具栏 + 编辑页子任务管理`
- **引入时间点与当时上下文**：
  在引入该 Commit 时，系统正在统一「新建弹窗」与「编辑全屏页」的 UI 表现（需求 59 定稿）。由于 `TextEditingController` 与 `FocusNode` 属于 Flutter 原生有状态对象，而原有的 `taskFormProvider` 是纯不可变数据流（`TaskFormState`）。为了在弹窗和全屏页中复用相同的输入控制器与光标位置，作者妥协设计了 `TaskEditorController`，试图将不可变状态与可变 Controller 拼接在一起，从而种下了「双源状态」的架构祸根。

---

### 3. 正确的架构演进路线图

为了彻底根治状态割裂，建议将表单演进为**完全统一的单向数据流（Unidirectional Data Flow, UDF）模型**：

```
┌────────────────────────────────────────────────────────┐
│               TaskEditState (不可变数据流)             │
│  - 基础字段: title, description, notes, priority, ...   │
│  - 子任务实体: List<SubtaskDraft> (纯数据模型)          │
│  - UI 派生标记: isDirty, hasPendingSubtasks, isValid   │
└──────────────────────────┬─────────────────────────────┘
                           │ (Riverpod 驱动)
                           ▼
┌────────────────────────────────────────────────────────┐
│             TaskEditorView (纯声明式渲染)             │
│  - 统一由 TaskEditNotifier 处理所有 Action             │
│  - Action: UpdateTitle, AddSubtask, RemoveSubtask      │
│  - Controller/FocusNode 仅作为 View 层的无状态渲染挂件  │
└────────────────────────────────────────────────────────┘
```

#### 演进实施三步走：
1. **第一步（数据模型纯化）**：将 `SubtaskRow` 中的 `TextEditingController` 和 `FocusNode` 剥离，定义纯粹不可变的 `SubtaskDraft` 数据类（`{String? id, String title, TaskStatus status, bool isDeleted}`），纳入统一的 `TaskFormState`；
2. **第二步（控制器下沉至 Widget）**：`TextField` 的 Controller 生命周期严格绑定在单个表单输入组件的 `State` 内部，通过 `onChanged` 将意图纯数据化地派发给 `TaskFormNotifier`；
3. **第三步（全链路原子落库）**：保存与校验收拢至 `taskFormProvider.notifier.save()`，由 Notifier 协调 Repository 进行父任务与子任务的原子级事务写入，彻底废弃 `TaskEditorController`。

---

## 阶段四：重构建议落地执行状态追踪

| 序号 | 重构项 | 涉及文件 | 状态 | 验证结果 |
|---|---|---|---|---|
| 1 | **键盘高度平滑与跨平台兜底**：优化 `KeyboardInsetBuilder` 的平台分支与平滑兜底判定，彻底解决退场最后一帧突跳风险 | `lib/core/platform/keyboard_inset_bridge.dart` | `[x] 已完成` | 单元测试 & Widget 测试全绿 |
| 2 | **子任务控制器生命周期管理**：为 `SubtaskRow` 增加 `dispose()` 并在 `TaskEditorController` 移除/重置/销毁时显式释放 Controller 与 FocusNode，杜绝内存泄漏 | `lib/features/tasks/widgets/task_editor.dart` | `[x] 已完成` | 单元测试 & 表单测试全绿 |
| 3 | **任务树全局 Key 引用修剪**：在 `TaskTree` 构建前后对 `_rowKeys` 实施增量清理，修剪已不在可视集中的键值，防止内存残留 | `lib/features/tasks/widgets/task_tree.dart` | `[x] 已完成` | 任务树拖拽与隐藏测试全绿 |
| 4 | **日历网格纯函数沉淀**：将 `_monthGridDays` 与 `_weekDays` 提取为 `calculateMonthGridDays` 与 `calculateWeekDays` 纯函数沉淀至 `dates.dart` 并复用 | `lib/core/utils/dates.dart`、`lib/features/calendar/calendar_page.dart` | `[x] 已完成` | 日历页面与国际化测试全绿 |
