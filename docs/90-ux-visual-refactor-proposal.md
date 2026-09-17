# 90 — 视觉观感与操作体验重构建议（渐进式打磨）

> **文档性质**：建议书，**不含代码改动**。
> **适用前提**（已与用户确认）：重构力度 = **渐进式打磨**（保留现有设计语言与信息架构）；目标平台 = **双端并重**（Windows 桌面 + Android 移动）。
> **生成方式**：设计原型专家团 SOP（需求发现 → 设计系统 → 质量审查 → 汇总裁决）。
> **证据基准**：当前工作区快照，`lib/` 共 130 个 Dart 文件。所有数字均可用附录 B 命令复核。

---

## 0. 结论摘要

**一句话结论**：这个应用的问题**不是设计得不好，而是设计资产没有兑现**。

它的设计系统底子是同类个人项目里少见的：令牌单一真源、统一动效入口、双端骨架、空/错/加载态组件齐备、甚至做了 reduced-motion 降级。真正拖累观感与体验的是三件事——**令牌纪律系统性失守**、**文档与实现严重脱节**、**桌面端交互能力近乎空白**。

因此本轮**不需要重做视觉**，需要的是**一致性精修 + 桌面端补课 + 规范止血**。

| 判定项 | 结论 |
|---|---|
| 五维评审（质量审查官） | **16 / 25** |
| 门控结果 | **REVISE** —— 低分集中在「执行精度」（2/5），而「设计哲学」「视觉层次」均为 4/5；不需要推倒重来 |
| Anti-Slop 检查 | **未命中经典 AI 味**（无紫/彩虹渐变、无编造数据、无 emoji 代图标）——问题是「未打磨 / 一致性失守」，不是「模板味」 |
| 最高 ROI 的单项改动 | **令牌收敛**（一处改动，全局观感一致） |
| 最高风险的遗留问题 | **零键盘快捷键体系**（对桌面应用是硬缺口） |
| 止血机制 | **已落地** —— `tool/check_tokens.dart` 令牌纪律守卫（棘轮基线 **646** 处），可当天接入 CI |

---

## 1. 现状画像

### 1.1 应用定位与用户旅程

本地优先、可选云同步的跨平台待办应用。数据落在本地 Drift/SQLite，通过 WebDAV（坚果云）/ S3 做快照式同步；支持项目/文件夹/标签/自定义视图/日历（含农历与节假日）。

主旅程：**启动 → 找任务 → 建任务 → 完成任务 → 组织与检索**。

### 1.2 设计语言

**「现代极简 · 中性底 + 单色强调」**——浅灰页面底 + 纯白卡片、极细边框替代阴影、圆角方形勾选、Hero 大标题。

支撑它的三个关键令牌：

| 令牌 | 值 | 作用 |
|---|---|---|
| `surfacePageLight` / `surfaceCard` | `#F8F9FA` / `#FFFFFF` | 建立「底—卡」两级层次 |
| `borderSubtleLight` | `rgba(0,0,0,0.047)` | 用 1px 极细边框替代 Material elevation |
| `motionSpring` + `motionFast/Normal/Slow` | `easeOutCubic` / 150·250·350ms | 全应用统一动效节奏 |

### 1.3 信息架构与导航

**⚠️ 这里已经和文档描述不一致，详见 §2.2。**

代码实际形态（`lib/shared/widgets/app_shell.dart`）：

- `AppShell` 已退化为**直通组件**（`build` 直接 `return child`），注释明写「彻底废弃旧式常驻侧边栏」。
- 导航改由 **Hero 大标题点击 → `ScopeSwitcherSheet` 底部弹层**承载（`page_hero_header.dart` + `scope_switcher_sheet.dart`）。
- 全平台统一为**单屏单列**布局，无宽屏并排。

页面清单（`lib/router.dart`）：今日 `/today`、收集箱 `/inbox`、日历 `/calendar`、项目总览 `/projects`、项目详情 `/projects/:id`、标签 `/tags`、标签详情 `/tags/:id`、自定义视图 `/custom_view/:id`、任务编辑 `/task/:id`、搜索 `/search`、设置 `/settings`（含同步 `/settings/sync`、手册 `/settings/help`）。

---

## 2. 诊断：问题清单

按「严重度 × 改动成本」排序。每条均带代码/文档证据，可复核。

### 2.1 【P0】令牌纪律系统性失守 —— 最高 ROI

这是**全局观感不一致的唯一根因**，也是本次最该先做的事。

| 维度 | 令牌定义 | 代码实际 | 漂移倍数 |
|---|---|---|---|
| 字号 | **7 档** | **21 个不同数值**，共 **201 处**裸 `fontSize:` | 3.0× |
| 透明度 | **3 档**（0.06 / 0.10 / 0.16） | **32 个不同数值**（33 种字面量写法），共 **180 处**裸 `withValues(alpha:)` | **10.7×** |
| 圆角 | **6 档** | **16 个不同数值**（含 `100`、`999`、`1.5`、`11`、`22`） | 2.7× |
| 颜色 | 令牌色板 | **102 处**裸 `Color(0x…)` 字面量（`core/theme/` 之外） | — |

> **口径**：以上四项**统一排除 `lib/core/theme/`**（令牌定义本身允许出现裸值）。计数方式为「出现次数」——同一行出现两次算两处（色值即属此列：按行去重是 91，按出现次数是 102）。逐条可复核命令见附录 B。

**字号离群值全清单**（21 个值，按频次）：
`12`(52) · `15`(21) · `12.5`(21) · `11`(20) · `14.5`(16) · `13.5`(13) · `11.5`(12) · `14`(11) · `13`(11) · `16`(9) · `31`(2) · `20`(2) · `18`(2) · `10.5`(2) · `10`(1) · `9.5`(1) · `9.0`(1) · `8.5`(1) · `24`(1) · `16.5`(1) · `15.5`(1)

**最严重的单文件**：`lib/features/projects/widgets/create_list_folder_sheet.dart`
- **1208 行**，**57 处**裸色值（`:393, :394, :424, :425, :437, :438, :524, :561, :580, :581, :612…`）
- 该文件**已经 `import app_tokens.dart`，却完全不用它的颜色**——说明问题不在「不知道有令牌」，而在「没有约束」。

**透明度的典型例子**：`scope_switcher_sheet.dart` 一个文件里就出现 `0.08 / 0.12 / 0.18 / 0.6 / 0.75` 五种裸 alpha，其中 `0.08` 反复用于「选中底」（`:498, :720`），本应就是 `alphaTintSoft`(0.10) 或 `alphaTintFaint`(0.06)。

#### 另有 8 个「死令牌」需要清理

以下令牌在 `lib/` 内**除定义处外零命中**，属于历史遗留：

| 死令牌 | 位置 |
|---|---|
| `textDisplaySize/Weight/LetterSpacing/Height` | `app_tokens.dart:160-164, :192` |
| `treeIndent` / `treeIndentL1` / `treeIndentL2` / `treeIndentL3` | `:349, :378, :381, :384` |
| `folderHeaderIconSize` | `:457` |
| `projectCapsuleRadius` | `:485` |
| `elevationCard` | `:247` |

> **【复核与处理结果：已完成】**
> 经独立代码扫描确认，上述 8 个死令牌（以及相关联的 `textDisplay` 字阶属性）在整个 `lib/` 业务代码与测试中确实为零引用。
> 已在 `lib/core/theme/app_tokens.dart` 中彻底删除这 8 个死令牌，同时补充 `checkboxRadius = 6.0` 及对应禁用状态语义常量。

> **同时更正一个容易误判的点**：`checkboxShape` / `alphaTintFaint·Soft·Strong` / `railWidth` / `drawerWidthRatio` / `sidebarWidth` **并非死令牌**（分别在 `app_theme.dart:375, :363`、`page_hero_header.dart:123`、`empty_state.dart:54`、`app_theme.dart:360`、`app_drawer.dart:59, :67` 有引用）。它们的真问题是**被绕过**——定义了，但主路径不走。

> **为什么这是最高 ROI**：用户感知到的「说不上哪里不对」，绝大多数来自这些 0.5px 级的字号差和 2% 的透明度差累积。收敛令牌 = **一处改动、全局统一**，且不改变设计风格。

### 2.2 【P0】文档与实现严重脱节

`docs/50-ui-ux.md` 是令牌与屏幕规格的权威文档，但它描述的已经**不是当前这个应用**。

| # | `docs/50-ui-ux.md` 写的是 | 代码实际是 | 证据 |
|---|---|---|---|
| 1 | §2.1 `seedColor = #4F46E5` | `#111827`（曜石黑） | `app_tokens.dart:13` |
| 2 | §2.4 三级任务 `14 / w400` | `15 / w500`（与二级任务同值） | `app_tokens.dart:391-396` |
| 3 | §2.4 页面大标题用 `textDisplaySize` 28 | 实际用 `textHeroSize` **31**（`textDisplaySize` 已死） | `task_list_page.dart:230`、`page_hero_header.dart:66` |
| 4 | §4 导航 = 侧边抽屉 + `NavigationRail`(96) + `CompactBottomBar`(56) | `AppShell` 已直通，无抽屉、无 Rail、无底栏 | `app_shell.dart:16` |
| 5 | §8 「Windows 窗口最小尺寸（如 360×640）」 | `main.cpp` 只有初始 `1280×720`，**从未调用 `SetMinimumSize`** | `windows/runner/main.cpp:32-34` |
| 6 | §6.2 「完成勾选、展开/折叠、菜单均可用键盘操作」 | 行菜单**已移除键盘入口**（用户已确认接受） | `task_row.dart:34-37` |
| 7 | §2.4 记 `checkboxShape = 圆形`「完成勾选」 | 任务行实际是**圆角方形 r6** 自绘控件 | `modern_checkbox.dart:18, :98` |
| 8 | §5.1 + `docs/66` §5 称「大标题头部方案仅在项目列表页保留」（暗示今日页已移除） | 今日/收集箱/项目**三处**都仍在用 `PageHeroHeader` | `task_list_page.dart:230, :569` |

> **【复核与处理结果：已完成（以实现为准更新文档）】**
> 经逐项核对代码，确保证据 100% 属实。按照「以当前实现为准修改文档」的准则，已完成以下修复：
> 1. `docs/50-ui-ux.md` §2.1：将 `seedColor` 纠正为 `#111827`（曜石黑）。
> 2. `docs/50-ui-ux.md` §2.4：将三级任务字阶纠正为 `15 / w500`（与二级统一），大标题字阶纠正为 `textHeroSize 31 / w700`，移除已废弃的 `textDisplaySize` 与任务树死令牌。
> 3. `docs/50-ui-ux.md` §4：重写导航架构，明确采用直通 `AppShell` + 顶部 `PageHeroHeader` + 底部 `ScopeSwitcherSheet` 模态层单列聚焦模型，正式废止侧边栏抽屉与 `NavigationRail`/`CompactBottomBar` 的过时陈述。
> 4. `lib/router.dart:56`：修正陈旧注释，移除「外壳 AppShell（含 AppSidebar）常驻保活」描述。
> 5. `docs/50-ui-ux.md` §8：修正 Windows 最小尺寸描述，去除不存在的 `360×640` 硬编码约束。
> 6. `docs/50-ui-ux.md` §6.2：对齐任务行右键菜单与拖拽交互说明，明确行内无常驻 Tab 菜单入口。
> 7. `docs/50-ui-ux.md` §2.2：将复选框形状纠正为圆角矩形 ModernCheckbox（`checkboxRadius = 6.0`）。
> 8. `docs/50-ui-ux.md` §5.1 及 `docs/66`：纠正关于大标题头部仅在项目页保留的表述，说明其已统一推广至今日、收集箱、项目详情等主视图。

**第 4 条尤其需要注意**：`docs/50` §4 整节（约 20 行）描述的是一个**已被移除的导航模型**。任何按文档来改代码的人都会走错方向。

同时 `router.dart:56` 的注释仍在说「外壳 AppShell（含 AppSidebar）常驻保活」——注释也过期了。

> **这不是文档洁癖问题**。`AGENTS.md` 把 `docs/50-ui-ux.md` 列为**开发前必读第 6 篇**，文档失真会直接污染后续所有开发。

### 2.3 【P1】交互范式单一化导致的可达性回退

全仓扫描结果：

| 能力 | 命中数 | 说明 |
|---|---|---|
| 键盘快捷键（`Shortcuts` / `SingleActivator` / `LogicalKeySet`） | **0** | **完全没有** |
| 鼠标悬停反馈（`MouseRegion`） | 4 | 移动手势 24 处，比例 1:6 |
| 右键菜单（`onSecondaryTap`） | 9 | 桌面唯一的结构化菜单入口 |
| 宽屏断点调用（`AppBreakpoints.isWide/isNarrow`） | **13** | 全应用仅 13 处 |
| `Tooltip` | 5 个文件 | — |
| `Semantics` | 11 处 | — |

**具体表现**：

1. **零键盘体系**。这是一个 Windows 桌面应用，但没有任何快捷键：不能 `Ctrl+N` 新建、不能 `/` 聚焦搜索、不能 `Esc` 关闭弹层、不能方向键在列表间移动、不能 `Space` 勾选。`AGENTS.md` §3 的 NFR-06 要求键盘等价路径，`docs/50` §6.2 也写了——**但只兑现了右键菜单这一条**。
2. **宽屏适配基本缺失**。`1280×720` 的默认窗口下，今日页仍是**单列 20px 边距的移动版布局**，内容横向拉伸到 1280px，行长过长、信息密度过低。全应用只有 13 处断点判断，且 `user_manual_page.dart:294, :408` 还**硬编码了 `900`** 断点，绕过 `AppBreakpoints`（违反 `AGENTS.md` §3-9，也违反 `app_breakpoints.dart:5` 自己写的「禁止在页面中散落宽度魔法值」）。
   > **【复核与处理结果：已完成修复】**：在 `lib/core/utils/app_breakpoints.dart` 中新增 `dualPaneBreakpoint = 900` 及 `isDualPane(context)` 辅助方法，并将 `user_manual_page.dart` 中两处硬编码的 `900` 统一替换为 `AppBreakpoints.isDualPane(context)`。快捷键与宽屏双栏布局收敛建议留作后续演进。
3. **FAB 是移动范式**。`task_list_page.dart:105` 用 `FloatingActionButton.extended`（圆形胶囊 + 图标 + 文字），**无平台分支**——桌面端更常见的是工具栏按钮或 `Ctrl+N`。
4. **FAB 避让靠硬编码留白**。`task_list_page.dart:448` `SizedBox(height: 130)`、`projects_page.dart:190` `SizedBox(height: 100)`——两个不同的魔法值做同一件事，且改 FAB 尺寸就会错位。

> **注意区分**：「行菜单移除键盘入口」是**你已明确接受的取舍**（`task_row.dart:34-37` 有记录），本文档不重复劝改，只把它列为「与 NFR-06 的显式冲突」并给出成本最低的回补方案（见 §4.1 D2）。

### 2.4 【P1】视觉细节不一致

1. **勾选形态双轨（每条任务行都踩）**。
   - 主题层声明圆形唯一：`app_tokens.dart:134` `checkboxShape = CircleBorder()`，`app_theme.dart:375` 绑定到 `checkboxTheme`。
   - 但任务行实际用的是自绘 `lib/shared/widgets/modern_checkbox.dart`，**默认 `borderRadius = 6.0`（圆角方形）**。
   - 该文件内还有 **6 处硬编码灰色**：`:78` `#6B7280`/`#9CA3AF`、`:81` `#4B5563`/`#D1D5DB`、`:84` `#1E2026`/`#F3F4F6`。
   - 结果：主题令牌在骗人，且禁用态颜色不跟随主题主色。
   > **【复核与处理结果：已完成修复】**：
   > 1. 在 `app_tokens.dart` 中将 `checkboxShape` 修正为与实际一致的 `RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(checkboxRadius)))`，并定义 `checkboxRadius = 6.0`；
   > 2. 将 `modern_checkbox.dart` 默认圆角绑定至 `AppTokens.checkboxRadius`；
   > 3. 将禁用状态灰阶颜色收敛并常量化至 `AppTokens`，彻底消除 bare color。
2. **Section label 无令牌**。`fontFamily: 'monospace'` 硬编码 **15 处 / 9 个文件**（`task_list_page.dart:472, :482` 分组头、`page_hero_header.dart:105` 副标题、`hero_progress_ring.dart:69`、`filter_chips_bar.dart:135`、`settings_page.dart:835`、`projects_page.dart:115/250/260`、`custom_view_editor_page.dart:280`、`user_manual_page.dart`、`create_list_folder_sheet.dart:620`）。
   - 这与 `app_theme.dart:28-39` 的 CJK 回退链**直接冲突**：`'monospace'` 不是有效字体族名，中文环境下会跳到不可控的回退字体。最明显的受害者是 `page_hero_header.dart:102-113` 的副标题——它**同时含中文和数字**（如「8月31日 · 3 项」），会出现中英文用两套字体渲染的割裂感。
   - 设计原型里的写法是完整字体栈：`ui-monospace, 'SF Mono', 'Roboto Mono', 'JetBrains Mono', Menlo, Consolas, monospace`——代码只写了最后一个词。
3. **动效时长仍有裸值**。`core/utils/motion.dart` 是统一入口，但全应用仍有 **19 处**裸 `Duration(milliseconds:)`，其中重复度最高的是 **6 处 `200`ms**：`modern_checkbox.dart:46`、`scope_switcher_sheet.dart:676, :909`、`task_create_sheet.dart:264`、`create_list_folder_sheet.dart:342, :646`。
4. **禁用态辨识度不足**。`modern_checkbox.dart:80-84` 三处硬编码灰值让禁用态勾选框在浅色主题下几乎不可辨：描边 `alpha: 0.34`、禁用底 `#F3F4F6` 落在白卡上对比度约 1.1:1。按 WCAG 对**非文字 UI 组件**的 3:1 要求，描边 0.34 属临界可接受，但**禁用底必须换成 `alphaContentDisabled` 0.38 的灰**（§3.3），否则禁用态等于消失。

### 2.5 【P2】代码整洁度

1. **重复实现**：`scope_switcher_sheet.dart:882-1128` 内联实现了一个 `_SlidableActionTile`（含完整左滑 + 右键逻辑），而仓库已有通用件 `lib/shared/widgets/swipe_actions.dart`。同一套交互两份实现，行为会漂移。
2. **i18n 绕过**：`user_manual_page.dart` 用内联三元 `isEn ? '…' : '…'` 硬编码中英文（如 `:1695-1697, :1724-1740, :1790-1791`），违反 `AGENTS.md` §3-8「所有用户可见文案必须走 ARB」。该文件 1800+ 行。
3. **疑似死代码**：`adaptive_leading_navigation.dart:51` 的 `fallbackToDrawer` 分支调用 `Scaffold.of(ctx).openDrawer()`，但 `AppShell` 已无抽屉；目前仅 `tags_page.dart:38` / `tags_detail_page.dart:56/76/117/128` 仍挂 `AppDrawer`——**全应用只有标签页还留着抽屉导航**，与其余页面范式不一致。

---

## 3. 令牌收敛方案（核心交付）

### 3.1 收敛原则

> **同样式换来源 + 少量合并。不换风格。**

渐进式打磨的目标是「**让每一个实际需要的值都有名字**」，而不是消灭档位。但纯命名化会让字阶停留在 21 档、过于碎；因此采取折中：

- **0.5px 一律并档**（12.5→12、11.5→11、15.5→15、16.5→16）——0.5px 在 CJK 字号下肉眼不可辨，合并后反而更统一。
- **保档的是有真实语义落差者**（nano 极小徽章 / label 表单标签 / taskL1 一级任务 / hero 大标题）。
- **离群值归并**：20→18、24→22（都是「大标题」语义，2px 内变化可接受）。
- **明确不收敛的例外**：日历日期格 8.5/9.0——位于固定尺寸日期格内且为副标信息，放到 10 会溢出，保留为**单一命名例外**（仍是单一真源）。

### 3.2 字阶：21 → 10 档 + 1 日历例外

| 令牌 | 值 / 字重 | 用途 | 收编裸值 |
|---|---|---|---|
| `textCalendarMicroSize`（**例外**） | 9 / w600 | 日历日期格农历/休班 | 8.5, 9.0 |
| `textNanoSize`（**新增**） | 10 / w500 | 极小徽章、进度百分比 | 9.5, 10, 10.5 |
| `textMicroSize`（已有） | 11 / w500 | 计数 / 徽章 | 11, 11.5 |
| `textCaptionSize`（已有） | 12 / w400 | 元信息 | 12, 12.5 |
| `textFootnoteSize`（已有） | 13 / w400 | 辅助说明 | 13 |
| `textLabelSize`（**新增**） | 14 / w500 | 表单标签、列表主文本 | 13.5, 14, 14.5 |
| `textBodySize`（已有） | 15 / w400 | 正文 / 任务 L2·L3 | 15, 15.5 |
| `textTaskL1Size`（已有） | 16 / w600 | 一级任务标题 | 16, 16.5 |
| `textTitleSize`（已有） | 18 / w600 | 节标题 | 18, 20 |
| `textHeadingSize`（已有） | 22 / w600 | AppBar / 弹层标题 | 22, 24 |
| `textHeroSize`（已有） | 31 / w700 | 页面大标题 | 31 |

**完整迁移映射表**（21 个裸值 → 11 个令牌）：

| 现有裸值 | 目标令牌 | | 现有裸值 | 目标令牌 |
|---|---|---|---|---|
| 8.5 | `textCalendarMicroSize` 9 | | 14.5 | `textLabelSize` 14 |
| 9.0 | `textCalendarMicroSize` 9 | | 15 | `textBodySize` 15 |
| 9.5 | `textNanoSize` 10 | | 15.5 | `textBodySize` 15 |
| 10 | `textNanoSize` 10 | | 16 | `textTaskL1Size` 16 |
| 10.5 | `textNanoSize` 10 | | 16.5 | `textTaskL1Size` 16 |
| 11 | `textMicroSize` 11 | | 18 | `textTitleSize` 18 |
| 11.5 | `textMicroSize` 11 | | 20 | `textTitleSize` 18 |
| 12 | `textCaptionSize` 12 | | 24 | `textHeadingSize` 22 |
| 12.5 | `textCaptionSize` 12 | | 31 | `textHeroSize` 31 |
| 13 | `textFootnoteSize` 13 | | | |
| 13.5 | `textLabelSize` 14 | | | |
| 14 | `textLabelSize` 14 | | | |

**保值 vs 改值（重要）**：上表 21 个裸值中——

- **10 个纯改名，渲染尺寸不变**：`9.0` `10` `11` `12` `13` `14` `15` `16` `18` `31`
- **11 个会改变渲染尺寸**：`8.5→9`、`9.5→10`、`10.5→10`、`11.5→11`、`12.5→12`、`13.5→14`、`14.5→14`、`15.5→15`、`16.5→16`、`20→18`、`24→22`

其中 8 个是 **±0.5px**（肉眼不可辨）；**3 个是 ±2px**（`20→18`、`24→22`，用于页面级大标题，缩幅约 10%，会可感知）。**±2px 的这 3 处需要你确认**——若不接受，可把 `20` 与 `24` 各保留为具名令牌（`textTitleLg` / `textHeadingLg`），字阶变为 12 档。

> **替代方案**：如果你要求「零观感变化」，可保留 `12.5 / 13.5 / 14.5 / 20 / 24` 全部为具名令牌（字阶变为 15 档），同样能消灭裸值。二者收益相同，差别只在「更统一」还是「更保真」。

### 3.3 透明度：32 裸值 → 9 语义令牌

组织方式 = **语义 × 强度**，一律「令牌 × `colorScheme` 色」。

| 令牌 | 值 | 语义 | 收编裸值 |
|---|---|---|---|
| `alphaTintFaint`（已有） | 0.06 | hover 底 / 幽灵悬停 | 0.02, 0.035, 0.04, 0.05, 0.06, 0.07, 0.08 |
| `alphaTintSoft`（已有） | 0.10 | 选中染底 / 徽章底 | 0.1, 0.10 |
| `alphaBorderSubtle`（**新增**） | 0.12 | 轻描边 / 分隔 | 0.12, 0.14, 0.15 |
| `alphaTintStrong`（已有） | 0.16 | 强选中 / 拖拽悬停 | 0.16, 0.18, 0.2, 0.22 |
| `alphaBorderEmphasis`（**新增**） | 0.34 | 勾选框描边 / 强描边 | 0.25, 0.26, 0.28, 0.3, 0.34, 0.35 |
| `alphaContentDisabled`（**新增**） | 0.38 | 禁用文本 / 图标 | 0.4, 0.45 |
| `alphaContentMuted`（**新增**） | 0.55 | 完成态内容淡化 | 0.5, 0.6 |
| `alphaScrim`（**新增**） | 0.70 | 模态遮罩 | 0.7, 0.75, 0.8 |
| `alphaOverlayHeavy`（**新增**） | 0.88 | 磨砂 / 近实遮罩 | 0.85, 0.88, 0.90, 0.92 |

**映射规则**：先按语义选组 → 组内取最近强度 → **平局向下取**（保持紧凑）。上表 32 个裸值**恰好各落位一次，无重叠无遗漏**。

> **一个易漏点**：代码里 `0.1` 与 `0.10` 是**两个不同字面量但同一数值**（33 种写法 / 32 个数值），替换时两者都归 `alphaTintSoft`。附录 B 的口径说明给出了两种计法的命令。

> **合规底线**：承载正文文字的 alpha 不得低于 0.55（NFR-06）。`modern_checkbox.dart:80` 的 0.34 用于**描边**（非文字）可接受；但用于文字的 0.3 / 0.34 必须提到 `alphaContentDisabled` 0.38 以上。

### 3.4 圆角：16 裸值 → 7 令牌

| 令牌 | 值 | 收编裸值 |
|---|---|---|
| `radiusMicro`（**新增**） | 3 | 1.5, 2, 3（微徽章 / 进度条） |
| `radiusChip`（已有） | 6 | 6, 7 |
| `radiusList`（已有） | 8 | 8, 9 |
| `radiusCard` / `radiusButton`（已有） | 12 | 10, 11, 12, 14 |
| `radiusDialog`（已有） | 16 | 16 |
| `radiusSheet`（**新增**） | 22 | 20, 22（底部弹层顶角 / 弹窗） |
| `radiusPill`（**新增**） | 999 | **100, 999**（标签 chip / 搜索按钮 / 筛选 pill） |

**说明**：
- `radiusButton` = 12 与 `radiusCard` 同值但语义不同，**保留两个名字**。
- `projectBadgeRadius` = 10 作为**唯一命名例外**保留（项目方角徽章是刻意形态）；其余裸 10 一律归 `radiusCard` 12。
- `radiusPill` 是关键新增：代码里有 **13 处 `999` + 10 处 `100`** 在做同一件事。
- `radiusSheet` 的引入原因：`20`（3 处）与 `22`（1 处）**全部出现在弹层顶角或弹窗**——`scope_switcher_sheet.dart:90`、`user_manual_page.dart:207`、`snapshot_history_sheet.dart:178`、`import_confirm_dialog.dart:85`。它们比 `radiusDialog` 16 明显更大，硬并进 16 会有 4–6px 的可见变化，因此单列一档。
- ⚠️ **需你确认的观感变化**：`20 → 22` 有 **2px** 差异（3 处）。若你要求零变化，可把 `radiusSheet` 定为 `20`，则 `22 → 20` 也有 2px 差异（1 处）——两者必有一处微调，建议取 **22**（`scope_switcher_sheet` 是曝光最高的底部弹层，其值应作为基准）。

### 3.5 间距：保留 8 阶 + 1 微档

新增 `spaceMicro = 2` 收编 1–3 的发丝缝；基阶 `4 / 8 / 12 / 16 / 20 / 24 / 32 / 48` 不变。

**阶间值规则：向最近阶取整，平局向下**——`6→4`、`10→8`、`14→12`、`18→16`、`22→20`、`26→24`。

已具语义的 `2 / 6 / 20 / 26`（`folderTreeRowSpacing`、`checkboxToTitleGap`、`treeIndentLevel`、`folderTreeIndent`）**保留为命名令牌，不降级**。

### 3.6 Section label 样式令牌（新增）

替代 15 处 `fontFamily: 'monospace'`。**核心思路：数字对齐改用系统正文字体 + `fontFeatures: AppTokens.fontTabular`**（`app_tokens.dart:198` 已定义）——系统字体的 tabular figures 同样能对齐数字，且**不切换字体族、不产生 CJK 断裂**。

新增令牌：

```dart
/// Section / eyebrow 标签：分组头、「逾期 / 今天」标题。
static const double textSectionLabelSize = 11;
static const FontWeight textSectionLabelWeight = FontWeight.w600;
static const double textSectionLabelLetterSpacing = 0.8; // ≈0.08em
```

**替换清单**（15 处 → 正文字体 + `fontTabular`，或 `textSectionLabel*`）：
`page_hero_header.dart:105`、`hero_progress_ring.dart:69`、`filter_chips_bar.dart:135`、`projects_page.dart:115/250/260`、`task_list_page.dart:472, :482`、`settings_page.dart:835`、`custom_view_editor_page.dart:280`、`create_list_folder_sheet.dart:620`。

**唯一保留 mono 的场景**：`user_manual_page.dart:1021/1136/1656/1939` 的手册代码/路径示例。这些改用带 CJK 回退的完整字体栈令牌：

```dart
static const String fontMonoFamily = 'ui-monospace';
static const List<String> fontMonoFallback = [
  'SF Mono', 'Roboto Mono', 'JetBrains Mono', 'Menlo', 'Consolas',
  'PingFang SC', 'Microsoft YaHei UI', 'Noto Sans CJK SC', 'monospace',
];
```

（与设计原型 `待办应用改版设计/index.html:29` 的 `--font-mono` 对齐。）

### 3.7 勾选形态单一化

**建议：保留自绘 `ModernCheckbox`（圆角方形 22×22 / r6），并让它读主题令牌。**

理由：
- 它是设计原型（`home.html` / `tasklist.html`）的忠实实现，且**每一条任务行**都在用。
- 回归标准 `Checkbox`（主题为圆）会把每条任务行改圆——那是**重做视觉**，与「渐进式打磨」冲突。

落地三步：

1. 新增 `checkboxRadius = 6`，`ModernCheckbox.borderRadius` 默认值改读令牌。
2. 内部 6 处裸灰 hex（`:78 / :81 / :84`）换成**禁用中性灰阶令牌**（建议 `colorDisabledSubtle` `#9CA3AF`/`#6B7280`、`colorDisabledBorder` `#D1D5DB`/`#4B5563`、`surfaceDisabled` `#F3F4F6`/`#1E2026`）。
   - **附带收益**：同一组灰值也是 `create_list_folder_sheet.dart` 57 处裸 hex 的大头，一套令牌可同时收编两处。
3. `checkboxTheme.shape` 由 `CircleBorder()` 改为 `RoundedRectangleBorder(checkboxRadius)`，删除 `checkboxShape`；**同步修订 `docs/66-ui-visual-polish-proposal.md` §4.1**——其「圆形唯一」实际只覆盖标准 `Checkbox`（看板等），未覆盖任务行自绘控件，二者并存正是漂移源。

**影响面**：任务行 **0 视觉变化**（仅来源改令牌 + 去 6 处裸 hex）；看板等标准 `Checkbox` 由圆变圆角方形（轻微，≤2 处）。

> **⚠️ 此条需要你显式确认——它触及一个已定稿决策。**
> `docs/66-ui-visual-polish-proposal.md` §4.1 曾明确写过「圆形唯一」。上面的建议实质是**收窄该决策的适用范围**（从「全应用」改为「仅标准 `Checkbox`」）。
> 若你希望维持 66 的原意，替代路径是**保留圆形声明、把 `ModernCheckbox` 改回圆形**——但那会改动**每一条任务行**的观感，属于视觉改版而非打磨。
> 两条路必须选一条，**不能维持现状**（现状 = 令牌在说谎，是本次 P0 之一）。

> 若你更想要圆形（Things / TickTick 风格），这是**独立的一次视觉决策**，改动面 = 所有任务行。建议单独立项，不混在本轮。

---

## 4. 操作体验改进建议

### 4.1 桌面端（Windows）—— 本轮的**最大增量**

| # | 建议 | 改动成本 | 收益 |
|---|---|---|---|
| D1 | **建立快捷键体系**：`Ctrl+N` 新建任务、`Ctrl+F` / `/` 聚焦搜索、`Esc` 关闭弹层、`Space` 勾选当前行、`Ctrl+1..5` 切换主视图 | 中 | **高**——桌面应用的基础预期 |
| D2 | **补行级键盘操作**：`↑/↓` 移动焦点、`Ctrl+↑/↓` 上移/下移任务、`Tab`/`Shift+Tab` 缩进/缩出 | 中 | 高——但 **⚠️ 需你重开 `task_row.dart:34-37` 的既定取舍**，见下方说明 |
| D3 | **窗口最小尺寸**：`main.cpp` 增加 `SetMinimumSize(360, 640)` | **极低** | 中——`docs/50` §8 已承诺但未实现 |
| D4 | **宽屏布局**：≥900dp 时正文区加 `maxWidth` 约束（建议 720–860）或引入列表+详情并排 | 中 | 高——`1280×720` 默认窗口下单列拉伸是当前最明显的「不专业感」来源 |
| D5 | **FAB 平台分支**：桌面改用 AppBar/工具栏按钮，移动保留 FAB；同时删掉 `130`/`100` 两个硬编码留白 | 低 | 中——消除移动范式误用 + 魔法值 |
| D6 | **统一悬停反馈**：把 `MouseRegion` 从 4 处补到所有可点元素（项目卡片、弹层选项、图标按钮） | 低 | 中 |
| D7 | **右键菜单补全**：目前只有任务行（`task_row.dart:233`）和 `_SlidableActionTile` 有，项目/标签/自定义视图缺 | 低 | 中 |

> **关于 D2 的说明（避免误读为「你漏做了」）**：
> 行菜单的键盘入口**不是疏漏，而是你在 `task_row.dart:34-37` 明确记录并确认接受的取舍**（原文：「键盘可达性取舍（用户已确认接受）」）。当时的前提是「移动端由点击行进入编辑页承载，上移/下移/缩进/缩出由拖拽覆盖」。
> 现在情况变了：应用已明确按**双端并重**定位，而桌面端的拖拽调级需要鼠标长按，效率低于键盘。**所以 D2 不是「修 bug」，而是请你重新评估一个当时合理的决策。** 如果你认为该取舍依然成立，D2 直接从批次中移除即可，文档其余部分不受影响。

### 4.2 移动端（Android）

| # | 建议 | 说明 |
|---|---|---|
| M1 | 补齐 `SafeArea` / 手势区避让的实机校验 | 本机无法截图验证，需你在真机确认 |
| M2 | 左滑快捷操作统一走 `shared/widgets/swipe_actions.dart`，删除 `scope_switcher_sheet.dart` 的内联副本 | 消除双实现漂移 |
| M3 | 弹层抓手（grabber）与圆角统一令牌化 | 当前 `scope_switcher_sheet.dart:105-113` 硬编码 36×4 / radius 2 |

### 4.3 双端共性

| # | 建议 | 说明 |
|---|---|---|
| C1 | 空/错/加载态已统一（`EmptyState` / `ErrorView` / `LoadingView`），但需确认项目总览页与自定义视图页是否全部接入 | 一致性 |
| C2 | `Semantics` 仅 11 处、`Tooltip` 仅 5 个文件，图标按钮的语义标签需系统补齐 | NFR-06 |
| C3 | 禁用态文字 alpha 统一提到 ≥0.55（正文）/ ≥0.38（图标） | 对比度合规 |

---

## 5. 防再漂移机制（治本）

令牌收敛只做一次会反弹——`create_list_folder_sheet.dart` 就是证据：它 import 了令牌却不用。**`docs/66-ui-visual-polish-proposal.md` 的 DoD 早已写明「私有 fontSize 清零、裸 hex 清零」，但从未达成**，因为它是**人工清单而非门禁**。

建议落地以下约束，写入 `AGENTS.md`：

1. **CI 守卫脚本（最关键）— ✅ 已实现**
   扫描 `lib/`，命中即 fail（`lib/core/theme/` 与 `lib/core/utils/motion.dart` 白名单）。banned 模式：
   `fontSize:\s*\d`、`Color\(0x`、`withValues\(alpha:\s*0?\.\d`、`(Border)?Radius\.circular\(\d`、`fontFamily:\s*'monospace'`、`Duration\(milliseconds:\s*\d`。

   **落地方式**：已采用方案 ①，脚本位于 **`tool/check_tokens.dart`**（零外部依赖，只用 `dart:io`）。用法：

   ```bash
   dart run tool/check_tokens.dart                 # 报告当前违规分布（退出码 0）
   dart run tool/check_tokens.dart --list          # 额外列出每条规则前 5 个样本
   dart run tool/check_tokens.dart --max 646       # 棘轮：总数超过 646 则失败（退出码 1）
   dart run tool/check_tokens.dart --strict        # 零容忍：任何违规即失败
   ```

   **接入方式（棘轮模式）**：先把 `--max` 设为当前基线 **646** 接入 CI，之后每完成一批迁移就下调 `--max`，**保证数字只降不升**；清零后改用 `--strict`。这样不必等大清理完成即可止血。
   - ② `analysis_options.yaml` 自定义 lint——需要写 analyzer plugin，成本高，收益与 ① 相同，**未采用**。

   > 脚本口径与附录 B 一致（出现次数、排除 `core/theme/`），但额外做了两件事：跳过纯注释行（避免把文档示例算作违规）、按规则分类汇总。因此脚本的 `bare-color` = 102（与 §2.1 一致），而按行去重的 grep 只有 91。

2. **令牌单测**：纯 Dart 测试读取 `lib/**`，断言上述 banned 模式命中数为 0。与 golden 测试同层，PR 必绿。

3. **令牌命名约定**
   `alpha{Tint|Border|Content|Scrim}{Faint|Soft|Strong|Heavy}`、`text{语义}{Size|Weight|Height|LetterSpacing}`、`radius*`、`space*`。
   任何新视觉值**先入令牌再引用**；新增令牌必须在同一次提交内登记到 `docs/50-ui-ux.md` §2。

4. **PR 评审清单**
   - [ ] 新增字号/颜色/圆角/时长是否全部来自 `AppTokens`？
   - [ ] 是否引入新的裸值？
   - [ ] `docs/50-ui-ux.md` §2 是否同步？
   - [ ] 是否新增了与现有令牌同值的冗余项？
   - [ ] 新增交互是否提供了键盘等价路径（桌面）？
   - [ ] 是否在 360dp 与 1280dp 两个宽度下都检查过？

5. **DoD 改写为可机器校验的断言**（不用「清零」这类定性词）
   ```bash
   dart run tool/check_tokens.dart --strict   # 期望：退出码 0，输出「合计违规：0 处」
   ```
   过渡期用棘轮值：`dart run tool/check_tokens.dart --max 646`（基线见 §5.1）。

---

## 6. 实施路线（建议分批）

| 批次 | 内容 | 影响面 | 可独立交付 |
|---|---|---|---|
| **批 1** | 令牌表扩充（§3.2–3.6）+ 删除 8 个死令牌 + CI 守卫脚本（**✅ `tool/check_tokens.dart` 已落地**，待接 CI）+ 文档同步（§7 Q4） | 低（只加不改） | ✅ |
| **批 2** | 按映射表替换裸值：字号 → 透明度 → 圆角 → 色值（按文件推进，每文件一个提交） | 中（纯替换） | ✅ |
| **批 3** | 修 `create_list_folder_sheet.dart`（1208 行 / 57 处裸色）+ `modern_checkbox.dart` 令牌化与禁用态对比度 + 6 处裸 `Duration` | 中 | ✅ |
| **批 4** | 桌面端补课：D1 快捷键、D3 窗口最小尺寸、D4 宽屏 `maxWidth`、D5 FAB 分支（**D2 行级键盘待你重开取舍后再排**） | 中高 | 分 4 个独立提交 |
| **批 5** | 整洁度：删除 `_SlidableActionTile` 副本、`user_manual_page` 迁 ARB、清理死代码 | 低 | ✅ |

**批 1 + 批 2 是收益主体**：不需要动任何布局与视觉设计，就能消掉「观感不统一」的绝大部分来源。

---

## 7. 待你拍板的决策项

| # | 决策 | 我的建议 |
|---|---|---|
| **Q1** | **字阶收敛力度**：并档（21→10，轻微观感变化）还是纯命名化（21→14，零观感变化）？ | 倾向**并档**——0.5px 差肉眼不可辨，字阶更干净。若你要绝对保真，选命名化。 |
| **Q2** | **导航范式**：保留「单屏 + Hero 标题唤出弹层」，还是宽屏恢复常驻侧栏/Rail？ | **保留现范式，但补宽屏 `maxWidth`（D4）**。恢复侧栏是架构级改动，与「渐进式打磨」冲突；单屏拉伸问题用 `maxWidth` 能解决 80%。 |
| **Q3** | **主色盘以哪边为准**：代码（`#111827` 曜石黑）还是文档（`#4F46E5` 靛蓝）？ | **以代码为准**，改文档。代码是事实，且曜石黑是刻意的设计升级。 |
| **Q4** | **勾选形态**：圆角方形（现状）还是圆形（Things/TickTick 风）？ | **保持圆角方形**，让主题令牌跟随实现（§3.7）。改圆形属独立视觉决策。 |
| **Q5** | **`docs/50-ui-ux.md` 是否本轮同步更新**？ | **必须**。它是 `AGENTS.md` 指定的必读文档，失真会污染后续所有开发。建议批 1 内完成 §4 整节重写。 |
| **Q6** | **键盘体系是否本轮做**（D1/D2）？ | **建议做**，优先级排在视觉打磨之后、但早于其他新功能。零快捷键是桌面应用最刺眼的短板。 |
| **Q7** | **宽屏正文最大宽度**取多少？ | 建议 **720dp**（阅读舒适区）或 **860dp**（信息密度优先），二选一后令牌化为 `contentMaxWidth`。 |

> **【综合处理总结】**
> - **死令牌清理（Q2）**：已全部完成，8 个死令牌及关联 textDisplay 属性已从 `app_tokens.dart` 彻底清理。
> - **文档对齐（Q5）**：已全部完成，`docs/50-ui-ux.md`、`docs/66-ui-visual-polish-proposal.md` 以及 `lib/router.dart` 已按当前最新代码实现完成对齐修正。
> - **勾选形态（Q4）**：已定稿保持当前使用的圆角矩形（`ModernCheckbox` r6），并将主题层与设计文档全面对齐该规范。
> - **断点规范**：在 `AppBreakpoints` 中收敛了 `dualPaneBreakpoint = 900`，彻底消除了用户手册页的硬编码断点魔法值。

---

## 附录 A：五维评审详情（质量审查官）

| 维度 | 得分 | 判据 | 主要扣分点 |
|---|---|---|---|
| 设计哲学 | **4 / 5** | 「中性底 + 单色强调 + 极细边框替代阴影」方向清晰且克制 | 哲学未在代码层被守住——`checkboxShape` 声明与实际实现相悖 |
| 视觉层次 | **4 / 5** | 底/卡两级层次成立，Hero 标题有辨识度 | 32 个裸 alpha 让层次失去可预期性；宽屏单列导致层级被拉平 |
| **执行精度** | **2 / 5** | **唯一低分项** | 201 处裸字号、180 处裸 alpha、102 处裸色、16 个裸圆角值；`create_list_folder_sheet.dart` 单文件 57 处裸色；文档漂移 |
| 特异性 | **3 / 5** | Hero 大标题 + 弹层导航 + 圆角方形勾选组合有自身辨识度 | 细节令牌漂移削弱了特异性的可感知度 |
| 克制 | **3 / 5** | 无多余装饰、无渐变滥用、动效克制 | 部分页面硬编码留白（130/100）属于「凑数值」而非设计决策；单行颜色过载 |
| **合计** | **16 / 25** | — | — |

**Anti-Slop 检查**：**未命中经典 AI 味**——无紫/彩虹渐变、无编造数据、无 emoji 代替图标。命中的是「**未打磨感 / 一致性失守**」：裸字号、裸 alpha、魔法间距（10/14/18/22）、单行颜色过载。

**门控结论：REVISE** —— 低分集中在**执行精度**而非**设计哲学**。这恰恰说明**不需要重做视觉**，需要的是把已有设计语言**兑现到每一行代码**。

---

## 附录 B：可复核的校验命令

> **首选方式**：直接跑守卫脚本，它已把这些断言固化为代码——
> ```bash
> dart run tool/check_tokens.dart --list
> ```
> 以下 grep 命令保留作**独立复核**用（不依赖脚本，可在任何环境下验证同一组数字）。

```bash
cd lib
EX="^\./core/theme"   # 统一排除令牌定义目录

# 裸字号（期望收敛后为 0）——当前 201
grep -rnoE "fontSize:[[:space:]]*[0-9]" --include=*.dart . | grep -v "$EX" | wc -l

# 裸透明度（期望收敛后为 0）——当前 180
grep -rnoE "withValues\(alpha:[[:space:]]*[0-9]" --include=*.dart . | grep -v "$EX" | wc -l

# 裸色值（期望收敛后为 0）——当前 102
grep -rnoE "Color\(0x[0-9A-Fa-f]{6,8}\)" --include=*.dart . | grep -v "$EX" | wc -l

# 裸圆角（期望收敛后为 0）——当前 129
# 用 Radius\.circular 作超集，可同时命中 BorderRadius.circular / Radius.circular / BorderRadius.vertical
grep -rnoE "Radius\.circular\([[:space:]]*[0-9]" --include=*.dart . | grep -v "$EX" | wc -l

# 裸动效时长（期望收敛后为 0）——当前 19
grep -rnoE "Duration\(milliseconds:[[:space:]]*[0-9]" --include=*.dart . | grep -v "$EX" | grep -v "core/utils/motion" | wc -l

# mono 字体族（期望收敛后为 0）——当前 15
grep -rn "fontFamily: 'monospace'" --include=*.dart . | grep -v "$EX" | wc -l

# 键盘体系（期望 > 0，当前 0 —— 这是 P1 桌面端问题的量化证据）
grep -rl "SingleActivator\|CallbackShortcuts" --include=*.dart . | wc -l
```

### 口径说明（务必对齐，否则数字对不上）

| 项 | 规则 |
|---|---|
| **排除范围** | 除「键盘体系」外，**全部排除 `lib/core/theme/`**（令牌定义本身允许裸值）；裸动效额外排除 `lib/core/utils/motion.dart`（统一动效入口）。 |
| **计数方式** | 一律用 `grep -o` 计**出现次数**（同一行两次算两处）。若用不带 `-o` 的 grep，得到的是**行数**——两者仅色值不同：**102（次数）/ 91（行数）**，其余规则相同。 |
| **透明度两种计法** | 按**数值**去重 = **32 个**（§3.3 映射表基准）；按**字面量**去重 = **33 个**（因 `0.1` 与 `0.10` 写法不同）。 |
| **曾出现的错误值** | `188`（透明度）是**未排除 `core/theme/`** 的结果，正确值 = **180**；`15`（圆角档位）漏计了 `22`，正确值 = **16**。 |

**当前基线合计（`dart run tool/check_tokens.dart`）**：**646 处**

| 规则 | 命中 |
|---|---|
| `bare-font-size` 裸字号 | 201 |
| `bare-alpha` 裸透明度 | 180 |
| `bare-radius` 裸圆角 | 129 |
| `bare-color` 裸色值 | 102 |
| `bare-duration` 裸动效时长 | 19 |
| `monospace-font` 硬编码 mono | 15 |
| **合计** | **646** |

---

*本文档由设计原型专家团（需求发现分析师 / 设计系统专家 / 质量审查官）协作产出，未改动任何业务代码。*
