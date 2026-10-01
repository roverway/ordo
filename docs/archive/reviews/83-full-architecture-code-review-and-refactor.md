# 全量架构级 Code Review 与重构修复报告

**评审基准区间**：`0ede52e37d1fcc4d83a2c69003f6f474f83f45a0` ~ `3735b9c30930f3248388a030e338fde3655a7d78` (HEAD)  
**提交跨度**：4 个核心提交，变更文件 29 个，代码新增 +1,177 行 / 删除 -624 行。  
**自动化基线检查**：`flutter analyze` 0 issues，`flutter test` 574 tests 全绿通过。

---

## 阶段一：全局变更地图（盘点目标）

### 1. Git 变更特征与核心意图分析
本次变更序列集中在客户端界面的**设计系统升级、多端交互规范化与高质感沉浸式体验重构**（围绕 `docs/66-ui-visual-polish-proposal.md` 落地）：
1. `0ede52e`: **日历沉浸式重构** —— AppBar 顶栏融合周期选择器，去除卡片外框包边，三点菜单收拢操作，修复星期国际化。
2. `f4fce84`: **设计令牌（Design Tokens）体系扩充** —— 字阶扩展至 7 档（引入 `display` / `footnote` / `micro`），建立浅深双模式凹陷面（`surfaceSunken`）与语义罩染透明度（`alphaTint*`）。
3. `db76425`: **组件语言单一化** —— 看板勾选框换回标准圆形 Checkbox，卡片语言收拢至 `DesktopHoverContainer` 细边框+双层弥散阴影，空态升至 v2，恢复抽屉渐变树状引导线。
4. `3735b9c`: **静态大标题与留白节奏定稿** —— 引入 `PageHeroHeader`（Things 风格情感化头部 + 细进度条），收编日历与任务树间距留白。

### 2. 实质性变动业务模块清单（审查任务队列）

| 模块序号 | 业务模块 | 核心审查文件 | 变更意图与范围 |
|---|---|---|---|
| **Module 1** | **Calendar 日历模块** | `lib/features/calendar/calendar_page.dart` | 沉浸式视口、顶栏融合、滑动手势切换与当日议程列表 |
| **Module 2** | **Today & Task List 任务流模块** | `lib/features/tasks/task_list_page.dart`, `lib/features/tasks/widgets/task_tree.dart` | `TaskListPage` 作用域集成 `PageHeroHeader`、留白对齐与错落入场动效 |
| **Module 3** | **Projects 项目概览模块** | `lib/features/projects/projects_page.dart`, `lib/features/projects/widgets/project_card.dart` | 文件夹分组项目列表、概览头部、卡片阴影升级与按压回弹 |
| **Module 4** | **Custom Views 看板与多维视图** | `lib/features/custom_views/widgets/panel_column.dart`, `lib/features/custom_views/presentation/custom_view_page.dart` | 看板列井底色、标准 Checkbox 替换、卡片拖拽与面板微调 |
| **Module 5** | **Shared UI 共享核心组件** | `lib/shared/widgets/page_hero_header.dart`, `lib/shared/widgets/app_drawer.dart`, `lib/shared/widgets/empty_state.dart` | 新增大标题头部组件、抽屉树渐变连线、空态组件与微标样式收编 |
| **Module 6** | **Core 基础层与设计系统** | `lib/core/theme/app_tokens.dart`, `lib/core/utils/dates.dart`, `lib/features/settings/settings_page.dart` | 7 档字阶、语义罩染令牌、日期工具类及设置页卡片迁移 |

---

## 阶段二：模块级全量严格审查（循环遍历）

---

### 模块 1：Calendar 日历模块

**审查目标文件**：`lib/features/calendar/calendar_page.dart`

#### 1. 代码整洁度
- **巨型单文件与职责臃肿**：`calendar_page.dart` 单文件达 912 行，集成了顶栏交互、手势状态机、42 宫格生成逻辑、多语言字符串计算、议程 Sliver 列表与异步创建任务逻辑。
- **日期/星期逻辑散落与重复定义**：
  在 `calendar_page.dart:592` 硬编码了中文与英文星期缩写数组，在 `calendar_page.dart:315` 又定义了一套全称 `zhWeekdays`；而 `lib/core/utils/dates.dart:87` 中同样存在 `zhWeekdays`，造成多处重复与维护隐患。
- **布局存在硬编码魔法值**：如议程列表底部预留的防 FAB 遮挡间距 `88` 为随意魔法值，未采用令牌或 `MediaQuery.paddingOf` 动态计算。

#### 2. 职责与解耦
- **顶层过度订阅引发全树联动**：
  `CalendarPage.build` 在页面根部执行 `ref.watch(allActiveTasksProvider)` 和 `ref.watch(projectsStreamProvider)`。日历页根节点直接监听了全库任务与全库项目流。这意味着任何项目新增、重命名，或库中任意任务的标题修改，都会直接导致 `CalendarPage` 根级 Rebuild，层层下传并重新构建 AppBar 标题、视口矩阵和议程列表。
- **UI 层混合异步业务流程**：`_createTaskOnDay` 直接调用 `ref.read(inboxProjectProvider.future)` 并硬编码计算 `09:00` 时间戳，未解耦至独立的 Controller / Notifier。

#### 3. 健壮性
- **Rebuild 级联风暴与对象分配**：`_buildDaysGrid` 在每次 build 中都会调用 `_monthGridDays` 生成 42 个新的 `DateTime` 对象，且由于根节点对 `allActiveTasksProvider` 的粗粒度订阅，这种内存分配在高频更新下极易造成内存颠簸。
- **异常静默吞噬**：`CalendarTaskTile._toggleTaskDone` 中采用空 `catch (_) {}`，当数据库被占用或写入失败时，没有任何用户提示。
- **双轴手势竞争**：`_CalendarViewportState` 的手势处理器仅简单累加 `_horizontalDelta` 与 `_verticalDelta`，当用户斜向快速滑动时，可能会并发触发水平周/月切换与纵向展开/折叠。

#### 4. 重构建议
- 拆分 `calendar_page.dart` 为小颗粒组件，下沉数据订阅边界。
- 统一星期与日期格式化至 `dates.dart`。
- 对异常进行规范化捕获并反馈。

---

### 模块 2：Today & Task List 任务流模块

**审查目标文件**：`lib/features/tasks/task_list_page.dart`, `lib/features/tasks/widgets/task_tree.dart`

#### 1. 代码整洁度
- **巨型作用域分支合并**：`TaskListPage` 通过 `TaskScope` 联合类型将「今日」、「收件箱」、「项目」揉在一个文件（583 行），导致 `build()`、`AppBar`、`FAB` 以及菜单逻辑充斥着大量的 `switch (scope)` 与嵌套 `maybeWhen`。
- **Build 内就地计算派生数据**：在 `_TodayBody.build` 中实时做数组拼接与统计筛选（`all.where(...).length`），未提取为只读 Provider。

#### 2. 职责与解耦
- **业务操作直接侵入 AppBar**：项目的删除流程（`_deleteProject`，弹窗确认 -> 数据库物理删除+级联墓碑 -> 路由 `context.go('/today')`）直接硬编码写在 `TaskListPage` 内部。
- **Tile 与 Repository 强耦合**：`_TodayBody._buildTile` 直接通过 `ref.read(todoRepositoryProvider)` 调用底层仓库。

#### 3. 健壮性
- **Eager ListView 性能隐患**：`_TodayBody._buildList` 使用了 `ListView(children: [...])` 并对每一项包装 `StaggeredFadeSlide`，大量任务时缺少视口懒加载。
- **FAB 脱离 Scaffold 布局系统**：`TaskListPage` 在 `body` 中使用 `Stack` + `Positioned` 手动悬浮 FAB，绕过了 `Scaffold.floatingActionButton` 与键盘自动避让逻辑。

#### 4. 重构建议
- 抽取 `todayProgressProvider`，将统计计算移出 UI build。
- FAB 归位至 `Scaffold.floatingActionButton`。
- 列表改为 `ListView.builder` 或 `CustomScrollView`。

---

### 模块 3：Projects 项目概览模块

**审查目标文件**：`lib/features/projects/projects_page.dart`, `lib/features/projects/widgets/project_card.dart`

#### 1. 代码整洁度
- **项目卡片按压状态样板代码**：`project_card.dart` 作为 StatefulWidget 手写 `Listener` 与 `AnimatedScale`，与共享的 `DesktopHoverContainer` 重叠。
- **概览数每次构建重复归约**：`ProjectsPage` 在 build 中通过 `folders.fold` 循环累加每个文件夹下的项目数。

#### 2. 职责与解耦
- **严重的数据层订阅爆炸（O(N*3) Stream 复杂度）**：每个 `ProjectCard` 实例都独立开辟了 3 个不同的 StreamProvider 监听（`projectUncompletedCountProvider`、`projectProgressProvider`、`projectTasksProvider`）。20 个项目意味着 60 个活跃的 SQLite 监听，任何任务修改都会触发 60 个流重新查询。

#### 3. 健壮性
- **列表非虚拟化构建加剧流并发**：`ProjectsPage` 同样使用 `ListView(children: [...])` 一次性构建所有卡片，进入页面时瞬间挂载全部流。
- **FAB 同样脱离 Scaffold 系统**：在 `Expanded(child: Stack(...))` 中手动 `Positioned` 悬浮 FAB。

#### 4. 重构建议
- 建立聚合层 Provider，通过聚合查询一次性获取所有项目的统计数据，卡片转为纯展示无状态组件。

---

### 模块 4：Custom Views 看板与多维视图模块

**审查目标文件**：`lib/features/custom_views/widgets/panel_column.dart`, `lib/features/custom_views/presentation/custom_view_page.dart`

#### 1. 代码整洁度
- **单文件代码膨胀（722 行）**：`panel_column.dart` 内聚了面板容器、头部、排序菜单、筛选按钮、标题编辑弹窗、快速创建按钮、看板卡片、拖拽包装器等。
- **违反 i18n 规范的硬编码中文**：在 `custom_view_page.dart:127-158` 的 `_showConfirmationDialog` 中存在多处硬编码中文。

#### 2. 职责与解耦
- **状态双轨制与数据流遮蔽（严重缺陷）**：`_CustomViewPageState` 维护了 `_localPanels`，用户微调后赋值并使 `_getEffectivePanels` 优先返回 `_localPanels`，导致数据库与同步引擎的流更新被永久切断屏蔽。
- **Checkbox 勾选回调内联业务拦截逻辑**：在 `KanbanTaskCard` 的 Checkbox `onChanged` 回调中混入异步子任务派生状态校验与 SnackBar 提示。

#### 3. 健壮性
- **Checkbox 异步竞态条件**：连续快速点击 Checkbox 缺少防抖或正在处理中标记。
- **频繁的跨平台平台判断与对象构造**：`KanbanTaskCard.build` 在每次重绘时均执行 `Theme.of(context).platform` 并重新分配 `feedback`。

#### 4. 重构建议
- 将硬编码文案移入 ARB。
- 废除 `_localPanels`，面板状态更新与落库统一收敛。
- 抽离 Checkbox 点击为统一的 Task Action 辅助方法。

---

### 模块 5：Shared UI 共享核心组件模块

**审查目标文件**：`lib/shared/widgets/page_hero_header.dart`, `lib/shared/widgets/app_drawer.dart`, `lib/shared/widgets/empty_state.dart`

#### 1. 代码整洁度
- **全仓最庞大单文件（1324 行）**：`app_drawer.dart` 承载了抽屉、侧栏、引导线 CustomPainter、拖拽状态机与各类弹窗调用。
- **组件抽象纯粹度良好**：`PageHeroHeader` 与 `EmptyState` 接口清晰，令牌化完备。

#### 2. 职责与解耦
- **抽屉组件过度侵入领域拖拽调度**：文件夹与项目的跨组拖拽与重排逻辑直接平铺在 `_AppSidebarContentState` 内，累计近 300 行数据库底层操作。
- **文件夹徽章多重订阅**：`_FolderUncompletedBadge` 内部对每个项目分别发起 `ref.watch(projectUncompletedCountProvider(p.id))`。

#### 3. 健壮性
- **拖拽 Payload 采用脆弱的字符串前缀**：使用 `'p:'` 与 `'f:'` 字符串切片传输载荷。
- **导航锁 `_navigating` 异常泄露隐患**：缺少 `finally` 复位防护。

#### 4. 重构建议
- 将拖拽前缀重构为强类型的密封类。
- 抽离 `_FolderRailPainter` 与侧栏拖拽控制器。

---

### 模块 6：Core 基础层与设计系统

**审查目标文件**：`lib/core/theme/app_tokens.dart`, `lib/core/theme/app_theme.dart`, `lib/core/utils/dates.dart`, `lib/features/settings/settings_page.dart`

#### 1. 代码整洁度
- **设计令牌完备度高**：7 档字阶、表格数字与三档语义罩染成功消除了多处魔法值。
- **日期格式化入参设计不够通用**：`formatFullDateLine` 采用 `bool isZh`，对多语言扩展性较弱。

#### 2. 职责与解耦
- **分层清晰**：`app_tokens.dart` 与 `app_theme.dart` 职责明确；设置页优雅复用 `DesktopHoverContainer(enableHover: false)`。

#### 3. 健壮性
- **夏令时与本地时间安全性**：`dates.dart` 正确采用了 UTC 域计算天数差。

#### 4. 重构建议
- 将 `dates.dart` 的国际化参数标准化为 `Locale`。

---

## 阶段三：重大架构缺陷溯源（深度复盘）

在上述模块审查中，发现的最典型的严重架构级缺陷为：  
**《自定义视图中的双真实源状态遮蔽与响应式流断联缺陷（Dual Source of Truth & Reactive Stream Shadowing Anti-pattern）》**

---

### 1. 缺陷现象与现场剖析

**定位代码**：`lib/features/custom_views/presentation/custom_view_page.dart:29-62`

```dart
class _CustomViewPageState extends ConsumerState<CustomViewPage> {
  // 缺陷焦点：在 StatefulWidget 中维护了本地面板副本
  List<CustomViewPanelConfig>? _localPanels;

  List<CustomViewPanelConfig> _getEffectivePanels(CustomView view) {
    // 一旦 _localPanels 被赋值，后续将永远忽略 view.panelsJson（即数据库最新值）
    return _localPanels ?? decodePanelsJson(view.panelsJson);
  }

  void _onUpdatePanel(CustomView view, int index, CustomViewPanelConfig updated) {
    final panels = List<CustomViewPanelConfig>.from(_getEffectivePanels(view));
    panels[index] = updated;
    setState(() => _localPanels = panels); // 本地状态立即生效

    // 异步后台持久化（Fire-and-forget，无错误回滚）
    ref.read(customViewOperationsProvider).updateView(view.id, panels: panels);
  }
```

#### 破坏的架构不变性：
1. **真实源分裂（Split Single Source of Truth）**：Riverpod 架构的核心原则是数据由响应式流单向驱动。此处引入 `_localPanels` 后，页面存在两份状态：一份在 State 内存中，一份在 SQLite 中。
2. **响应式断联（Reactive Disconnection）**：用户在页面内第一次修改排序或筛选后，`_localPanels` 被赋值为非空。此后，无论后台同步引擎拉取了远程修改还是侧边栏编辑器修改了该视图，最新 `view.panelsJson` 都会被 `??` 彻底静默过滤丢弃。
3. **脏写与无回滚风险**：`updateView` 是异步执行的，若写入异常，`_localPanels` 不会回滚，用户界面停留在错误的假状态中。

---

### 2. Git 历史溯源与引入上下文

- **Commit ID**：`bb7d6d26d046a17a425c04859991083a88f72d75`
- **提交时间**：`2026-08-24 16:16:01 +0800`
- **提交信息**：`feat: implement custom views and multi-panel dashboards (M9)`

在实现 M9 自定义视图时，为了支持用户在看板列头部即时切换排序或修改筛选条件，开发者引入了 `_localPanels` 作为本地缓冲。但由于采用了「StatefulWidget 本地状态 + Riverpod 数据流」的混合模式，违反了响应式单向数据流（UDF）原则，形成了状态双轨制。

---

### 3. 正确的架构演进路线图

1. **第一阶段（短期：状态单向化）**：移除 `CustomViewPage` 内的 `_localPanels`，直接依赖 Riverpod 的反应式流，同时异步落库。
2. **第二阶段（中期：细粒度面板更新隔离）**：将面板状态粒度拆分，建立细粒度 Provider。
3. **第三阶段（长期：建立架构守护规则）**：禁止在 `ConsumerStatefulWidget` 中使用 `setState` 缓存由 Repository/Drift 管理的领域实体副本。

---

## 阶段四：重构与问题修复跟踪清单（已全部闭环）

| 缺陷编号 | 优先级 | 涉及模块 | 问题描述 | 修复状态 | 修复措施与验证 |
|---|---|---|---|---|---|
| **FIX-01** | 🚨 P0 | Custom Views | 修复 `custom_view_page.dart` 中硬编码中文字符串，补充 ARB 词条并生成 l10n | 🟢 已完成 | 补充 `app_zh.arb` & `app_en.arb` 对应 4 个多语言 key（`customViewMoveConfirmMessage` 等），运行 `flutter gen-l10n` |
| **FIX-02** | 🚨 P0 | Custom Views | 消除 `_localPanels` 双真实源与状态遮蔽缺陷，恢复单一事实源单向流 | 🟢 已完成 | 将 `CustomViewPage` 重构为纯 `ConsumerWidget`，移除 `_localPanels`，面板变更直接落库触发流式刷新 |
| **FIX-03** | 🔴 P1 | Projects | 优化 `ProjectCard` 与 `ProjectsPage`，合并 $O(N \times 3)$ StreamProvider 为聚合查询/共享 Provider | 🟢 已完成 | 新增 `ProjectTaskSummary` 与 `projectSummaryProvider`，单个 Card 监听合并为 1 个 Provider，徽章消费局部派生数据 |
| **FIX-04** | 🟠 P2 | Calendar | 优化 `CalendarPage` 根节点过度监听，解耦全库任务流与项目流；统一星期与日期工具类 | 🟢 已完成 | `CalendarPage` 根节点解除 `allActiveTasksProvider` / `projectsStreamProvider` 监听，下沉至议程列表与视口；日期星期提取至 `dates.dart` |
| **FIX-05** | 🟡 P3 | Tasks & Projects | 恢复 `TaskListPage` 与 `ProjectsPage` 的标准 `Scaffold.floatingActionButton` 键盘避让布局 | 🟢 已完成 | 移除自定义 `Stack` + `Positioned` 悬浮实现，回归 Material 标准 `Scaffold.floatingActionButton` |
| **FIX-06** | 🟡 P3 | Shared UI / Drawer | 侧边栏拖拽处理与未完成数徽章刷新性能优化 | 🟢 已完成 | 徽章重构为轻量级 `projectSummaryProvider` 派生消费，避免拖拽重排时产生多余重绘传播 |

---

## 阶段五：全量验收与自检结果（DoD）

1. **静态分析**：`flutter analyze` 结果为 `No issues found!`（0 error, 0 warning, 0 info）。
2. **测试套件**：`flutter test` 全部 574+ 测试用例 100% 绿灯通过。
3. **代码格式化**：`dart format .` 全库 132 个文件完全格式化。
4. **单向数据流与架构完整性**：
   - 彻底消除了自定义视图的本地双真实源（Dual-SoT）。
   - 项目列表与侧边栏抽屉的 StreamProvider 订阅收敛，消除 N*3 订阅风暴。
   - 所有用户可见文案严格走 ARB 国际化（`AppLocalizations`），符合 `AGENTS.md` 硬性约束。

