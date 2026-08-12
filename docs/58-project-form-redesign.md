# 58 — 新建项目 / 项目编辑界面优化（定稿）

> 状态：**定稿（已确认决策）** · 参考图：`/home/rw/Downloads/参考2/项目内具体任务编辑页面（弹出式）.jpg`、`（全屏）.jpg`
> 分析报告：`docs/ticktick-task-editor-analysis.md`（des-1 输出）

## 1. 背景与目标

参考滴答清单「任务编辑页」的视觉语言与交互模式，优化本项目的**新建项目 / 项目编辑界面**。
注意：参考图是任务编辑页，借鉴的是**呈现形态与选项行视觉**，字段仍按项目自身（名称/颜色/描述）。

## 2. 现状

### 2.1 当前表单（`lib/features/projects/widgets/project_form_dialog.dart`）
- 居中 `AlertDialog`：标题（新建项目/编辑项目）+ 名称输入 + 颜色圆点网格 + 取消/保存
- 移动端与桌面端同形，无平台自适应
- 无描述字段、无选项行结构

### 2.2 数据模型（`lib/core/db/tables.dart`）
- `Projects` 表：id / name / color / sortOrder / createdAt / updatedAt / deleted
- **无 description 列** —— 但 `10-requirements.md` FR-PRJ-02 声明项目字段含「描述（可选，纯文本）」
- 当前 `schemaVersion = 2`；加描述需 v3 迁移（`database.dart` MigrationStrategy + `migration_test.dart`）

### 2.3 调用方（4 处）
| 位置 | 场景 |
|---|---|
| `app_drawer.dart` | 抽屉底部「新建项目」 |
| `projects_page.dart` | 项目列表页 FAB / 空态按钮（新建） |
| `task_list_page.dart`（项目作用域 AppBar） | 编辑项目（改名/改色） |
| `task_create_sheet.dart` | 新建任务弹窗内「+ 新建清单」 |

## 3. 参考图要点（摘要）

- **弹出式**：底部弹窗（约 60–70% 屏高），顶部圆角 20–24px，遮罩点击关闭；顶部栏（标题 + 操作图标）；内容区选项行堆叠；自动保存
- **全屏式**：AppBar + 内容区 + 底部工具栏，字段排布同弹出式
- **选项行**：`[图标] 字段名 …… 右侧值/箭头`，高 48–56dp 整行可点，图标灰色线性 24px，字段名灰 14–16sp
- **层次**：间距 12–16dp 分组，无强分隔线；标题粗体大字、描述常规字重、无边框输入
- **保存**：勾选图标保存 / 自动保存；键盘适配（viewInsets 上移）

## 4. 决策（已确认 2026-08-12）

| 决策 | 选择 | 说明 |
|---|---|---|
| **D1 移动端形态** | 底部弹窗，可上拉扩展为全屏页 | 默认底部弹窗（对齐 TaskCreateSheet 滴答式），支持拖拽上拉至全屏（`DraggableScrollableSheet` 或等效）；全屏态提供 AppBar 返回 |
| **D2 描述字段** | 补上 | `projects.description` 列（默认 `''`），schemaVersion 2→3 迁移；表单加多行描述输入 |
| **D3 颜色选择** | 选项行 + 底部选择器 | `[色点] 项目颜色 [当前色]` 选项行，点击弹出底部颜色选择器 |
| **D4 保存行为** | 显式保存按钮 | 底部 取消/保存；新建/编辑语义明确 |
| **D5 桌面端** | 居中对话框 | 宽度约束 400–480dp，选项行结构一致，底部 取消/保存 |

## 5. 实施范围（按决策）

### 5.1 数据层（v2→v3 迁移）
- `tables.dart`：`Projects` 表新增 `TextColumn description => text().withDefault(const Constant(''))()`
- `database.dart`：`schemaVersion` 2→3；`onUpgrade` 增加 `if (from < 3) addColumn(projects, projects.description)`
- 跑 `dart run build_runner build --delete-conflicting-outputs` 重新生成 `database.g.dart`
- `todo_repository.dart`：`createProject` / `updateProject` 支持 `description` 参数
- `migration_test.dart`：新增 v2→v3 迁移测试（旧 schema 造数据 → 升级 → 断言 description 默认 `''` 且数据完整）

### 5.2 UI 层（`project_form_dialog.dart` 重写）
- **移动端**：底部弹窗（`showModalBottomSheet` + `isScrollControlled` + `useSafeArea` + 顶部圆角 `radiusDialog` + viewInsets 键盘适配），默认部分高度，可上拉扩展全屏；全屏态 AppBar 返回
- **桌面端**：居中对话框，宽度 400–480dp
- **选项行结构**：`[图标] 字段名 …… 右侧值/箭头`，高 48–56dp 整行可点
- **字段**：名称（必填校验）、颜色（选项行 → 底部颜色选择器）、描述（多行输入，可选）
- **保存**：显式 取消/保存 按钮
- `ProjectFormData` 增加 `description` 字段；4 个调用方签名不变（`showProjectFormDialog` 返回类型不变）

### 5.3 调用方（4 处，接线 description）
- `app_drawer.dart`（新建）、`projects_page.dart`（新建）、`task_list_page.dart`（编辑）、`task_create_sheet.dart`（新建清单）：传入/透传 `description`

### 5.4 文档同步
- `40-data-model.md`：Projects 字段表 + §8 迁移步骤（v2→v3）
- `10-requirements.md`：FR-PRJ-02 描述字段落地标记
- `50-ui-ux.md`：若新增组件/令牌（颜色选择器、选项行）

### 5.5 验证
- `flutter analyze` 0 issue + `flutter test` 全绿 + `dart format`
- 提交前核对 diff

## 6. 影响面

- `project_form_dialog.dart` 重写（选项行化 + 平台自适应 + 可上拉全屏）
- `tables.dart` + `database.g.dart`（跑 build_runner）+ `database.dart`（v3 迁移）+ `migration_test.dart`
- `todo_repository.dart`：createProject/updateProject 支持 description
- 4 个调用方签名不变（`showProjectFormDialog` 返回 `ProjectFormData` 增加 description）
- 文档同步：`40-data-model.md`（Projects 字段表 + 迁移步骤）、`50-ui-ux.md`（若新增组件/令牌）、`10-requirements.md`（FR-PRJ-02 落地标记）
- 验证：`flutter analyze` 0 issue + `flutter test` 全绿 + `dart format`