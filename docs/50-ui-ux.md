# 50 — UI/UX 设计系统与屏幕规格

> 定义设计令牌、主题、导航、屏幕规格与交互规格。**所有颜色/圆角/间距/动效必须使用设计令牌**（`AGENTS.md` §3-9），禁止散落魔法值。

## 1. 设计方向

- **风格**：Material 3 基底 + 自定义设计令牌，复现 MIUI/HyperOS 视觉语言：squircle 圆角、弹簧动效、Monet 动态色。
- **原则**：移动端优先；信息密度适中；层级清晰（缩进 + 圆角卡片）；动效跟手但不喧宾夺主。
- **平台中立**：不绑定单一平台设计语言，四平台观感一致。
- **UI 重构（2026-08，见 `55-ui-redesign-proposal.md`）**：向滴答清单靠拢——页面基底「浅灰底 + 白卡」强化卡片层级；任务行**圆形复选框 + 卡片化**；移动端导航改**侧边栏抽屉**（批 2-A 已完成，见 §4）；移动端新建任务走底部弹窗（批 2 待做）。

## 2. 设计令牌（Design Tokens）

> 全部定义在 `lib/core/theme/app_tokens.dart`，UI 一律引用令牌，禁止魔法值。

### 2.1 色彩

| 令牌 | 值 | 说明 |
|---|---|---|
| `seedColor` | `#4F46E5` | 默认种子色（Electric Indigo / Iris 质感升级） |
| `colorDone` | 翡翠绿 `#059669` | 已完成 |
| `colorInProgress` | 靛蓝 `#4F46E5` | 进行中（与 seedColor 一致） |
| `colorCancelled` | 灰 `#9CA3AF` | 已取消 |
| `colorOverdue` | 玫瑰红 `#E11D48` | 逾期（优雅冷调红，非刺眼） |
| `surfacePage` | 浅 `#F8F9FA` / 深 `#0D0E11` | 页面基底（Scaffold 背景，纯净冷白/深度碳黑） |
| `surfaceCard` | 浅 `#FFFFFF` / 深 `#16181D` | 卡片表面（纯白/碳黑浮层容器） |
| `borderSubtleLight` | `rgba(0, 0, 0, 0.047)` | 浅色 1px 极细微边框 |
| `borderSubtleDark` | `rgba(255, 255, 255, 0.06)` | 暗色 1px 极细微发光边框 |
| `surfaceSunken` | 浅 `#EFF1F4` / 深 `#12141A` | 凹陷面：比页面底沉一档的内嵌区域（看板列井、输入井，66 §3） |
| `alphaTintFaint / Soft / Strong` | 0.06 / 0.10 / 0.16 | 语义罩染强度三档（配 primary/onSurface，收编 ad-hoc alpha，66 §3） |

> 注：seedColor/语义色均以 `lib/core/theme/app_tokens.dart` 为准（改代码必改文档）。

- 明/暗两套由 `ColorScheme.fromSeed(seedColor)` 生成，语义色（done/inProgress/cancelled/overdue）在明暗下均保持可辨识。
- **Monet 动态色**：Android 12+ 从系统壁纸取色；Windows/低版本 Android 回退 `seedColor` 主题（Oracle 评审 H-低）。

### 2.2 圆角（Modern Refined 风格）

| 令牌 | 值 | 用途 |
|---|---|---|
| `radiusCard` | 12 | 卡片（精致现代 12dp） |
| `radiusButton` | 12 | 按钮 |
| `radiusChip` | 6 | 标签/筛选 mini badge 胶囊 |
| `radiusDialog` | 16 | 对话框/底部弹层 |
| `radiusList` | 8 | 列表行 |
| `checkboxShape` | 圆形 | 任务完成勾选（完成=中性灰填充白勾） |

### 2.3 间距

`spaceXxs=4 / spaceXs=8 / spaceSm=12 / spaceMd=16 / spaceLg=20 / spaceXl=24 / spaceXxl=32`

### 2.4 字体

> 平台系统字体链见 `app_theme.dart`（Win 雅黑 UI / Apple 苹方 / Linux 思源）。
> 七档字阶（66 §2）：display 供页面级大标题（现用于项目列表页），micro 仅限徽章/计数等非关键元信息，
> 正文类文案仍须 ≥ caption（NFR-06 对比度底线）。

| 令牌 | 值 | 用途 |
|---|---|---|
| `textDisplaySize/Weight` | 28 / w700（letterSpacing −0.5，行高 1.2） | 页面大标题头部 |
| `textHeadingSize/Weight` | 22 / w600 | 页标题（AppBar） |
| `textTitleSize/Weight` | 18 / w600 | 节标题 |
| `textTaskL1Size/Weight` | 16 / w600 | 一级任务标题 |
| `textTaskL2Size/Weight` | 15 / w500 | 二级任务标题 |
| `textTaskL3Size/Weight` | 14 / w400 | 三级任务标题 |
| `textBodySize/Weight` | 15 / w400（行高 1.45） | 正文 |
| `textFootnoteSize/Weight` | 13 / w400 | 辅助说明层 |
| `textCaptionSize/Weight` | 12 / w400（行高 1.35） | 元信息说明 |
| `textMicroSize/Weight` | 11 / w500 | 徽章/计数 |
| `treeIndentL1/L2/L3` | 0 / 20 / 38 | 任务树 3 级自然阶梯缩进 |
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
>
> M7 已落地动效：任务完成勾选弹性（`TweenSequence` 关键帧 + `easeOutBack`）、列表逐项错落入场
> （`StaggeredFadeSlide`，>15 项封顶平铺）、文件夹树展开（`AnimatedSize`）、路由滑动式转场
> （`CustomTransitionPage` + `SlideTransition`）、抽屉滑入曲线、进度环数值平滑过渡、
> 底部弹窗弹簧入场、卡片按压抬升（阴影 + scale 0.98）、FAB 按压回弹。

### 2.6 菜单（弹出/下拉统一规格）

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

其他约定：侧边栏「任务分组」组头、文件夹行、面板列头等「更多」入口一律竖排三点
（`more_vert`）；任务树展开动画与侧边栏文件夹展开一致——仅卡片级 `AnimatedSize`
自上而下揭示，子行不叠加逐项动画（已移除子行 `StaggeredFadeSlide` 及
`motionTreeStaggerDelay` 令牌）。

## 3. 主题

- 模式：跟随系统 / 浅色 / 深色（`FR-SET-01`），持久化于 settings 表。
- 语言：简体中文 / English / 跟随系统（`FR-SET-02`），持久化于 settings 表。
- 主题构建唯一入口 `AppTheme.build(mode, seedColor)`（`core/theme/app_theme.dart`）。

## 4. 导航与信息架构

- **窄屏（<600dp）**：侧边栏抽屉承载清单导航（`55-ui-redesign-proposal.md` §3.1，D1；M6 文件夹化 `62-folder-nav.md` §6）：
  - 顶部：应用名/Logo（无账号体系，不做头像）。
  - 系统组（无分隔线）：**今日 / 收集箱 / 日历 / 标签**；当前项浅色药丸高亮（`secondaryContainer` 派生 + 圆角 8–12）。
  - 细分隔线 + 项目区（M6）：**文件夹组（各含项目行）+ 未分组区**。
    - 「任务分组」组头右侧为**竖排三点菜单**（`more_vert`，tooltip「更多选项」，与文件夹行菜单方向一致）：**新建文件夹**（原组头直按钮收编入菜单）/ **总览**（进入 `/projects` 项目总览页，此前该页无可达入口）。
    - 文件夹行：`[展开/折叠箭头] [文件夹图标] 名称 [汇总未完成数]`；点击切换展开/折叠；展开状态设备本地持久化（settings，不同步）。
    - 项目行：颜色圆点 + 项目名 + 未完成数；缩进在所属文件夹下；当前项目药丸高亮。
    - 未分组区：小标题「未分组」+ 平铺项目行（在文件夹之后；收件箱仍由系统组承载，不参与文件夹）。
    - 拖拽（复用任务树 LongPressDraggable/DragTarget 模式）：项目行拖到文件夹行=入夹、拖到未分组区=出夹、同组拖动=组内排序；文件夹行拖动=文件夹间排序；折叠文件夹作拖放目标时自动展开。
  - 细分隔线 + 底部「新建项目」/「新建文件夹」（图标 + 文字，复用项目表单对话框视觉）。
  - 宽度 = 屏宽 × `drawerWidthRatio`（0.78，75–80%）；右侧半透明遮罩点击关闭。
  - AppBar：左侧汉堡（`Icons.menu`）打开抽屉，右侧搜索/设置。
  - 底部 **`CompactBottomBar`（自绘紧凑底栏，`57-task-page-polish.md` §4.1 D5）**：**2 个系统入口：今日 / 日历**（标签移入抽屉），高 `bottomBarHeight`（56dp，明显矮于标准 NavigationBar 80dp）；图标（`bottomBarIconSize` 22）+ 极小标签（`bottomBarLabelSize` 10）；选中 = 主色 + filled 图标，**非底栏路径视觉无选中**（`selectedIndex = -1`）；列表渲染可扩展（新增功能按钮向 `_barPaths`/`barDestinations` 各加一项）。
- **宽屏（≥600dp）**：`NavigationRail`（宽度 96，5 目的地：收集箱/今日/日历/项目/标签）+ 两栏 master-detail；选中态药丸高亮（`indicatorColor` 由 colorScheme 派生）。
- 搜索、设置：AppBar 图标，所有视图可用。
- **通用任务页（`TaskListPage`，56-task-scope-page.md §3）**：今日 / 收件箱 / 项目三个任务类入口统一渲染为同一页面组件，由 `TaskScope`（Today | Inbox | Project(projectId)）驱动：
  - 标题：今日 = `navToday`；收件箱/项目 = 对应项目名（动态）。
  - body：今日 = 分组列表（逾期 + 今天）；收件箱/项目 = 任务树（3 级，收件箱复用 `TaskTree(projectId: inboxProjectId)`，Bug 3 后与项目作用域一致）。
  - AppBar：今日/收件箱 = 搜索/设置；项目 = 搜索/设置 + 编辑 + 删除（删除后跳 `/today`）。
  - FAB：统一走滴答式新建底部弹窗（今日缺省收件箱；收件箱/项目带对应 projectId）。
  - 三个作用域均在 AppShell 壳内（汉堡/底栏/Rail 常驻）。
- 路由不变（`/inbox /today /calendar /projects /tags` 仍存在），抽屉/Rail 选中态由当前路由路径推导；启动默认页 `/today`。

## 5. 屏幕规格

### 5.1 今日视图（`/today`）

- 顶部：搜索图标；项目作用域另有三点菜单。（66 号的大标题头部方案经用户实机评审后仅在项目列表页保留，见 66 §5。）
- 分组：**逾期**（红标）→ **今天** → **即将到期**（可选分组）。
- 任务行：完成勾选（**圆形复选框**，完成=蓝填充白勾）、标题、项目名、标签 chips、时间、派生进度；**白卡片化行**（圆角 16 + 轻阴影，hover/按压轻微抬升）。
- 空态：无任务时展示引导文案 + 「新建任务」按钮。
- 今日/收件箱/项目统一为 `TaskListPage`（作用域驱动），规格见 §4。

### 5.2 日历视图（`/calendar`）

> **沉浸式布局定稿（0ede52e + 66 纲领）**：日历视口去卡片化——无边框/阴影/内边距直接落在页面基底上，
> 视口底以 1px outlineVariant(25%) 细分隔线与议程区相接；周期标题融入 AppBar（点击弹日期选择器 +
> keyboard_arrow_down 下拉箭头）；右上操作收拢为三点菜单（回到今天/周月切换/搜索）。宽屏左栏宽
> `calendarPaneWidth`=400。

- 顶部：AppBar 内周期选择器 + 三点菜单；左右滑动翻页、上下滑折叠周/月（手势不变）。
- 滑动动效（用户打磨 2026-08）：上下（月↔周）由外层 `AnimatedSize` 平滑高度过渡（motionNormal +
  motionCurve + topCenter，与任务树/侧边栏同一范式）；左右（翻月/翻周）由内层方向性
  `AnimatedSwitcher` 推入——新网格自滑动方向侧滑入（0.18 宽度分数）、旧网格向反侧滑出并淡出，
  月周切换退化为纯淡入；reduced motion 经 motionNormal 归零瞬时切换。
- 议程头部与「日历暂无安排」空态均不设新建入口（与底部 FAB 完全重复），新建统一走 FAB。
- 月视图：7 列网格，日期格内显示任务点/标题（溢出省略）；跨天任务在区间内每天显示。
- 周视图：横向时间轴或 7 列列表（v1 可用简化实现，见 `70-milestones.md` M3）。
- 点击日期格：弹出该日任务列表 + 新建入口。
- 今天高亮；周末弱化。

### 5.3 项目视图（`/projects`）

- 项目列表：**按文件夹分组展示**（M6，`62-folder-nav.md` §6.4）——文件夹分组头（图标 + 名称）+ 项目卡片 + 未分组区（分组头「未分组」）。卡片式（颜色圆点 + 名称 + 未完成任务数 + 进度）。**不做拖拽**（仅展示分组，D5）。
- 大标题头部（66 §5）：display 级「项目」+ 计数副标题（「x 个项目 · y 个文件夹」ARB）。
- 项目详情（`/projects/:id`）：`TaskListPage` 项目作用域（AppShell 壳内，汉堡/底栏/Rail 常驻）——任务树（最多 3 级），缩进 + 展开/折叠箭头；每行：勾选、标题、标签、时间、状态徽标；AppBar 追加编辑/删除项目（删除后跳 `/today`）；FAB 走滴答式新建弹窗（带 projectId）。
- 树内操作：长按拖动（排序/调级）、行尾菜单（编辑/删除/上移/下移/缩进/缩出/新建子任务）。

### 5.4 标签视图（`/tags`）

- 标签列表：彩色 chip 网格。
- 标签详情（`/tags/:id`）：该标签下任务列表 + 状态筛选（弹出菜单同 §5.5 筛选条规格）。

### 5.5 搜索（`/search`）

- 顶部搜索框（自动聚焦）；结果列表（标题高亮匹配）；空结果提示。
- 筛选条（状态/标签/时间段）：触发区 = 筛选名 labelMedium + 选中值 bodyMedium +
  下拉箭头；弹出菜单与全局三点菜单同规格（`AppMenuItem` 紧凑项，选中项带 check），
  不使用 DropdownButton（其菜单项不受 popupMenuTheme 管辖）。

### 5.6 任务编辑（`/task/:id` 或新建）

> 任务编辑界面统一重构（统一编辑器 + 底部工具栏）见 `docs/59-task-editor-optimization.md`（D1–D9 定稿）。

- **统一编辑器（59 D1）**：新建底部弹窗（`TaskCreateSheet`）与编辑全屏页（`TaskEditPage`）共用同一「任务编辑器」组件，**仅呈现容器不同**——弹出式（60–65% 高、顶部圆角、遮罩、键盘上移，快速编辑）/ 全屏式（AppBar + 返回箭头，深度编辑）；内容区与底部工具栏完全一致。
- **结构**（自上而下）：
  - 顶部栏：[项目图标] 项目名 [下拉双箭头]（编辑中直接切换所属项目）＋ [⋯ 菜单]（描述/备注开关；编辑态含**删除**，带确认弹窗，D4/D8/D9）。
  - 内容区（设置项全部移出，仅留核心内容）：
    ① 任务标题：大号加粗（titleLarge）、无边框、自动聚焦；
    ② 描述：**默认内联展示**（D9 修订，不再依赖 ⋯ 菜单）；备注：⋯ 菜单开关后内联展开（默认隐藏，D8）；
    ③ 子任务列表：圆形复选框 + 文字 + 拖拽手柄 + 删除按钮（新建弹窗仅 1 级任务展示，parentId 为空时；**编辑页按被编辑任务自身深度 < 3 展示**——3 级最深隐藏，解决「有子任务的 2 级任务不显示子任务区」的不一致，方案 B；编辑页支持新增/删除/拖拽排序，D3）。
  - 底部工具栏（常驻，替代原选项行）：[日期] [状态] [标签] [优先级] [附件占位禁用]（D5）。
- **项目**：保留在顶部栏；**编辑态只读展示项目名**（无下拉箭头——跨项目移动未实现，隐藏误导入口），**新建态可切换**（下拉双箭头 → 清单选择器）；父任务（parentId 非空）只读展示在顶部栏或保留信息行。
- **日期（D6）**：工具栏单「日期」图标，弹层内分设开始/截止（今天/明天/下周/自定义/清除，复用现有 `_DueDateChoice` 预设 + 自定义）。
- **状态（D7）**：工具栏图标，弹层选择 4 状态；有子任务时图标禁用 + Tooltip 派生提示（AGENTS.md §3-2）。
- **标签**：工具栏图标弹层多选 + 新建。
- **优先级**：工具栏旗帜图标（单一入口，不散落表单）。
- **附件**：占位禁用图标 + Tooltip「即将推出」（D5；v1 数据模型无附件字段）。
- **保存（D2）**：编辑页**显式保存**（AppBar 保存按钮）+ 未保存离开提示（PopScope）；新建弹窗**自动保存**（失去焦点/关闭时保存，标题为空则丢弃或提示）。
- 时间选择：日期 + 时间选择器（本地时区显示，存储 UTC 毫秒）。
- 保存校验：标题非空、`endAt >= startAt`、深度限制（新建子任务时）。

### 5.7 设置（`/settings`）

- 分组：外观（主题模式、语言）、同步（入口）、关于。
- 同步配置（`/settings/sync`）：类型选择（坚果云（WebDAV 协议）/S3）、连接参数表单（坚果云提示使用应用密码）、测试连接、自动同步开关、WiFi-only、立即同步、上次同步时间。

## 6. 交互规格

### 6.1 拖拽（FR-TSK-06/07）

| 操作 | 手势 | 行为 |
|---|---|---|
| 同级排序 | 长按任务行拖动 | 目标位置插入，重排 sortOrder |
| 调级 | 拖动到另一任务行上悬停 | 成为其子级（目标高亮） |
| 回到 1 级 | 拖动到项目空白区/项目头 | parentId=NULL |
| 非法目标 | 自身/后代/超深 | 目标红色高亮，松手回弹，提示原因 |

- 校验失败必须**回弹**并提示，禁止静默失败。
- 拖拽反馈：拖动项半透明 + 阴影；目标行高亮边框。
- **文件夹拖拽（M6，`62-folder-nav.md` §6.2）**：项目行长按拖动 → 文件夹行（入夹）/ 未分组区（出夹）/ 同组行（组内排序）；文件夹行拖动 → 文件夹间排序；折叠文件夹作拖放目标时自动展开。

### 6.2 键盘/无障碍兜底（FR-TSK-08）

- 任务行菜单提供：上移 / 下移 / 缩进 / 缩出（与拖拽同校验逻辑）。
- 触控目标 ≥48dp；图标按钮带 `Tooltip` + 语义标签。
- 完成勾选、展开/折叠、菜单均可用键盘操作（Tab 聚焦 + Enter/Space）。

### 6.3 状态反馈

- 空态 / 加载态 / 错误态统一组件（`shared/widgets/`）：
  - 空态：图标 + 文案 + 主操作按钮。
  - 加载：骨架屏或居中 spinner（列表用骨架屏）。
  - 错误：图标 + 文案 + 重试按钮。
- 同步状态：设置页与 AppBar 显示同步指示（进行中 spinner / 失败红点 + 上次同步时间）。

## 7. 无障碍（NFR-06）

- 语义标签：图标按钮、拖拽手柄、状态徽标。
- 对比度：正文与背景对比 ≥4.5:1；语义色在明暗主题下可辨识。
- 字体缩放：跟随系统字体缩放，布局不破（用 `MediaQuery.textScaler` 测试）。
- 拖拽操作均有键盘等价路径（§6.2）。

## 8. 平台细节

| 平台 | 细节 |
|---|---|
| Android | 返回键 `PopScope` 处理（编辑未保存提示）；Monet 动态色；状态栏/导航栏颜色适配主题 |
| Windows | 窗口最小尺寸（如 360×640）；标题栏与主题一致；DPI 缩放正常 |
| 通用 | 深色模式下禁用纯黑背景（用 `surface` 令牌）；滚动条桌面可见、移动隐藏 |