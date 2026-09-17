# 50 — UI/UX 设计系统与屏幕规格

> 定义设计令牌、主题、导航、屏幕规格与交互规格。**所有颜色/圆角/间距/动效必须使用设计令牌**（`AGENTS.md` §3-9），禁止散落魔法值。

## 1. 设计方向

- **风格**：Material 3 基底 + 自定义设计令牌，复现 MIUI/HyperOS 与 Things 视觉语言：squircle 圆角、弹簧动效、精致现代灰阶与品牌强调色。
- **原则**：移动端优先；信息密度适中；层级清晰（缩进 + 圆角卡片）；动效跟手但不喧宾夺主。
- **平台中立**：不绑定单一平台设计语言，四平台观感一致。
- **UI 架构演进**：向 Things / 滴答清单的极简专注靠拢——页面基底「浅灰底 + 白卡」强化卡片层级；任务行采用**圆角矩形复选框（ModernCheckbox r6） + 卡片化**；全局导航统一采用 **`PageHeroHeader` 大标题 + `ScopeSwitcherSheet` 范围切换模态层**，单列专注，外壳 `AppShell` 直通保活。

## 2. 设计令牌（Design Tokens）

> 全部定义在 `lib/core/theme/app_tokens.dart`，UI 一律引用令牌，禁止魔法值。

### 2.1 色彩

| 令牌 | 值 | 说明 |
|---|---|---|
| `seedColor` | `#111827` | 默认种子色（曜石黑 Obsidian Black，现代极简基底） |
| `colorNavToday` | `#F59E0B` | 今日特征金橙色（Sun/Morning） |
| `colorNavInbox` | `#4F46E5` | 收集箱特征经典靛蓝（Iris/Primary） |
| `colorNavCalendar` | `#E11D48` | 日历特征珊瑚红（Agenda/Rose） |
| `colorNavTags` | `#8B5CF6` | 标签特征洋紫（Lavender/Tag） |
| `colorNavCustomView` | `#0284C7` | 自定义视图默认海蓝（Ocean/Filter） |
| `colorNavOverview` | `#10B981` | 概览特征翡翠绿（Overview） |
| `colorDone` | 翡翠绿 `#059669` | 已完成 |
| `colorInProgress` | 靛蓝 `#4F46E5` | 进行中 |
| `colorCancelled` | 灰 `#9CA3AF` | 已取消 |
| `colorOverdue` | 玫瑰红 `#E11D48` | 逾期（优雅冷调红，非刺眼） |
| `surfacePage` | 浅 `#F8F9FA` / 深 `#0D0E11` | 页面基底（Scaffold 背景，纯净冷白/深度碳黑） |
| `surfaceCard` | 浅 `#FFFFFF` / 深 `#16181D` | 卡片表面（纯白/碳黑浮层容器） |
| `borderSubtleLight` | `rgba(0, 0, 0, 0.047)` | 浅色 1px 极细微边框 |
| `borderSubtleDark` | `rgba(255, 255, 255, 0.06)` | 暗色 1px 极细微发光边框 |
| `surfaceSunken` | 浅 `#EFF1F4` / 深 `#12141A` | 凹陷面：比页面底沉一档的内嵌区域（看板列井、输入井，66 §3） |
| `alphaTintFaint / Soft / Strong` | 0.06 / 0.10 / 0.16 | 语义罩染强度三档（配 primary/onSurface，收编 ad-hoc alpha，66 §3） |

### 2.1.1 八款精选主题色盘（Theme Palettes）

设置中支持切换 8 种高质感主题主色（`themePalettes` 预设），自适应 Material 3 种子生成光影层次：

1. **曜石黑 (Obsidian Black)**: `#111827` —— 现代极简、高级纯粹（默认主色）。
2. **克莱因蓝 (Klein Blue)**: `#2563EB` —— 宽广宁静、沉着专注。
3. **翡翠绿 (Emerald Green)**: `#059669` —— 清新自然、生机勃勃。
4. **琥珀橙 (Amber Orange)**: `#D97706` —— 温暖明快、充满能量。
5. **罗兰紫 (Violet Purple)**: `#7C3AED` —— 优雅灵动、高级浪漫。
6. **玫瑰红 (Rose Red)**: `#E11D48` —— 热烈醒目、精致夺目。
7. **松石青 (Turquoise Teal)**: `#0891B2` —— 澄澈清新、舒缓灵秀。
8. **烟雨灰 (Misty Slate)**: `#64748B` —— 极简冷静、商务纯粹。

> 注：seedColor/语义色均以 `lib/core/theme/app_tokens.dart` 为准（改代码必改文档）。

- 明/暗两套由 `ColorScheme.fromSeed(seedColor)` 生成，语义色（done/inProgress/cancelled/overdue）在明暗下均保持可辨识。
- 用户可在「设置 → 外观设置 → 主题主色」中即时切换并持久化至 `SettingsDao`。

### 2.2 圆角（Modern Refined 风格）

| 令牌 | 值 | 用途 |
|---|---|---|
| `radiusCard` | 12 | 卡片（精致现代 12dp） |
| `radiusButton` | 12 | 按钮 |
| `radiusChip` | 6 | 标签/筛选 mini badge 胶囊 |
| `radiusDialog` | 16 | 对话框/底部弹层 |
| `radiusList` | 8 | 列表行 |
| `checkboxShape` / `checkboxRadius` | 圆角矩形 / 6dp | 任务完成勾选（ModernCheckbox 统一 6dp 形状） |

### 2.3 间距

`spaceXxs=4 / spaceXs=8 / spaceSm=12 / spaceMd=16 / spaceLg=20 / spaceXl=24 / spaceXxl=32 / spaceXxxl=48`

### 2.4 字体

> 平台系统字体链见 `app_theme.dart`（Win 雅黑 UI / Apple 苹方 / Linux 思源）。
> 七档字阶（66 §2）：hero 供页面级大标题，micro 仅限徽章/计数等非关键元信息，
> 正文类文案仍须 ≥ caption（NFR-06 对比度底线）。

| 令牌 | 值 | 用途 |
|---|---|---|
| `textHeroSize/Weight` | 31 / w700（letterSpacing −0.775，行高 1.1） | 页面大标题头部（PageHeroHeader） |
| `textHeadingSize/Weight` | 22 / w600 | 页标题（AppBar） |
| `textTitleSize/Weight` | 18 / w600 | 节标题 |
| `textTaskL1Size/Weight` | 16 / w600 | 一级任务标题 |
| `textTaskL2Size/Weight` | 15 / w500 | 二级任务标题 |
| `textTaskL3Size/Weight` | 15 / w500 | 三级任务标题（与二级任务统一） |
| `textBodySize/Weight` | 15 / w400（行高 1.45） | 正文 |
| `textFootnoteSize/Weight` | 13 / w400 | 辅助说明层 |
| `textCaptionSize/Weight` | 12 / w400（行高 1.35） | 元信息说明 |
| `textMicroSize/Weight` | 11 / w500 | 徽章/计数 |
| `treeIndentLevel` | 20 | 任务树扁平缩进阶梯 |
| `fontTabular` | `[FontFeature.tabularFigures()]` | 日期/计数数字纵向对齐 |

### 2.5 动效（Folme 风格弹簧，M7 打磨后统一入口）

| 令牌 | 值 | 用途 |
|---|---|---|
| `motionSpring` | 弹簧曲线（`Curves.easeOutCubic`） | 列表项、卡片 |
| `motionFast` | 150ms | 微交互（勾选/按压/FAB） |
| `motionNormal` | 250ms | 页面转场、树展开、进度环 |
| `motionSlow` | 350ms | 弹层/底部弹窗 |
| `motionStaggerDelay` | 50ms | 列表错落入场逐项间隔 |
| `cardPressScaleSubtle` | 0.998 | 任务列表按压轻微缩放（卡片包裹层单层承担；0.998 几乎无感） |

> **统一入口（M7，`docs/63-motion-polish.md`）**：所有自定义动画经 `lib/core/utils/motion.dart`
> 选取时长/曲线（`motionDuration`/`motionNormal/Fast/Slow`/`motionCurve`/`motionBounceCurve`）。
> **reduced motion（NFR-06）**：系统开启「减弱动态效果」时（`MediaQuery.disableAnimations`）自动
> 降级——位移/缩放类动画退化为纯淡入或瞬时。零第三方动画依赖（全部 Flutter 内置 API）。

### 2.6 菜单（弹出/下拉菜单统一规格）

弹出菜单（PopupMenuButton）与下拉菜单（DropdownButton）共用同一套紧凑规格，样式收敛在
全局 `popupMenuTheme` 与共享组件 `AppMenuItem`（`shared/widgets/app_menu_item.dart`），
调用点不得局部覆盖 shape/constraints：

| 令牌/配置 | 值 | 用途 |
|---|---|---|
| `menuItemHeight` | 40（M3 默认 48 紧凑化） | 菜单项行高 |
| `menuItemIconSize` | 18 | 菜单项图标（icon 与文字间距 `spaceXs`） |
| `menuMinWidth` | 120 | 菜单容器最小宽度（菜单随内容收缩） |
| `popupMenuTheme.menuPadding` | 垂直 `spaceXxs`(4) | 菜单容器上下内边距 |
| 菜单项文本 | `bodyMedium`（`labelTextStyle` 统一） | M3 默认 bodyLarge 偏大 |
| 圆角 | `radiusCard`(12) | 弹出菜单与 DropdownButton 菜单统一 |
| elevation | 3 | 弹出菜单与 DropdownButton 菜单统一 |
| destructive 项 | `colorScheme.error`（图标+文字） | 删除类条目（`AppMenuItem.destructive`） |

## 3. 主题

- 模式：跟随系统 / 浅色 / 深色（`FR-SET-01`），持久化于 settings 表。
- 语言：简体中文 / English / 跟随系统（`FR-SET-02`），持久化于 settings 表。
- 主题构建唯一入口 `AppTheme.build(mode, seedColor)`（`core/theme/app_theme.dart`）。

## 4. 导航与信息架构

- **单列沉浸式架构**：
  - 应用统一使用单列视图，外壳 `AppShell` 为直通组件；无常驻抽屉栏与常驻侧边栏。
  - 核心入口与清单范围切换统一由顶部 **`PageHeroHeader`** 驱动：用户点击大标题即可唤出 **`ScopeSwitcherSheet`（底部作用域选择面板）**，支持在「今日 / 收集箱 / 日历 / 概览 / 标签 / 自定义视图 / 项目与文件夹」之间自由穿梭。
  - 页面标题右侧统一收纳快捷功能入口（搜索、设置、日历切页等）。
- **通用任务页（`TaskListPage`，56-task-scope-page.md §3）**：今日 / 收集箱 / 项目三个任务类入口统一渲染为同一页面组件，由 `TaskScope`（Today | Inbox | Project(projectId)）驱动：
  - 标题：由 `PageHeroHeader` 呈现当前作用域名称，点击可切换。
  - body：今日 = 分组列表（逾期 + 今天）；收集箱/项目 = 任务树（3 级，嵌套卡片层级）。
  - FAB：统一走滴答式新建底部弹窗（`TaskCreateSheet`）。
- **路由**：保留常用路由路径（`/today`, `/inbox`, `/calendar`, `/overview`, `/projects`, `/tags`, `/settings` 等），启动默认页为 `/today`。

## 5. 屏幕规格

### 5.1 今日视图（`/today`）

- 顶部：统一采用 `PageHeroHeader` 头部，展示「今日」大标题、未完成统计及范围切换手势；右侧为搜索与操作图标。
- 分组：**逾期**（红标）→ **今天** → **即将到期**（可选分组）。
- 任务行：完成勾选（**圆角矩形 ModernCheckbox r6**，完成=主题色填充白勾）、标题、项目名、标签 chips、时间、派生进度；**白卡片化行**（圆角 12 + 细微边框与弥散阴影，hover/按压轻微提升）。
- 空态：无任务时展示引导文案 +「新建任务」按钮。

### 5.2 日历视图（`/calendar`）

- 沉浸式布局：日历视口去卡片化，与页面底色自然融为一体；顶部 AppBar 整合周/月折叠与日期跳转；右侧操作收敛为快捷菜单。
- 支持月视图（7 列网格）与周视图切换，点击日期格可聚焦当日安排。

### 5.3 项目视图（`/projects` 与 `/projects/:id`）

- 项目总览（`/projects`）：按文件夹分组卡片展示项目，包含文件夹分组头与项目列表。
- 项目详情（`/projects/:id`）：`TaskListPage` 项目作用域，呈现多级嵌套任务树；支持行拖拽排序调级与上下文菜单。

### 5.4 标签视图（`/tags` 与 `/tags/:id`）

- 标签列表：彩色 chip 标签流。
- 标签详情（`/tags/:id`）：该标签下任务列表 + 状态筛选。

### 5.5 搜索（`/search`）

- 顶部搜索框（自动聚焦）；结果列表（标题高亮匹配）；空结果提示与快速状态/标签筛选条。

### 5.6 任务编辑（`/task/:id` 或新建）

- **统一编辑器（59 D1）**：新建底部弹窗（`TaskCreateSheet`）与编辑全屏页（`TaskEditPage`）共用同一「任务编辑器」组件，仅容器呈现不同。
- 内容区包含任务标题、描述（内联展示）、子任务列表（带 ModernCheckbox 勾选）与底部常用工具栏（日期/状态/标签/优先级）。

### 5.7 设置（`/settings`）

- 分组：外观（主题模式、语言、主题主色）、数据同步、用户手册、关于。

## 6. 交互规格

### 6.1 拖拽（FR-TSK-06/07）

| 操作 | 手势 | 行为 |
|---|---|---|
| 同级排序 | 长按任务行拖动 | 目标位置插入，重排 sortOrder |
| 调级 | 拖动到另一任务行上悬停 | 成为其子级（目标高亮） |
| 回到 1 级 | 拖动到项目空白区/项目头 | parentId=NULL |
| 非法目标 | 自身/后代/超深 | 目标红色高亮，松手回弹，提示原因 |

### 6.2 桌面与无障碍交互（FR-TSK-08）

- 桌面端：任务行支持鼠标右键（`onSecondaryTap`）弹出上下文操作菜单（编辑、删除、调整层级等）。
- 移动端：支持任务行向左滑动（优先级、标签）与向右滑动（快速完成切换）。
- 触控目标 ≥48dp；图标按钮带 `Tooltip` + 语义标签。

### 6.3 状态反馈

- 统一空态（EmptyView）、加载态（LoadingView）与错误态（ErrorView）。

## 7. 无障碍（NFR-06）

- 语义标签：图标按钮、拖拽手柄、状态徽标均具备完整语义。
- 对比度：正文与背景对比 ≥4.5:1；语义色在明暗主题下均可辨识。
- 字体缩放：跟随系统字体缩放，布局不破裂。

## 8. 平台细节

| 平台 | 细节 |
|---|---|
| Android | 返回键 `PopScope` 处理；状态栏/导航栏颜色适配主题 |
| Windows | 默认窗口尺寸 1280×720；窗口标题栏与主题色调一致；DPI 缩放正常 |
| 通用 | 深色模式下禁用纯黑背景（用 `surface` 令牌）；滚动条桌面可见、移动隐蔽 |
