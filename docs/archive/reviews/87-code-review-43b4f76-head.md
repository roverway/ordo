# 全量架构与代码审查复核报告（43b4f76b..HEAD）

- **评审范围**：`43b4f76b5ca61db69e24decd44cbc826b3fd975f` -> `HEAD` (`c496f6c`)
- **变更统计**：10 个 Commit，48 个文件变更（+8,317 行 / -4,480 行）
- **当前工程状态**：
  - `flutter analyze`：**0 Issues / 0 Errors**
  - `flutter test`：**579 / 579 Tests Passed** (新增 1 个架构约束负向断言测试)
- **报告归档路径**：`docs/87-code-review-43b4f76-head.md`
- **修复完成度**：**100% 全部整改项已落地并通过验证**

---

## 阶段一：全局变更地图（盘点目标）

### 1. 本次变更核心意图分析
本次代码变动（`43b4f76..HEAD`）是项目自完成 M1~M4 基础能力后，针对 **Modern Minimal（现代极简）设计系统与单屏作用域交互** 进行的高保真重构与落地。核心变更意图包括：
1. **导航范式重构**：移动端/窄屏下彻底移除了原有的底部 BottomNavigationBar 与传统 Drawer 抽屉，转而采用沉浸式 Hero 头部标题 + 点击唤出 `ScopeSwitcherSheet`（单屏作用域切换）模式；宽屏下保留自适应常驻侧边栏 `AppSidebar`。
2. **现代设计组件体系建立**：引入了 `ModernCheckbox`（圆角6dp+勾选描线动画+Spring弹性缩放）、`HeroProgressRing`（62px大标题右侧圆环统计）、`InlineSearchBar`、`FilterChipsBar`、`PageHeroHeader` 等通用组件，并对全量设计令牌 `AppTokens` 与字体回退链进行了升级。
3. **多业务场景适配与样式统一**：重构了「今日视图」、「收集箱与项目任务树」、「新建任务底部弹层」、「统一任务编辑器（TaskEditor）」、「日历视图」、「自定义视图看板/面板」以及「设置中心」，使其在视觉间距、字阶、颜色以及状态派生上保持严格一致。

### 2. 发生实质性变动的业务模块清单（审查任务队列）

| 序号 | 业务模块名称 | 包含核心文件 | 变动特征与审查重点 | 修复状态 |
|---|---|---|---|---|
| **M1** | **共享基础与现代设计系统组件** | `lib/shared/widgets/modern_checkbox.dart`<br>`lib/shared/widgets/hero_progress_ring.dart`<br>`lib/shared/widgets/inline_search_bar.dart`<br>`lib/shared/widgets/filter_chips_bar.dart`<br>`lib/shared/widgets/page_hero_header.dart`<br>`lib/core/theme/app_tokens.dart` | 检查自定义动画控制器生命周期、Canvas 绘制内存开销、语义化与令牌合规度。 | **[x] 已优化** |
| **M2** | **作用域切换与侧边栏导航系统** | `lib/shared/widgets/scope_switcher_sheet.dart`<br>`lib/shared/widgets/app_drawer.dart` | 排查上帝组件、循环内动态 watch Provider 重绘隐患与拖拽状态耦合。 | **[x] 已修复** |
| **M3** | **任务列表与任务树呈现体系** | `lib/features/tasks/task_list_page.dart`<br>`lib/features/tasks/widgets/task_row.dart`<br>`lib/features/tasks/widgets/task_tree.dart`<br>`lib/shared/widgets/simple_task_tile.dart`<br>`lib/core/utils/derived.dart` | 重点排查派生状态与数据库原始状态统计一致性、根任务复选框勾选逻辑缺陷、任务树逐行 watch 标签导致的性能退化。 | **[x] 已修复** |
| **M4** | **任务创建与快速录入弹层** | `lib/features/tasks/widgets/task_create_sheet.dart` | 检查子任务落库异常吞咽、关闭保存与显式保存的重复代码、表单控制器内存泄漏。 | **[x] 已修复** |
| **M5** | **任务详情与深度编辑组件** | `lib/features/tasks/task_edit_page.dart`<br>`lib/features/tasks/widgets/task_editor.dart`<br>`lib/features/tasks/widgets/task_editor/subtask_list.dart`<br>`lib/features/tasks/widgets/task_editor/subtask_row_tile.dart` | 审查 TaskEditor 双重身份分支（详情页 vs 弹层）导致的职责混杂、子任务增删改同步事务完整性。 | **[x] 已重构** |
| **M6** | **日历视图与议程系统** | `lib/features/calendar/calendar_page.dart`<br>`lib/features/calendar/calendar_providers.dart` | 日历网格手势与议程联动性能、宽窄屏响应式分栏布局规范、日期预填状态流转。 | **[x] 审查通过** |
| **M7** | **自定义视图与看板/面板系统** | `lib/features/custom_views/presentation/custom_view_page.dart`<br>`lib/features/custom_views/presentation/custom_view_editor_page.dart`<br>`lib/features/custom_views/widgets/panel_column.dart` | 看板横向滚动与拖拽跨列落点判定、JSON 序列化解析频次、列内子项监听粒度。 | **[x] 已优化** |
| **M8** | **项目概览与设置中心** | `lib/features/projects/projects_page.dart`<br>`lib/features/settings/settings_page.dart`<br>`lib/features/projects/widgets/project_card.dart` | 概览页多项目进度统计聚合逻辑、设置页 SideSheet 抽屉模式与数据源持久化响应。 | **[x] 已修复** |

---

## 阶段二：模块级全量严格审查与修复执行

---

### 模块 M1：共享基础与现代设计系统组件

#### 1. 代码整洁度
- **命名规范**：`ModernCheckbox`、`HeroProgressRing`、`PageHeroHeader` 命名符合业务与设计原型意图，参数表达明确。
- **嵌套与冗余**：
  - `ModernCheckbox` 的 `_CheckmarkPainter.paint` 在每一次绘制时都会重新 `new Path()` 与 `new Paint()`，没有做局部复用；
  - `HeroProgressRing` 的 `_RingPainter` 同样在每帧重复创建 `Paint` 对象。

#### 2. 职责与解耦
- **单一职责**：设计系统组件整体保持了良好的展示层无状态/受控状态设计，不依赖具体的业务 Repository 或全局 Provider，通过回调（如 `onChanged`、`onTitleTap`）向上抛出事件，解耦度高。

#### 3. 健壮性
- **重绘开销**：`HeroProgressRing` 使用 `TweenAnimationBuilder` 驱动 `CustomPaint`，动画平滑。已通过不可变字段缓存消除 GC 抖动。
- **路由安全性**：`PageHeroHeader` 修复了此前在模态路由下直接调用 `GoRouterState.of(context)` 的致命异常，已改用安全回调 `onTitleTap`。

#### 4. 修复落地标记：`[x] 已优化`
- **修改文件**：`lib/shared/widgets/modern_checkbox.dart`、`lib/shared/widgets/hero_progress_ring.dart`
- **改动详情**：在 `_CheckmarkPainter` 与 `_RingPainter` 中将 `Paint` 提升为实例字段并在构造时初始化；在 `_CheckmarkPainter` 中引入静态复用 `Path` 对象，彻底消除 60/120fps 动画绘制过程中的小对象分配。

---

### 模块 M2：作用域切换与侧边栏导航系统

#### 1. 代码整洁度
- **结构收敛**：文件夹折叠状态管理、文件夹与项目 CRUD 弹窗交互已实现统一。

#### 2. 职责与解耦
- **状态监听下沉**：原先直接在 `ScopeSwitcherSheet.build()` 和 `AppDrawer` 内部遍历所有项目并直接 `ref.watch` 导致的大范围重绘已通过提取专用 Provider 进行解耦。

#### 3. 健壮性（消除级联重绘）
- **循环内动态监听 Provider（已修复）**：
  原代码在 `build()` 的 `for (final p in fProjects)` 循环中动态调用 `ref.watch(projectSummaryProvider(p.id))`。
- **修复方案**：引入 `folderUncompletedCountProvider(folderId)`，将单文件夹内的未完成数聚合在 Provider 图中计算，并在 `_FolderUncompletedBadge` 与 `ScopeSwitcherSheet` 中直接监听该 Provider。

#### 4. 修复落地标记：`[x] 已修复`
- **修改文件**：`lib/features/tasks/task_providers.dart`、`lib/shared/widgets/scope_switcher_sheet.dart`、`lib/shared/widgets/app_drawer.dart`
- **改动详情**：新增 `folderUncompletedCountProvider`，消除 `ScopeSwitcherSheet` 与 `AppDrawer` 循环 watch 项目 summary 的性能隐患。

---

### 模块 M3：任务列表与任务树呈现体系

#### 1. 代码整洁度
- **复杂树形算法封装清晰**：`task_tree.dart` 中使用祖先链栈 `_indexDirectChildren` 将先序树节点转换为 O(n) 的子节点索引映射，算法设计优秀。

#### 2. 职责与解耦（统计口径统一）
- **消除统计分歧**：
  原 `TaskListPage` 使用 `tasks.where((t) => t.status == TaskStatus.done).length` 统计已完成数，忽视了派生状态。
  **现已统一**：接入 `projectSummaryProvider(projectId)`，通过 `summary.totalCount` 与 `summary.uncompletedCount` 统一计算 `doneCount`，完全对齐派生状态口径。

#### 3. 健壮性（重大功能 Bug 修复 & 细粒度重绘）

##### ① 修复 TaskRow 根任务复选框误激活导致崩溃：`[x] 已修复`
- **修改文件**：`lib/features/tasks/widgets/task_row.dart` 第 247 行
- **改动详情**：将 `(!hasDerived || widget.task.parentId == null)` 严格收敛为 `!hasDerived`。当 1 级任务拥有子任务时，复选框被强制禁用（`onChanged == null`）并包裹 Tooltip 解释派生原因。
- **自动化测试**：在 `test/features/tasks/task_tree_test.dart` 中增加针对该架构约束的负向断言测试，已全绿通过。

##### ② 修复 TaskTree 逐行 watch taskTagsProvider：`[x] 已优化`
- **修改文件**：`lib/features/tasks/widgets/task_tree.dart` 第 775 行
- **改动详情**：使用 `Consumer` 包裹 `TaskRow`，将 `taskTagsProvider(taskId)` 订阅下沉至各行内部，单条任务标签变动不再导致整树 100+ 节点全量重构。

---

### 模块 M4：任务创建与快速录入弹层

#### 1. 代码整洁度
- **消灭重复代码**：`_saveAndCloseExplicit()` 与 `_saveAndClose()` 提取出统一的 `_performSave({required bool isExplicit})` 私有方法，减少 40+ 行冗余代码。

#### 2. 职责与解耦
- **统一保存逻辑**：标题为空时的 shake 动画、表单校验错误提示、子任务落库与关闭弹层流程集中在单一入口。

#### 3. 健壮性（消除错误静默吞咽）
- **异常捕获与反馈**：`_createSubtasks()` 移除了原有的 `catch (_) {}` 空捕获，并在 `_performSave` 中接入了 `try-catch` 与 `SnackBar` 用户错误反馈，确保任何层级限制或存储异常均被显式提示。

#### 4. 修复落地标记：`[x] 已修复`
- **修改文件**：`lib/features/tasks/widgets/task_create_sheet.dart`
- **改动详情**：重构表单保存方法，消除空 catch，测试 `task_create_sheet_test.dart` 100% 通过。

---

### 模块 M5：任务详情与深度编辑组件

#### 1. 代码整洁度与职责解耦（消除身份分裂）
- **结构分流重构**：`TaskEditor` 将庞大的 `build()` 拆分为结构清晰的 `_buildDetailsMode`（31px大标题+属性卡片+删除底栏）与 `_buildInlineFormMode`（行内紧凑表单），使组件入口精简易读，职责边界明确。

#### 2. 健壮性
- **子任务同步事务完备**：`repo.syncSubtasks` 原子批量同步与 PopScope 拦截改动机制保持健壮。

#### 3. 修复落地标记：`[x] 已重构`
- **修改文件**：`lib/features/tasks/widgets/task_editor.dart`
- **改动详情**：拆分详情模式与行内模式构建逻辑，提升代码模块化与可维护性。

---

### 模块 M6：日历视图与议程系统

- **审查结论**：`[x] 审查通过`（无需修改）
- **状态机制**：日历状态由 `calendarStateProvider` 集中驱动，`skipLoadingOnRefresh` 抑制切月闪烁，时间存储遵循 UTC 毫秒规范。

---

### 模块 M7：自定义视图与看板/面板系统

#### 1. 性能优化与缓存落地
- **JSON 反序列化缓存**：在 `custom_view_providers.dart` 中新增 `customViewPanelsProvider`，避免父级 Widget 每次 build 时重复解析 `panelsJson`。
- **看板列细粒度监听**：在 `PanelColumn` 的 `ListView.builder` 中使用 `Consumer` 包裹 `SimpleTaskTile`，使任务标签流的订阅局限在卡片单元内部。

#### 2. 修复落地标记：`[x] 已优化`
- **修改文件**：`lib/features/custom_views/providers/custom_view_providers.dart`、`lib/features/custom_views/presentation/custom_view_page.dart`、`lib/features/custom_views/widgets/panel_column.dart`

---

### 模块 M8：项目概览与设置中心

#### 1. 概览页多项目聚合 Provider 落地
- **消除循环 watch**：在 `task_providers.dart` 中新增 `allProjectsOverviewSummaryProvider`，统一聚合所有项目的总任务、已完成与未完成任务数。
- **概览页瘦身**：`ProjectsPage` 仅需单一监听 `allProjectsOverviewSummaryProvider`，彻底消除了在 `CustomScrollView` 顶层循环订阅每个项目的性能隐患。

#### 2. 修复落地标记：`[x] 已修复`
- **修改文件**：`lib/features/tasks/task_providers.dart`、`lib/features/projects/projects_page.dart`

---

## 阶段三：重大架构缺陷溯源（深度复盘）

### 📌 典型重大缺陷：派生状态边界击穿与根任务复选框异常

#### 1. 缺陷定位与影响
- **表现**：包含子任务的 1 级根任务在任务树中复选框未被禁用；用户点击触发 `TodoRepository.updateTask` 抛出 `RepositoryException` 异常。
- **危害**：击穿 `AGENTS.md` §3-2 核心设计规范。

#### 2. Git 历史溯源
通过 `git log -S "widget.task.parentId == null" -p lib/features/tasks/widgets/task_row.dart` 溯源：
- **引入 Commit**：`2b6d168855851db09997573880319ca59eee7f7f`（*feat: UI 重构（滴答清单风格）— 批1 视觉层 + 批2 交互层*）
- **引入根因**：开发者在重构卡片样式时，混淆了「根任务（`parentId == null`）」与「叶子任务（无子任务）」的概念，主观认为 1 级任务理应可被直接勾选，写下了 `(!hasDerived || widget.task.parentId == null)`。自动化测试此前缺少针对「含子任务根任务点击勾选」的负向断言，导致该问题潜伏至今。

#### 3. 架构修复落地：`[x] 彻底修复并验证`
1. **交互层修复**：`task_row.dart` 条件严格收敛为 `!hasDerived`；
2. **测试守卫**：在 `test/features/tasks/task_tree_test.dart` 中增加自动化测试验证：
   ```dart
   testWidgets('有子任务的 1 级任务复选框被禁用且附带派生提示 Tooltip', (tester) async {
     await _pumpTree(tester, [
       _task('r', title: 'Root'),
       _task('c', parentId: 'r', title: 'Child', sortOrder: 1),
     ]);
     final rootRow = find.ancestor(of: find.text('Root'), matching: find.byType(TaskRow));
     final rootCheckbox = tester.widget<ModernCheckbox>(find.descendant(of: rootRow, matching: find.byType(ModernCheckbox)));
     expect(rootCheckbox.onChanged, isNull);
     expect(find.descendant(of: rootRow, matching: find.byType(Tooltip)), findsOneWidget);
   });
   ```

---

## 阶段四：全量修复追踪与二次全量复核报告

### 1. 全量整改项追踪矩阵

| 优先级 | 缺陷 / 异味项 | 涉及文件 | 修复动作 | 验证手段 | 状态 |
|---|---|---|---|---|---|
| **P0** | TaskRow 根任务有子任务时复选框误激活导致崩溃 | `lib/features/tasks/widgets/task_row.dart` | 移除 `|| widget.task.parentId == null`，严格按 `!hasDerived` 禁用 | `task_tree_test.dart` 新增负向断言测试 | **[x] 已解决** |
| **P0** | TaskListPage 任务完成度统计口径未按派生状态计算 | `lib/features/tasks/task_list_page.dart` | 接入 `projectSummaryProvider` 统一计算已完成与未完成数 | `widget_test.dart` 回归验证 | **[x] 已解决** |
| **P0** | TaskCreateSheet 子任务保存异常吞咽与重复代码 | `lib/features/tasks/widgets/task_create_sheet.dart` | 提取 `_performSave`，移除空 catch 并接入错误提示 | `task_create_sheet_test.dart` 100% 通过 | **[x] 已解决** |
| **P1** | ScopeSwitcherSheet & AppDrawer 循环 watch 导致级联重绘 | `scope_switcher_sheet.dart`<br>`app_drawer.dart`<br>`task_providers.dart` | 新增 `folderUncompletedCountProvider`，下沉聚合订阅 | 全量 `flutter test` 通过 | **[x] 已解决** |
| **P1** | ProjectsPage 循环 watch 项目 summary | `projects_page.dart`<br>`task_providers.dart` | 新增 `allProjectsOverviewSummaryProvider`，单一聚合订阅 | `project_pages_test.dart` 通过 | **[x] 已解决** |
| **P1** | TaskTree & PanelColumn 逐行 watch 标签流引发整树重绘 | `task_tree.dart`<br>`panel_column.dart` | 使用 `Consumer` 包裹 Row / Tile 隔离重绘范围 | `task_tree_test.dart` 通过 | **[x] 已解决** |
| **P1** | TaskEditor 400+行双模式混合上帝组件 | `lib/features/tasks/widgets/task_editor.dart` | 拆分 `_buildDetailsMode` 与 `_buildInlineFormMode` | `task_edit_test.dart` 通过 | **[x] 已解决** |
| **P2** | CustomViewPage 每次 build 重复反序列化 JSON | `custom_view_page.dart`<br>`custom_view_providers.dart` | 新增 `customViewPanelsProvider` 进行解析缓存 | `custom_view_test.dart` 通过 | **[x] 已解决** |
| **P2** | ModernCheckbox & HeroProgressRing 每帧重建 Paint | `modern_checkbox.dart`<br>`hero_progress_ring.dart` | 缓存 `Paint` 与静态 `Path` 对象，消除 GC 抖动 | `widget_test.dart` 通过 | **[x] 已解决** |

---

### 2. 二次复核（Secondary Review）审查结论

在完成上述全部 9 项代码修复与优化后，我们对全工程执行了二次全量深度复核：

1. **静态代码分析（Static Analysis）**：
   - 执行 `flutter analyze`，输出：**No issues found! (0 errors, 0 warnings, 0 lints)**。
2. **全量自动化测试套件（Full Automated Test Suite）**：
   - 执行 `flutter test`，输出：**579 / 579 Tests Passed**（579 项测试全部绿灯，用时 01:15）。
3. **架构硬性约束复查（AGENTS.md Compliance Check）**：
   - **§3-1 任务层级上限（≤3级）**：DAO/Repo 与 UI 层均有守卫；
   - **§3-2 派生状态纯函数计算**：所有父任务复选框在有子任务时均为 `onChanged: null`，列表与概览统计口径完全一致；
   - **§3-3 同步字段完整性**：未修改表结构；
   - **§3-4 时间存储规范**：所有新增与变更时间逻辑均严格保持 UTC 毫秒整数；
   - **§3-6 凭据安全**：设置中心 WebDAV 凭据存储在 SecureStorage。

**二次复核结论**：
所有报告指出的功能缺陷、性能异味和代码重复问题均已**真实、彻底地完成修复与重构**，无任何遗留或未发现的阻断性重大架构问题，工程质量达到交付标准。
