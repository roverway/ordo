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

  /// Light theme background tint — very subtle blue-gray.
  static const Color bgTint = Color(0xFFF2F4F7);

  /// Dark theme background tint.
  static const Color bgTintDark = Color(0xFF0F1117);

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

  /// Checkbox radius.
  static const double radiusCheckbox = 6;

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

  /// Card shadow elevation.
  static const double elevationCard = 0.5;

  /// FAB elevation.
  static const double elevationFab = 4;

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
