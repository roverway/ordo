# 56 — 通用任务页（Task Scope Page）开发计划（定稿）

> 状态：**FINAL — 已与用户讨论定稿（2026-08-12）**。依据：用户新需求 + 已确认决策 D1–D3 + 开放问题已答复。
> 本文档是实施唯一依据；改代码必同步 `50-ui-ux.md` / `10-requirements.md` / `70-milestones.md`。

## 1. 背景与目标

### 1.1 需求

1. 把「今日」页重构为**可共用的任务页**：根据用户在侧边栏选中的作用域显示对应任务（**默认 = 今日**，或某个项目）。
2. 修复：从侧边栏选项目后进入项目任务页，但**汉堡按钮与底栏消失**、无法切换视图。

### 1.2 已确认决策（D1–D3）

| 决策 | 结论 |
|---|---|
| D1 项目任务展示 | 项目作用域**保留任务树**（3 级、拖拽、展开折叠）；今日作用域保持分组列表 |
| D2 项目管理入口 | 项目编辑/删除放入通用任务页 **AppBar**；`/projects` 卡片页保留用于宽屏总览 |
| D3 启动默认页 | `initialLocation` 由 `/inbox` 改为 `/today`（与「默认显示今日」一致） |
| D4 收件箱 | **收件箱并入统一页**（抽屉三个任务类入口：今日/收集箱/项目 全部统一为 TaskListPage 作用域） |
| D5 删除项目跳转 | 删除项目后跳转 **`/today`**（新首页） |

## 2. 现状与根因分析

| 路由 | 页面 | AppShell？ | 汉堡/底栏 |
|---|---|---|---|
| `/today` | `TodayPage` | ✅ 有 | ✅ 常驻 |
| `/projects/:id` | `ProjectDetailPage` | ❌ **自带 Scaffold** | ❌ 消失（需求 2 根因） |
| `/projects` | `ProjectsPage`（卡片） | ✅ | ✅ |
| `/inbox` | `InboxPage` | ✅ | ✅ |

- **需求 2 根因**：`ProjectDetailPage` 返回自己的 `Scaffold(appBar: ...)`，绕过 `AppShell`，因此导航壳（汉堡/底栏/Rail）全部丢失。需求 1 让项目作用域也渲染在 AppShell 壳内后，该问题**随之解决**（同一问题的两面）。
- 抽屉选中态已按路由路径推导（`path == '/projects/:id'`），路由驱动的作用域方案与现有架构天然契合，**无需改抽屉导航逻辑**。
- 今日 FAB 已走 `TaskCreateSheet`（滴答式弹窗）；项目详情的 FAB 仍为旧全屏跳转（`context.push('/task/new?projectId=...')`）——并入统一页时应统一为 `TaskCreateSheet(projectId:)`（与 D2「新建用弹窗」一致）。

## 3. 设计方案

### 3.1 作用域模型（路由驱动）

```
TaskScope = Today | Inbox | Project(projectId)
```

- `/today` → 今日作用域（保持现有分组列表：逾期 + 今天）
- `/inbox` → 收件箱作用域（`TaskTree(projectId: inboxProjectId)`，与项目作用域一致的任务树；Bug 3 修复前为扁平 1 级列表，扁平组件 `InboxTaskTile`/`inboxTasksProvider` 已删除）
- `/projects/:id` → 项目作用域（TaskTree，3 级任务树）
- 侧边栏选中项由路由路径推导（现有逻辑不变）；三个作用域**共用同一个页面组件 `TaskListPage`**，仅 body 与 AppBar actions 不同。

### 3.2 统一页面结构（`TaskListPage`）

```
TaskListPage(scope)
└─ AppShell(title: scope 标题, actions: scope 专属操作)
   ├─ body:
   │   Today 作用域   → 今日分组列表（复用 today_providers 的 TodayViewData 逻辑）
   │   Inbox 作用域   → TaskTree(inboxProjectId)（与项目作用域一致的 3 级任务树）
   │   Project 作用域 → TaskTree(projectId)
   ├─ FAB → TaskCreateSheet（Today: 缺省收件箱；Inbox/Project: 对应 projectId）
   └─ 空态/加载/错误（随作用域）
```

- **标题**：今日 = `navToday`；收件箱 = `inboxProject.name`（动态，来自 `inboxProjectProvider`）；项目 = `project.name`（动态，来自 `projectsStreamProvider`）。
- **AppBar actions**：今日/收件箱作用域 = 搜索/设置（AppShell 默认）；项目作用域 = 搜索/设置 + **编辑项目** + **删除项目**（沿用 `project_form_dialog.dart` 与确认框）。
- **FAB**：三作用域统一走 `TaskCreateSheet`（今日缺省收件箱 / 收件箱与项目带对应 projectId），消除旧的 `/task/new` 全屏新建路径。
- **删除项目后**：跳转 `/today`（新默认首页）。

### 3.3 AppShell 扩展

- AppShell 增加可选 `actions` 参数（默认 = 搜索/设置；项目作用域在末尾追加编辑/删除图标）。
- 其余（drawer、底栏 3 tab、宽屏 Rail 5 目的地、未命中路由底栏无选中）保持不变。

### 3.4 路由与文件调整

| 项 | 变更 |
|---|---|
| `router.dart` | `initialLocation: '/inbox'` → `'/today'`；`/today`、`/inbox`、`/projects/:id` 改渲染 `TaskListPage(对应作用域)` |
| `today_page.dart` | 列表构建逻辑抽取为今日作用域 body（供 `TaskListPage` 复用） |
| `inbox_page.dart` | 任务列表/空态/标题逻辑并入收件箱作用域 body（Bug 3 后收件箱作用域直接渲染 `TaskTree`，扁平列表组件 `InboxTaskTile` 已删除） |
| `project_detail_page.dart` | 任务树 + 编辑/删除逻辑并入项目作用域 body/actions；**文件废弃或瘦身为轻壳** |
| 新增 | `TaskListPage`（作用域分发；收件箱作用域复用 `TaskTree`） |

## 4. 实施步骤（分两批）

### 批 1 — 统一页骨架 + 今日/收件箱作用域（纯重构，行为不变）

1. AppShell 增加 `actions` 参数（默认兼容现有调用）。
2. 新建 `TaskListPage`：支持 `TaskScope.today` 与 `TaskScope.inbox`；body 从 TodayPage/InboxPage 抽取；FAB = `TaskCreateSheet`（收件箱作用域带 inboxProjectId）。
3. `router.dart`：`/today`、`/inbox` 改渲染 `TaskListPage`；`initialLocation` 改 `/today`。
4. 全量回归：现有今日页/收件箱页行为不变。

**验收**：`flutter analyze` 0 error；`flutter test` 全绿；今日/收件箱功能无回归。

### 批 2 — 项目作用域并入（功能迁移 + 需求 2 修复）

1. `TaskListPage` 支持 `TaskScope.project(projectId)`：body = `TaskTree`；AppBar = 编辑/删除项目；FAB = `TaskCreateSheet(projectId:)`；空态 = 项目空提示。
2. `/projects/:id` 改渲染 `TaskListPage(project)`；`ProjectDetailPage` 废弃。
3. 修复确认：项目作用域下汉堡/底栏/Rail 常驻（需求 2 验收点）。
4. 测试更新：`widget_test.dart` 项目导航用例（原断言「无汉堡独立页」改为「AppShell 壳内」）、新增项目作用域 AppBar/删除跳转 `/today` 用例。

**验收**：批 1 全绿 + 双端手工走查（侧边栏选项目 → 有汉堡/底栏可切换、任务树正常、编辑/删除可用、新建走弹窗）。

## 5. 影响与风险

| 项 | 说明 |
|---|---|
| `ProjectDetailPage` 废弃 | 其任务树/编辑/删除逻辑被 `TaskListPage` 吸收，确认无其他引用遗漏 |
| 底栏高亮 | 项目作用域下底栏 3 tab **无选中**（项目属抽屉级，与滴答一致；已实现） |
| 今日/收件箱 FAB | 今日缺省收件箱不变；收件箱作用域显式传 inboxProjectId；项目从全屏页改为弹窗（既有 D2 决策的自然统一） |
| 删除项目跳转 | 由 `/projects` 改为 `/today`（新首页，D5 已确认） |
| 宽屏 master-detail | 本次不做三栏重构；宽屏项目作用域 = Rail + 统一页单栏（沿用现状） |

## 6. 开放问题（已答复）

| 问题 | 结论 |
|---|---|
| 收件箱是否并入统一页？ | **并入**（D4）：抽屉三个任务类入口全部统一为 `TaskListPage` 作用域 |
| 删除项目后的跳转 | 改 **`/today`**（D5，新首页） |

## 7. 待办（定稿后）

- [ ] 更新 `10-requirements.md`（FR-NAV-01 抽屉作用域说明、FR-VIEW 相关）
- [ ] 更新 `50-ui-ux.md` §4/§5（统一任务页规格）
- [ ] 更新 `70-milestones.md` M5（新增统一任务页子任务）
- [ ] 实施批 1 → 验收 → 批 2 → 双端手工走查
