import 'package:flutter/material.dart';

/// Design Tokens — the single source of truth for all visual values.
///
/// Inspired by TickTick's restrained palette + Microsoft To Do's task-first
/// minimalism. Soft blues, generous whitespace, gentle rounded corners.
///
/// All UI code must reference these tokens; no magic values (AGENTS.md §3-9).
abstract final class AppTokens {
  // ── Color ──

  /// Seed color: clean, modern blue (TickTick-inspired).
  static const Color seedColor = Color(0xFF4A6CF7);

  /// Done — soft sage green.
  static const Color colorDone = Color(0xFF5CAB7D);

  /// In Progress — match seed blue.
  static const Color colorInProgress = Color(0xFF4A6CF7);

  /// Cancelled — neutral gray.
  static const Color colorCancelled = Color(0xFF9CA3AF);

  /// Overdue — gentle red (not harsh).
  static const Color colorOverdue = Color(0xFFEF6B6B);

  /// Inbox project accent — warm violet.
  /// 与 todo_repository.dart 的 inboxProjectColor 保持一致（DB 实际写入值）。
  static const Color colorInbox = Color(0xFF6C5CE7);

  /// Page surface (light) — very subtle blue-gray, cards float on top.
  /// (55-ui-redesign-proposal.md §5 `surfacePage`)
  static const Color surfacePageLight = Color(0xFFF2F4F7);

  /// Page surface (dark).
  static const Color surfacePageDark = Color(0xFF0F1117);

  /// Card surface (light) — pure white（滴答式「白卡」，55-ui-redesign §5）。
  static const Color surfaceCard = Color(0xFFFFFFFF);

  /// Card surface (dark) — slightly lifted from the near-black page base.
  static const Color surfaceCardDark = Color(0xFF1B1E27);

  /// Checkmark glyph on the filled (done) circular checkbox.
  static const Color colorOnCheck = Colors.white;

  /// Done checkbox fill — TickTick blue（完成 = 蓝填充白勾，55-ui-redesign §5）。
  static const Color checkboxDoneFill = colorInProgress;

  // ── Priority colors（滴答式旗帜 红/橙/蓝/无，55-ui-redesign §4.1）──

  /// High priority — red（与 presetColors[3] 同值）。
  static const Color colorPriorityHigh = Color(0xFFEF6B6B);

  /// Medium priority — warm amber（与 presetColors[2] 同值）。
  static const Color colorPriorityMedium = Color(0xFFF4A74A);

  /// Low priority — seed blue（与 presetColors[0] 同值）。
  static const Color colorPriorityLow = Color(0xFF4A6CF7);

  // ── Border Radius ──

  /// Card / surface radius.
  static const double radiusCard = 16;

  /// Button radius.
  static const double radiusButton = 14;

  /// Chip / tag radius.
  static const double radiusChip = 10;

  /// Dialog / bottom sheet radius.
  static const double radiusDialog = 20;

  /// List row radius.
  static const double radiusList = 10;

  /// Checkbox shape — circle (TickTick-style). Radius-based square shape
  /// (`radiusCheckbox`) removed in favour of this circular shape.
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

  /// Page heading: 22 / w600.
  static const double textHeadingSize = 22;
  static const FontWeight textHeadingWeight = FontWeight.w600;

  /// Section title: 18 / w600.
  static const double textTitleSize = 18;
  static const FontWeight textTitleWeight = FontWeight.w600;

  /// Body: 15 / w400.
  static const double textBodySize = 15;
  static const FontWeight textBodyWeight = FontWeight.w400;

  /// Caption / metadata: 12 / w400.
  static const double textCaptionSize = 12;
  static const FontWeight textCaptionWeight = FontWeight.w400;

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

  // ── Elevation / Shadow ──

  /// Card shadow elevation (resting).
  static const double elevationCard = 1.0;

  /// Card shadow elevation while hovered/pressed (subtle lift).
  static const double elevationCardHover = 2.0;

  /// Card shadow tint (light, resting) — soft black ~8%.
  static const Color shadowCard = Color(0x14000000);

  /// Card shadow tint (light, hover/press lift) — deeper black ~16%.
  static const Color shadowCardElevated = Color(0x2A000000);

  /// Card shadow tint (dark, resting) — faint white rim so cards lift off
  /// the near-black page base.
  static const Color shadowCardDark = Color(0x0AFFFFFF);

  /// Card shadow tint (dark, hover/press lift).
  static const Color shadowCardDarkElevated = Color(0x1CFFFFFF);

  /// Card shadow blur radius (resting).
  static const double shadowBlurRest = 6;

  /// Card shadow blur radius (hover/press lift).
  static const double shadowBlurElevated = 12;

  /// Card shadow vertical offset (resting).
  static const double shadowOffsetY = 1;

  /// Card shadow vertical offset (hover/press lift).
  static const double shadowOffsetYElevated = 3;

  /// FAB elevation.
  static const double elevationFab = 4;

  // ── Progress Ring（仅令牌，批 2 使用 UI）──

  /// Circular progress ring diameter for parent tasks.
  static const double progressRingSize = 24;

  /// Circular progress ring stroke width.
  static const double progressRingWidth = 2.5;

  // ── Drawer（仅令牌，批 2 使用 UI）──

  /// Mobile drawer width as a fraction of screen width (TickTick: 75–80%).
  static const double drawerWidthRatio = 0.78;
  // 批 2：drawerSelectedBg 由 colorScheme.primaryContainer 派生（55-ui-redesign §5），
  // 不在静态令牌中放派生色。

  /// Wide-screen NavigationRail width（80 → 96，55-ui-redesign-proposal.md §3.2）。
  static const double railWidth = 96;

  // ── Sizing ──

  /// Minimum touch target (accessibility).
  static const double touchTarget = 48;

  /// Checkbox touch area size.
  static const double checkboxSize = 24;

  /// Expand/collapse arrow size.
  static const double expandArrowSize = 20;

  /// Task tree indent per depth level.
  static const double treeIndent = 28;

  /// Empty state icon size.
  static const double emptyIconSize = 56;

  // ── Preset Colors (project palette) ──

  /// TickTick-inspired soft palette for project colors.
  static const List<Color> presetColors = [
    Color(0xFF4A6CF7), // blue
    Color(0xFF5CAB7D), // sage
    Color(0xFFF4A74A), // warm amber
    Color(0xFFEF6B6B), // coral
    Color(0xFF8B5CF6), // violet
    Color(0xFF3BA5D9), // sky
    Color(0xFFEC6B8F), // rose
    Color(0xFF6B7280), // slate
  ];
}
