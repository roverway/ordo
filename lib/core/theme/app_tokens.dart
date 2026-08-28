import 'package:flutter/material.dart';

/// Design Tokens — the single source of truth for all visual values.
///
/// Inspired by TickTick's restrained palette + Microsoft To Do's task-first
/// minimalism. Soft blues, generous whitespace, gentle rounded corners.
///
/// All UI code must reference these tokens; no magic values (AGENTS.md §3-9).
abstract final class AppTokens {
  // ── Color ──

  /// Seed color: refined Electric Indigo / Iris.
  static const Color seedColor = Color(0xFF4F46E5);

  /// Done — refined Emerald green.
  static const Color colorDone = Color(0xFF059669);

  /// In Progress — match seed indigo.
  static const Color colorInProgress = Color(0xFF4F46E5);

  /// Cancelled — neutral gray.
  static const Color colorCancelled = Color(0xFF9CA3AF);

  /// Overdue — elegant rose red (gentle, not harsh).
  static const Color colorOverdue = Color(0xFFE11D48);

  /// Inbox project accent — warm violet.
  /// 与 todo_repository.dart 的 inboxProjectColor 保持一致（DB 实际写入值）。
  static const Color colorInbox = Color(0xFF6C5CE7);

  /// Page surface (light) — pure crisp cool off-white.
  /// (docs/66-ui-visual-polish-proposal.md)
  static const Color surfacePageLight = Color(0xFFF8F9FA);

  /// Page surface (dark) — Linear deep charcoal.
  static const Color surfacePageDark = Color(0xFF0D0E11);

  /// Card surface (light) — pure white.
  static const Color surfaceCard = Color(0xFFFFFFFF);

  /// Card surface (dark) — Linear elevated charcoal container.
  static const Color surfaceCardDark = Color(0xFF16181D);

  /// Sunken surface (light) — inset wells that sit one step below the page:
  /// kanban column background, search input fills.
  /// (docs/66-ui-visual-polish-proposal.md §3)
  static const Color surfaceSunkenLight = Color(0xFFEFF1F4);

  /// Sunken surface (dark) — between page charcoal [surfacePageDark] and
  /// card charcoal [surfaceCardDark].
  static const Color surfaceSunkenDark = Color(0xFF12141A);

  // ── Semantic tint alphas（语义罩染强度）──
  //
  // 收编页面里随手写的 alpha 值。约定：罩染一律「语义令牌 × colorScheme 色」，
  // 不再出现裸数字透明度。（docs/66-ui-visual-polish-proposal.md §3）

  /// 极淡罩染：hover 底色、幽灵按钮悬停、轻提醒背景。
  static const double alphaTintFaint = 0.06;

  /// 淡罩染：选中态低饱和染底、数量徽章底（对应既往 10–12% 档）。
  static const double alphaTintSoft = 0.10;

  /// 强罩染：强选中/拖拽悬停等最高强调档（对应既往 15–16% 档）。
  static const double alphaTintStrong = 0.16;

  /// Subtle border (light) — ~4.7% black.
  static const Color borderSubtleLight = Color(0x0C000000);

  /// Subtle border hover (light) — ~10% black.
  static const Color borderSubtleHoverLight = Color(0x1A000000);

  /// Subtle border (dark) — ~6% white micro-glow.
  static const Color borderSubtleDark = Color(0x0FFFFFFF);

  /// Subtle border hover (dark) — ~16% white glow highlight.
  static const Color borderSubtleHoverDark = Color(0x28FFFFFF);

  /// Checkmark glyph on the filled (done) circular checkbox.
  static const Color colorOnCheck = Colors.white;

  /// Done checkbox fill / border — Neutral Gray (matches onSurfaceVariant in theme).
  static const Color checkboxDoneFill = Color(0xFF767680);

  // ── Priority colors（红/橙/蓝/无）──

  /// High priority — refined rose.
  static const Color colorPriorityHigh = Color(0xFFE11D48);

  /// Medium priority — warm amber.
  static const Color colorPriorityMedium = Color(0xFFD97706);

  /// Low priority — seed indigo.
  static const Color colorPriorityLow = Color(0xFF4F46E5);

  // ── Border Radius ──

  /// Card / surface radius (refined modern 12dp).
  static const double radiusCard = 12;

  /// Button radius.
  static const double radiusButton = 12;

  /// Chip / tag badge radius.
  static const double radiusChip = 6;

  /// Dialog / bottom sheet radius.
  static const double radiusDialog = 16;

  /// List row radius.
  static const double radiusList = 8;

  /// Checkbox shape — circle (TickTick/Things-style).
  static const OutlinedBorder checkboxShape = CircleBorder();

  // ── Spacing ──

  static const double spaceXxs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 20;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;
  static const double spaceXxxl = 48;

  // ── Typography ──
  //
  // 七档字阶（docs/66-ui-visual-polish-proposal.md §2）：
  // display / heading / title / body / footnote / caption / micro。
  // 新增 display、footnote、micro 三档收编此前散落的私有字号（10.5–13.5）。

  /// Page hero large title: 28 / w700（今日页大标题等 Things 式头部）。
  static const double textDisplaySize = 28;
  static const FontWeight textDisplayWeight = FontWeight.w700;

  /// Display 级负字距：大字号下收紧排版，获得编辑感。
  static const double textDisplayLetterSpacing = -0.5;

  /// Page heading: 22 / w600.
  static const double textHeadingSize = 22;
  static const FontWeight textHeadingWeight = FontWeight.w600;

  /// Section title: 18 / w600.
  static const double textTitleSize = 18;
  static const FontWeight textTitleWeight = FontWeight.w600;

  /// Body: 15 / w400.
  static const double textBodySize = 15;
  static const FontWeight textBodyWeight = FontWeight.w400;

  /// Footnote: 13 / w400（正文与说明之间的辅助说明层，如抽屉组头说明）。
  static const double textFootnoteSize = 13;
  static const FontWeight textFootnoteWeight = FontWeight.w400;

  /// Caption / metadata: 12 / w400.
  static const double textCaptionSize = 12;
  static const FontWeight textCaptionWeight = FontWeight.w400;

  /// Micro: 11 / w500（徽章/计数等非关键元信息专用；正文类文案仍须 ≥ caption，
  /// 保 NFR-06 对比度底线）。
  static const double textMicroSize = 11;
  static const FontWeight textMicroWeight = FontWeight.w500;

  // 行高（倍数）：display 紧凑有力，正文宽松以获得呼吸感。
  static const double textDisplayHeight = 1.2;
  static const double textBodyHeight = 1.45;
  static const double textCaptionHeight = 1.35;

  /// 表格数字（tabular figures）：日期、计数、进度等数字纵向对齐用，
  /// 配 `TextStyle(fontFeatures: AppTokens.fontTabular)` 使用。
  static const List<FontFeature> fontTabular = [FontFeature.tabularFigures()];

  // ── Motion ──

  /// Spring curve for list items, cards.
  static const Curve motionSpring = Curves.easeOutCubic;

  /// Micro-interactions.
  static const Duration motionFast = Duration(milliseconds: 150);

  /// Page transitions.
  static const Duration motionNormal = Duration(milliseconds: 250);

  /// Overlay / sheet animations.
  static const Duration motionSlow = Duration(milliseconds: 350);

  /// Staggered list entrance delay per item.
  static const Duration motionStaggerDelay = Duration(milliseconds: 50);

  /// 列表错落入场上限：超过该数量的列表不再错落（长列表直接平铺，
  /// 控制总错落时长 ≤ 15×50ms + 250ms ≈ 1s，docs/63-motion-polish.md §5 B）。
  static const int motionMaxStaggerItems = 15;

  /// 列表错落入场上移距离（fade + slide-up，docs/63-motion-polish.md §5 B）。
  static const double motionStaggerSlideOffset = 8;

  /// 勾选弹性幅度：勾选时勾选框 scale 1 → [checkboxBounceScale] → 1
  /// （docs/63-motion-polish.md §5 A）。
  static const double checkboxBounceScale = 1.15;

  /// 取消勾选弹性幅度：scale 1 → [checkboxBounceShrink] → 1（同曲线反向）。
  static const double checkboxBounceShrink = 0.85;

  /// 卡片按压轻微缩放（project_card / 任务卡片，docs/63-motion-polish.md §5 H）。
  static const double cardPressScale = 0.98;

  /// 任务列表按压缩放（des-4 需求 2：0.98 → 0.995，用户评审 2026-08 再减：
  /// 0.995 → 0.998——此前一级卡片「卡片包裹层 + 行内层」双层缩放叠加
  /// ≈0.990 体感明显；现卡片层单层承担、行级仅剩 compact 子行，取 0.998
  /// 几乎无感。项目卡片仍用 [cardPressScale]）。
  static const double cardPressScaleSubtle = 0.998;

  /// FAB 按压缩放（docs/63-motion-polish.md §5 I：按压回弹）。
  static const double fabPressScale = 0.9;

  // ── Elevation & Ambient Shadows ──

  /// 卡片静止 elevation（浮层/弹层用；普通卡片一律走「细边框 + 弥散阴影」，
  /// 不用 Material elevation，66 §4）。
  static const double elevationCard = 1.0;

  /// Diffused ambient dual-shadow for light cards (resting).
  static const List<BoxShadow> cardShadowLight = [
    BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Diffused ambient dual-shadow for light cards (hovered/elevated).
  static const List<BoxShadow> cardShadowLightHover = [
    BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x10000000), blurRadius: 20, offset: Offset(0, 6)),
  ];

  /// Ambient shadow for dark cards (resting).
  static const List<BoxShadow> cardShadowDarkList = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Ambient shadow for dark cards (hovered/elevated).
  static const List<BoxShadow> cardShadowDarkHoverList = [
    BoxShadow(color: Color(0x2A000000), blurRadius: 6, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// FAB elevation.
  static const double elevationFab = 4;

  // ── Progress Ring（仅令牌，批 2 使用 UI）──

  /// Circular progress ring diameter for parent tasks
  /// （用户打磨要求 1：24 → 18，行尾更轻量）。
  static const double progressRingSize = 18;

  /// Circular progress ring stroke width（用户打磨要求 1：2.5 → 2）。
  static const double progressRingWidth = 2;

  /// 进度百分比字号（用户打磨要求 1：bodySmall 12 → 10，整体小一号）。
  static const double progressPercentSize = 10;

  // ── Drawer（仅令牌，批 2 使用 UI）──

  /// Mobile drawer width as a fraction of screen width (TickTick: 75–80%).
  static const double drawerWidthRatio = 0.78;
  // 批 2：drawerSelectedBg 由 colorScheme.primaryContainer 派生（55-ui-redesign §5），
  // 不在静态令牌中放派生色。

  /// Wide-screen persistent sidebar width (TickTick/Todoist desktop standard: 260dp).
  static const double sidebarWidth = 260;

  /// 宽屏日历页左栏（沉浸式视口）宽度（0ede52e 定稿 400）。
  static const double calendarPaneWidth = 400;

  /// Wide-screen NavigationRail width（80 → 96，55-ui-redesign-proposal.md §3.2）。
  static const double railWidth = 96;

  // ── Dialog & Side Sheet ──

  /// Standard form dialog maximum width (440dp).
  static const double dialogMaxWidth = 440;

  /// Standard modal side sheet width (settings, etc.: 480dp).
  static const double sideSheetWidth = 480;

  /// Wide modal side sheet width (task edit, custom view editor: 520dp).
  static const double sideSheetEditorWidth = 520;

  // ── Sizing ──

  /// Minimum touch target (accessibility).
  static const double touchTarget = 48;

  /// Checkbox touch area size.
  static const double checkboxSize = 24;

  /// 任务行勾选框触控区尺寸（用户打磨要求 4，override 61 §3.2 行高规格 +
  /// NFR-06 ≥48dp 触控下限的权衡）：视觉 [checkboxSize]=24，触控区取 44
  /// ——单行任务行高由触控区决定，44 处「48 硬约束」与「行高明显更窄」
  /// （用户期望 36-48）的折中，用户明确接受 44-48 区间取舍；
  /// 行点击（onTap → 编辑页）由整行 InkWell 兜底。
  static const double checkboxTapTargetSize = 44;

  /// Expand/collapse arrow size.
  static const double expandArrowSize = 20;

  /// Task tree indent per depth level.
  static const double treeIndent = 28;

  /// Empty state icon size.
  static const double emptyIconSize = 56;

  /// Empty state v2 背衬圆直径（主色调淡染，66 §4）。
  static const double emptyBackdropSize = 72;

  /// Empty state v2 背衬圆内图标尺寸。
  static const double emptyBackdropIconSize = 32;

  // ── Menu（弹出/下拉菜单统一规格）──

  /// 弹出菜单项高度（M3 默认 48 的紧凑化；50-ui-ux §2.6 菜单规格）。
  static const double menuItemHeight = 40;

  /// 菜单项图标尺寸（统一各调用点 16/18/20 混用）。
  static const double menuItemIconSize = 18;

  /// 弹出菜单容器最小宽度（默认 minWidth 112 略收紧；各调用点不再局部覆盖）。
  static const double menuMinWidth = 120;

  // ── 任务列表扁平行（61-task-list-redesign.md §4/§7）──

  /// 任务树每级缩进量（61 §4.3，替代 [treeIndent]=28 用于扁平行子任务缩进；
  /// 用户打磨要求 2：24 → 20 适度收紧）。
  static const double treeIndentLevel = 20;

  /// 行尾展开/折叠箭头尺寸（61 §4.5，比 AppBar/树内 [expandArrowSize] 20 稍小）。
  static const double expandArrowSizeRow = 16;

  /// 行尾展开/折叠控件最小触控区域（评审修复 2：改造前固定 28×28，
  /// 改造后箭头随内容尺寸收缩到约 16px；恢复触控目标并尽量接近 NFR-06
  /// ≥48dp 的硬约束，行内空间有限取 32）。
  static const double expandTapTargetSize = 32;

  /// 相对时间文字颜色（「距开始 X 天」，61 §4.4，与 colorPriorityMedium 同值）。
  static const Color colorDateRelative = Color(0xFFF4A74A);

  /// 任务行最小高度（一级任务行，61 §3.2；用户打磨要求 3：56 → 52，
  /// 勾选框 48dp 触控不变，行高仍由内容撑起可点性下限）。
  static const double taskRowMinHeight = 48;

  /// 任务行最小高度（子任务行，61 §3.2；用户打磨要求 3：48 → 44——实际
  /// 行高由 48dp 勾选框触控区撑起，最小高度下调不影响可点性）。
  static const double taskRowCompactMinHeight = 44;

  /// 已完成任务内容区透明度（降低与背景对比度）：完成态任务行内容区
  /// （标题/描述/标签/日期等）整体淡化，勾选/进度环等交互控件保持全不透明。
  static const double doneContentOpacity = 0.55;

  // ── 抽屉（55-ui-redesign §3.1 / 62-folder-nav.md §6.1，des-1 垂直节奏优化）──

  /// 抽屉行统一垂直间距（系统组 / 文件夹行 / 项目行一致）。
  ///
  /// 每行上下各留 `spacing / 2` 外间距，行间净距 = [drawerRowSpacing]，
  /// 保证整个抽屉的垂直节奏统一（des-1 需求 4）。
  static const double drawerRowSpacing = 4;

  // ── 抽屉文件夹树（62-folder-nav.md §6.1；des-2 连线方案经用户评审废弃，
  //    仅保留缩进与行距令牌）──

  /// 树状区缩进量（与父级文件夹正文文字起始线严格纵向对齐）。
  static const double folderTreeIndent = 26;

  /// 树状连线区内项目行的垂直间距（比全局 [drawerRowSpacing] 更紧凑，
  /// 每行上下各留 `spacing / 2`，des-2 需求 2b）。
  static const double folderTreeRowSpacing = 2;

  /// 抽屉/项目页分组小标题图标尺寸（62-folder-nav.md §6.1/§6.4）。
  static const double folderHeaderIconSize = 16;

  // ── 状态反馈（M5 任务 1，50-ui-ux.md §6.3）──

  /// 统一加载指示器尺寸（LoadingView）。
  static const double loadingIndicatorSize = 32;

  /// 紧凑加载指示器尺寸（列表行内/抽屉内联加载）。
  static const double loadingIndicatorSizeCompact = 20;

  /// 加载指示器描边宽度。
  static const double loadingStrokeWidth = 3;

  /// 错误态图标尺寸（ErrorView）。
  static const double errorIconSize = 56;

  /// 错误态紧凑图标尺寸（列表行内联错误，如抽屉项目组）。
  static const double errorIconSizeCompact = 20;

  // ── Preset Colors (project palette) ──

  /// Refined palette for project colors (Tailwind/Radix inspired).
  static const List<Color> presetColors = [
    Color(0xFF4F46E5), // indigo
    Color(0xFF059669), // emerald
    Color(0xFFD97706), // warm amber
    Color(0xFFE11D48), // rose
    Color(0xFF8B5CF6), // violet
    Color(0xFF0284C7), // sky
    Color(0xFFDB2777), // pink
    Color(0xFF6B7280), // slate
  ];
}
