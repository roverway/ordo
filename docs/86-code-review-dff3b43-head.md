# 全量架构与代码审查报告 (Code Review Report)

- **复核基线**：`dff3b4339a2a16bbf39c61d25251d5c1b0d2db34` 至 `HEAD` (`c528d42`)
- **执行时间**：2026-08-30
- **复核状态**：已完成全量独立验证与深度整改（静态检查 `flutter analyze` 0 Error / 0 Warning，全量测试套件 `flutter test` 593/593 全绿）

---

## 阶段一：全局变更地图（盘点目标）

### 1. 本次变更核心意图分析
本次版本演进主要围绕以下四大核心目标展开：
1. **解决任务编辑全屏页与软键盘动画的渲染卡顿与死锁**：重构底部工具栏悬浮机制，引入基于 GPU 矩阵平移（`Transform.translate`）的 `KeyboardAttachedToolbar`，并通过细粒度 `WindowInsetsBoundary` 隔绝正文滚动区与子任务列表的 `viewInsets` 脏标记传播。
2. **完善子任务的生命周期与交互体验**：打通子任务直接点击编辑、勾选切换完成状态（`onToggleStatus`）、长文本自动换行及已完成子任务的视觉弱化（变灰与降透明度），在仓储层支持子任务状态的原子同步（`syncSubtasks`）。
3. **优化自定义视图/看板布局与交互**：修复看板模式超出屏幕时的水平滚动条展示（独立管理 `ScrollController`），并在面板编辑器中隔离拖拽手柄与删除按钮的命中区域冲突。
4. **重构标签模块导航层级与系统设置体验**：将标签入口从抽屉侧边栏收敛至设置页（`SettingsPage`），提升 `/tags` 为一级全屏过渡路由；在侧边栏抽屉内隔离 `ScaffoldMessenger` 作用域，并深度定制 Material 3 `SegmentedButton` 的选中态与无障碍视觉反馈。

### 2. 发生实质性变动的业务模块清单（任务队列）

| 模块序号 | 业务模块名称 | 核心涉及文件 | 关键变动特征 | 整改状态 |
| :--- | :--- | :--- | :--- | :--- |
| **模块 1** | **任务编辑与子任务生命周期管理** | `lib/features/tasks/widgets/task_editor.dart`<br>`lib/features/tasks/widgets/task_editor/`（子模块包）<br>`lib/features/tasks/task_edit_page.dart`<br>`lib/features/tasks/widgets/task_create_sheet.dart`<br>`lib/core/platform/keyboard_inset_bridge.dart`<br>`lib/core/db/repositories/todo_repository.dart`<br>`lib/shared/widgets/window_insets_boundary.dart` | 软键盘 GPU 矩阵平移隔离、WindowInsets 脏标记隔断、子任务交互（点击编辑/切换状态/换行/弱化）、子任务事务同步、**超大文件按职责完全模块化拆解** | **[已完成整改]** |
| **模块 2** | **自定义看板与面板排序交互** | `lib/features/custom_views/presentation/custom_view_page.dart`<br>`lib/features/custom_views/presentation/custom_view_action_handler.dart`<br>`lib/features/custom_views/presentation/custom_view_editor_page.dart` | 水平滚动条与 ScrollController 生命周期绑定、面板列表拖拽手柄 (`ReorderableDragStartListener`) 事件隔离、**拖拽动作与弹窗逻辑解耦** | **[已完成整改]** |
| **模块 3** | **系统设置与标签导航重构** | `lib/features/settings/settings_page.dart`<br>`lib/features/settings/widgets/settings_side_sheet.dart`<br>`lib/features/tags/tags_page.dart`<br>`lib/features/tags/tags_detail_page.dart`<br>`lib/shared/widgets/adaptive_leading_navigation.dart`<br>`lib/router.dart`<br>`lib/shared/widgets/app_drawer.dart` | 标签路由提升为一级全屏过渡路由、**提取通用自适应导航组件 `AdaptiveLeadingNavigation`**、**SideSheet 拦截物理返回/ESC 键**、Drawer 精简 | **[已完成整改]** |
| **模块 4** | **基础设计令牌与通用组件细化** | `lib/core/theme/app_theme.dart`<br>`lib/shared/widgets/modal_side_sheet.dart`<br>`lib/shared/widgets/simple_task_tile.dart` | M3 `SegmentedButtonThemeData` 高对比度与无图标定制、`ModalSideSheet` 独立 `ScaffoldMessenger` 作用域隔离 | **[已验证无误]** |

---

## 阶段二：模块级全量严格审查与整改落地

---

### 🔍 模块 1：任务编辑与子任务生命周期管理

#### 1. 代码整洁度 (Clean Code)
* **超大单文件（1827 行）反模式**：
  - **复核结论与整改方案**：**`[已完成整改]`**
  - **整改详情**：将原 1827 行的 `task_editor.dart` 彻底拆解为按职责高内聚的模块目录 `lib/features/tasks/widgets/task_editor/`：
    1. `task_editor_controller.dart`：状态控制器、草稿模型 `SubtaskRow`、编辑模式 `TaskEditorMode`；
    2. `subtask_row_tile.dart`：子任务单行组件与 `SubtaskTileDisplayMode` 状态机；
    3. `subtask_list.dart`：子任务列表与拖拽重排交互；
    4. `project_picker_sheet.dart`：项目选择与所属清单切换组件；
    5. `tag_picker_sheet.dart`：标签多选弹层与快速新建标签；
    6. `task_date_picker_dialogs.dart`：日期范围弹层、状态选择器、优先级选择器；
    7. `task_editor_toolbar.dart`：底部常驻工具栏与局部更新展示组件；
    8. `task_editor.dart`：收敛为主表单容器入口，并 `export` 全部子模块保持 100% 外部向后兼容。
* **状态判断冗余与混乱**：
  - **复核结论与整改方案**：**`[已完成整改]`**
  - **整改详情**：在 `SubtaskRowTile` 中引入 `enum SubtaskTileDisplayMode { viewing, editing }` 单一状态机，清晰管理展示态与编辑态，失焦时对于已有子任务平滑回退为只读/划线预览态，彻底消除多重布尔叠加死锁。

#### 2. 职责与解耦 (Architecture & Decoupling)
* **双轨制状态管理（Dual-State Track）考量**：
  - **复核结论与架构决策**：**`[无需整改 / 维持现设计架构]`**
  - **决策理由**：在 Flutter 框架中，文本输入框的 IME 输入法交互（如中文拼音输入过程、长句组词、光标位置、高频连续击键）依赖于原生的 `TextEditingController` 与 `FocusNode` 内存持久化持有。若强行将每个击键（每秒数十次）序列化为不可变 Riverpod 状态树并触发整体不可变表单的深度复制与 Rebuild，会导致严峻的输入法断字、光标跳字以及垃圾回收卡顿；因此，表单主字段由 `taskFormProvider` 驱动（细粒度按字段监听），高频交互的子任务列表由专属 `TaskEditorController` 管理并在保存时执行事务级 `syncSubtasks`，是兼顾代码整洁与极端打字流畅度的合理工程折衷方案。
* **UI 弹窗与底层仓储解耦**：
  - **复核结论与整改方案**：**`[已完成整改]`**
  - **整改详情**：规范化 `ProjectPickerSheet` 与 `TagPickerSheet` 中的数据流操作，通过 `projectProviders` 与 `tagProviders` 驱动，并在异常时通过标准 SnackBar 提示。

#### 3. 健壮性与性能 (Robustness & Performance)
* **巧妙的 GPU 隔离机制**：
  - **复核结论**：`KeyboardAttachedToolbar` 使用 `Transform.translate` 独立更新 RenderObject 变换矩阵，并将内部 `viewPaddingBottom` 保持恒定，彻底避免了工具栏因位移触发反复 Relayout，设计优秀予以保留。
* **伪造 MediaQuery 带来的潜在边界风险**：
  - **复核结论与整改方案**：**`[已完成整改]`**
  - **整改详情**：提取公共 `WindowInsetsBoundary` 组件（`lib/shared/widgets/window_insets_boundary.dart`），保留全部环境属性（`textScaler`, `platformBrightness`, `padding`, `viewPadding`, `gestureSettings`, `accessibleNavigation` 等），安全归零 `viewInsets`，在 `task_edit_page.dart` 中挂载使用。

---

### 🔍 模块 2：自定义看板与面板排序交互

#### 1. 代码整洁度 (Clean Code)
* **状态提纯与生命周期规范**：
  - **复核结论**：`CustomViewPage` 规范管理 `_horizontalScrollController` 的初始化与销毁，设计合理。
* **业务编排代码污染 UI 层**：
  - **复核结论与整改方案**：**`[已完成整改]`**
  - **整改详情**：提取 `CustomViewActionHandler`（`lib/features/custom_views/presentation/custom_view_action_handler.dart`），将跨面板拖拽判定（`handleTaskDrop`）、删除确认（`confirmDeleteView`）、面板编辑与删除（`updatePanel`/`deletePanel`）完整封装至独立 Handler，大幅净化 UI 页面圈复杂度。

#### 2. 职责与解耦 (Architecture & Decoupling)
* **精确的事件目标解耦**：
  - **复核结论**：在 `CustomViewEditorPage` 中显式设置 `buildDefaultDragHandles: false` 并局部使用 `ReorderableDragStartListener`，事件隔离清晰，已验证无误。

---

### 🔍 模块 3：系统设置与标签导航重构

#### 1. 代码整洁度 (Clean Code)
* **AppBar 导航 Leading 模板代码重复**：
  - **复核结论与整改方案**：**`[已完成整改]`**
  - **整改详情**：创建通用 `AdaptiveLeadingNavigation` 组件（`lib/shared/widgets/adaptive_leading_navigation.dart`），统一兼容 GoRouter 与标准 Navigator，在 `TagsPage`、`TagsDetailPage`、`CustomViewPage` 中全量替换重复的 leading 模板代码。

#### 2. 职责与解耦 (Architecture & Decoupling)
* **侧边栏导航返回拦截**：
  - **复核结论与整改方案**：**`[已完成整改]`**
  - **整改详情**：在 `SettingsSideSheet` 的 `_SettingsSheetNavigator` 中增加 `PopScope` 拦截，当处于子页面（`_showingSync` / `_showingTags`）时，按物理返回键或 ESC 键先退回设置主页面，避免误关闭整个 SideSheet。

---

### 🔍 模块 4：基础设计令牌与通用组件细化

#### 1. 设计令牌与无障碍
* **复核结论**：`SegmentedButtonThemeData` 与 `ModalSideSheet` 的独立 `ScaffoldMessenger` 隔离实现符合架构规范，已验证无误。

---

## 阶段三：重大架构缺陷溯源与整改总结

### 1. 架构整改对照清单

| 审查提出的缺陷/建议 | 整改判定 | 落地状态与说明 |
| :--- | :--- | :--- |
| **超大单文件拆解**：`task_editor.dart` 1827 行拆分为高内聚包 | **必须整改** | **[已完成]** 拆分为 `lib/features/tasks/widgets/task_editor/` 下 7 个独立模块，主入口精简至 ~260 行。 |
| **子任务状态机重构**：`SubtaskRowTile` 消除多布尔死锁 | **必须整改** | **[已完成]** 引入 `SubtaskTileDisplayMode` 状态机模式。 |
| **视口隔离规范化**：提取通用 `WindowInsetsBoundary` | **必须整改** | **[已完成]** 创建 `lib/shared/widgets/window_insets_boundary.dart` 并接入使用。 |
| **看板动作解耦**：抽离 `CustomViewActionHandler` | **必须整改** | **[已完成]** 创建 `lib/features/custom_views/presentation/custom_view_action_handler.dart`。 |
| **自适应导航复用**：抽离 `AdaptiveLeadingNavigation` | **必须整改** | **[已完成]** 创建 `lib/shared/widgets/adaptive_leading_navigation.dart` 并全量接入。 |
| **SideSheet 键盘/返回拦截**：增加 `PopScope` 保护 | **必须整改** | **[已完成]** 在 `settings_side_sheet.dart` 中落地 `PopScope`。 |
| **将子任务每击键更新为 Riverpod 不可变树** | **无需整改** | **[保持现有设计]** 维持 `TaskEditorController` 管理瞬态草稿，防范 IME 拼音断字与每击键深拷贝开销。 |

---

## 阶段四：验收定义 (DoD) 与验证结论

1. **静态分析自检**：运行 `flutter analyze`，输出 `No issues found!`（**0 Error / 0 Warning**）。
2. **单元与集成测试自检**：运行 `flutter test`，全量测试套件 **593/593 全绿通过**（0 Failed, 6 Skipped 特性标记）。
3. **代码格式化自检**：运行 `dart format lib test`，全库 146 个 Dart 文件全部格式化完成。
4. **硬性约束与向后兼容**：
   - 层级上限、派生状态与数据同步字段均严格满足 `AGENTS.md` 要求；
   - `task_editor.dart` 维持了全部公开类、枚举与函数的 re-export，对已有调用方无任何破坏性变更。

**综合评审结论**：本阶段提取的全部必要整改事项已 100% 落地完成，代码整洁度与架构清晰度显著提升，系统处于稳定可用交付状态。
