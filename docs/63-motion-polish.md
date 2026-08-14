# 63 — 细节动效打磨（Motion Polish）（定稿）

> 状态：**定稿（决策已确认 2026-08-14）**
> 相关文档：`50-ui-ux.md`（§2.5 动效令牌）、`70-milestones.md`（M7）
> 决策基线：9 项全做 ｜ 滑动式转场 ｜ 克制轻盈（滴答风格） ｜ 支持 reduced motion ｜ **零新依赖**（全部 Flutter 内置动画 API）

## 1. 背景与目标

当前应用交互足够完整，但**细节动效缺失**，使用感受偏「静态」。目标：用克制的微动画提升整体质感与高级感，不引入任何第三方动画包（AGENTS.md §3-7 版本锁定 + 仓库「禁止新增 pub 依赖」文化，`snapshot_codec.dart` 先例）。

## 2. 现状评估

- 动效令牌齐备（`AppTokens.motion*`：motionSpring=easeOutCubic / motionFast 150ms / motionNormal 250ms / motionSlow 350ms / motionStaggerDelay 50ms），但**大部分未实际使用**。
- 仅有零散 `AnimatedContainer`/`AnimatedOpacity`（任务行/标签页/颜色选择器），未接令牌曲线。
- 缺口：页面转场默认直切、勾选无弹性、列表无错落入场、树展开瞬时、进度环静态、弹窗默认曲线、卡片无按压反馈、FAB 无回弹。

## 3. 决策（已确认）

| 决策 | 选择 |
|---|---|
| 范围 | **批 1（微交互）+ 批 2（页面级）+ 批 3（弹性氛围）共 9 项全做** |
| 转场风格 | **滑动式**（SlideTransition，方向感强，Material 风格） |
| 动画强度 | **克制轻盈**（easeOutCubic 为主，弹性仅限勾选/按压微交互） |
| reduced motion | **支持**：`MediaQuery.disableAnimations` 时降级为淡入/瞬时（NFR-06） |
| 依赖 | **零新增**：全部用 Flutter 内置 `TweenAnimationBuilder`/`AnimationController`/`AnimatedSize`/`CustomTransitionPage` 等 |

## 4. 共享基建（`lib/core/utils/motion.dart`）

统一动效入口，两个车道共用：

- `isReducedMotion(context)`：读 `MediaQuery.disableAnimations`（跟随系统）。
- `motionDuration(context, full)`：reduced motion → `Duration.zero`。
- `motionNormal/Fast/Slow(context)`：令牌时长的降级版。
- `motionCurve(context)`：常规 `motionSpring`（easeOutCubic），reduced → easeOut。
- `motionBounceCurve(context)`：微交互弹性 `easeOutBack`，reduced → easeOut。
- `motionFadeCurve`：纯淡入曲线（reduced 安全）。

## 5. 实施清单（9 项）

### 批 1 — 高频微交互（车道 A）

| # | 位置 | 方案 |
|---|---|---|
| A | 任务完成勾选（`simple_task_tile.dart` / `task_row.dart` / `task_tree.dart`） | 勾选时勾选框 scale 弹性（1→~1.15→1，`motionBounceCurve` + `motionFast`），勾线淡入；取消完成缩小回弹。`TweenAnimationBuilder` 或 `AnimatedScale` |
| B | 列表逐项错落入场（任务列表/项目列表/标签/抽屉） | 首帧逐项 fade + slide-up 8px，间隔 `motionStaggerDelay`(50ms)，总时长 `motionNormal`；数据刷新不重放（仅首次 build）。共享错落组件（如 `StaggeredFadeSlide`）放 `shared/widgets/` |
| C | 文件夹树展开/折叠（`app_drawer.dart`） | 树区包 `AnimatedSize`（`motionNormal` + easeOutCubic），连线随高度平滑延伸 |

### 批 2 — 页面级动效（车道 B）

| # | 位置 | 方案 |
|---|---|---|
| D | 路由转场（`router.dart`） | 改用 `CustomTransitionPage` + `SlideTransition`：push（任务编辑/设置/详情）右→左滑入 + 淡入；pop 反向。时长 `motionNormal`。tab 级切换保持轻量 |
| E | 抽屉展开（`app_shell.dart` 抽屉） | 定制抽屉滑入曲线（easeOutCubic + `motionNormal`），scrim 同步淡入 |
| F | 进度环（`task_progress_ring.dart`） | `TweenAnimationBuilder` 让 value 平滑过渡（`motionNormal` easeOut），数值变化时圆环扫过 |

### 批 3 — 弹性与氛围（A 车道做 H/I，B 车道做 G）

| # | 位置 | 方案 |
|---|---|---|
| G | 新建任务底部弹窗（`task_create_sheet.dart`） | 自定义 bottom sheet 转场：slide-up + `motionBounceCurve` + `motionSlow`，遮罩淡入 |
| H | 卡片按压反馈（`project_card.dart` / 任务卡片） | 按压时阴影抬升 + 轻微 scale 0.98，接 `elevationCardHover` 令牌 |
| I | FAB 按压回弹 | FAB 按压 scale 回弹（`motionBounceCurve`）；完成勾选加涟漪（`InkResponse`） |

## 6. 车道划分与文件边界

### 车道 A（@designer/des-1 复用，批 1 + 批 3 H/I）
文件：`lib/shared/widgets/simple_task_tile.dart`、`lib/features/tasks/widgets/task_row.dart`、`lib/features/tasks/widgets/task_tree.dart`、`lib/features/tasks/task_list_page.dart`（FAB）、`lib/features/projects/projects_page.dart`、`lib/features/projects/widgets/project_card.dart`、`lib/features/tags/tags_page.dart`、`lib/shared/widgets/app_drawer.dart`、新增 `lib/shared/widgets/staggered_fade_slide.dart`。

### 车道 B（@designer 新会话，批 2 + 批 3 G）
文件：`lib/router.dart`、`lib/shared/widgets/app_shell.dart`（抽屉曲线）、`lib/shared/widgets/task_progress_ring.dart`、`lib/features/tasks/widgets/task_create_sheet.dart`。

> 两车道无文件重叠。跨车道约定：转场 250ms，错落 50ms/项，转场与错落衔接克制不重叠；reduced motion 全部降级。

## 7. 令牌

复用现有 `motion*` 令牌；如需要新增（如勾选弹性幅度）加到 `app_tokens.dart` 并注释。禁止魔法值。

## 8. 验证

- `flutter analyze` 0 error；`flutter test` 全绿；`dart format`。
- 现有 widget 测试若因动画改变需同步（如 `pumpAndSettle` 时序），更新并保证全绿。
- reduced motion 用 `tester.platformDispatcher.accessibilityFeaturesTestValue` 注入测试降级路径。

## 9. 文档同步

- `50-ui-ux.md` §2.5 动效令牌 → 补充 motion.dart 使用约定与 reduced motion。
- `70-milestones.md` → 新增 M7（细节动效打磨，DoD 见 §8）。

## 10. 里程碑

新增 **M7 — 细节动效打磨**。9 项 DoD：勾选/错落/树展开/转场/抽屉/进度环/弹窗/卡片按压/FAB 全落地 + reduced motion 降级 + 全量验证绿。
