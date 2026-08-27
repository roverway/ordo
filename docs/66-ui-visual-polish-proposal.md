# 66 — 外观质感升级提案：沉浸式纲领与高级简约定稿

> 状态：**FINAL（已实施）**。本文档同时补上 `app_tokens.dart` 中悬空引用的
> 「现代质感升级」出处（66 号此前未落盘，本次一并归档）。
> 涉及令牌一律以 `lib/core/theme/app_tokens.dart` 为准，改代码必改文档。

## 1. 设计纲领

**内容优先的沉浸式表面 + 极少卡片容器**。0ede52e 已在日历页落地
（去卡片边框/阴影、周期标题融入 AppBar），本提案将其确立为全 app 视觉语言：

1. **层级靠排版与留白，不靠装饰容器**——能平铺在页面基底上的内容不再包卡片；
   卡片语言统一为「1px 细边框 + radiusCard 12 + 双层弥散阴影」单一系统
   （任务卡/看板卡/设置卡/项目卡一致），Material elevation 仅保留给浮层。
2. **同一概念单一形态**——圆形勾选框全 app 唯一实现（主题层 Checkbox）；图标
   基座/outlined 家族统一，filled 只表达「选中态」（侧栏）或「激活态」（筛选）。
3. **克制而精确的微交互**——既有 motion.dart 纪律（reduced-motion 全覆盖）
   不变；错落入场、勾选弹性、按压缩放全部保留。

与日历顶栏的关系：日历是工具型周期导航放 AppBar；今日页等情感型概览页用
静态大标题头部（`PageHeroHeader`，不折叠）。两者并存互补。

## 2. 字阶体系化（4 → 7 档）

新增 display / footnote / micro 三档收编散落的私有字号
（10 / 10.5 / 11 / 11.5 → micro 11；12.5 → caption 12；13 / 13.5 → footnote 13）：

| 新令牌 | 值 | 用途 |
|---|---|---|
| `textDisplaySize/Weight/LetterSpacing` | 28 / w700 / −0.5（行高 1.2） | 页面大标题头部 |
| `textFootnoteSize/Weight` | 13 / w400 | 辅助说明层 |
| `textMicroSize/Weight` | 11 / w500 | 徽章/计数（正文类仍 ≥ caption，保 NFR-06） |

行高落地 `app_theme.textTheme`：bodyLarge/bodyMedium height 1.45、bodySmall 1.35，
给 CJK 正文呼吸感。`fontTabular=[tabularFigures]` 用于日期/计数数字对齐。

## 3. 颜色语义化

- **凹陷面**：`surfaceSunkenLight #EFF1F4` / `surfaceSunkenDark #12141A`——比页面底
  沉一档的内嵌区域。清掉看板列硬编码魔值 `#F1F3F6`（浅深双模式对称取自令牌），
  输入井 fillColor 同步接入（替代 surfaceContainerHighest 30% ad-hoc alpha）。
- **语义罩染三档**：`alphaTintFaint .06 / alphaTintSoft .10 / alphaTintStrong .16`。
  约定罩染 = 语义令牌 × colorScheme 色，不再出现裸数字透明度；存量 ad-hoc alpha
  在触及文件处就近替换（本次：看板列 hover 染色、空态背衬圆等）。

## 4. 组件层定稿

1. **勾选形态唯一**：看板卡手绘 18px 圆 → 标准 `Checkbox`（shrinkWrap 紧凑触控），
   形状走主题层 `checkboxShape` 圆形；方形变体 `checkboxShapeSquare` 及
   `checkboxRadius` 已零引用，随本提案删除。
2. **图标家族统一**：custom_views / 抽屉品牌区 / 日历下拉箭头的 `_rounded` 变体
   全部回归基座或 `_outlined`；侧栏选中态 outlined↔filled 切换的既有好设计保留。
3. **卡片语言归一**：settings `_SettingsCard` 与 `project_card` 由 Material elevation
   （含抬升动画）迁移至 `DesktopHoverContainer` 的「细边框+双层弥散阴影」语言，
   项目卡保留按压 scale 0.98 微反馈；孤立的 elevation/shadow 单值令牌删除
   （`elevationCard` 因浮层仍在使用而保留）。
4. **EmptyState v2**：主色调淡染背衬圆（`emptyBackdropSize`=72、内部图标 32，
   primary × alphaTintSoft）+ 加权主文案 + 可选副描述 + 可选操作按钮插槽；
   日历议程空态保持自有更丰富实现（已是标杆）。
5. **抽屉树状引导线复活**：按 62-folder-nav §6.1 des-2 以 `_FolderRailPainter`
   自绘全高渐变竖线（folderTreeLineWidth=2 圆头，alpha 0.12→0.45 上淡下浓），
   替代退化的纯缩进；`folderTreeConnectorWidth` 随新形态删除。

## 5. 页面层定稿：静态大标题头部（今日/项目）

新共享组件 `shared/widgets/page_hero_header.dart`：

- display 大标题 + 可选副标题 + 完成概览行（ARB 文案 `tasksCompletedCount` +
  LinearProgressIndicator minHeight 4、圆角胶囊、填充 colorDone 绿）。
- **今日页**：固定头部（不随列表滚动）：大标题 = 完整日期（「8月27日 星期三」/
  `formatFullDateLine`），避免与 AppBar「今日」字面重复；概览 = 逾期+今天两桶汇总。
  空态时头部照常显示、下方出 EmptyState。
- **项目列表页**：大标题「项目」+ 计数副标题（`projectCount`·`folderCount` ARB）。
- 新增 ARB 词条：`tasksCompletedCount` / `projectCount` / `folderCount`（zh/en）。

## 6. 留白节奏统一

- 内容横距全 app 统一 spaceMd=16：任务树水平 padding 8→16
  （**覆盖 61 §3.2 用户打磨要求 3 的旧决策**）、日历议程行距 2→spaceXs。
- 日历残留魔值收编：宽屏左栏宽 400→`calendarPaneWidth` 令牌；AppBar 标题
  InkWell 内边距 h8/v4→spaceXs/spaceXxs。

## 7. 与既往文档的差异声明

| 事项 | 旧定稿 | 本提案 |
|---|---|---|
| 任务树列表横距 | 61 §3.2 用户打磨要求 3（spaceXs=8） | spaceMd=16 跨页统一（§6） |
| 方形勾选框 | 61 §4.2 checkboxShapeSquare | 删除，圆形唯一（§4.1） |
| 项目/设置卡阴影 | 63 §5 H elevation 抬升动画 | DesktopHoverContainer 弥散阴影语言（§4.3） |
| 日历视口 | b546347 卡片式 `_CalendarCard` | 0ede52e 沉浸式 `_CalendarViewport`（§1） |

## DoD

- [x] analyze 0 error / test 全绿 / dart format
- [x] 功能区内 `_rounded` 图标清零、私有 fontSize 清零、裸 hex 清零
- [x] 今日/项目页呈现大标题头部与完成概览
- [x] 死令牌全部处置（删除或复活），50-ui-ux.md 与代码一致
