import 'package:flutter/material.dart';

/// 设计令牌（Design Tokens）—— 唯一魔法值来源（50-ui-ux.md §2）。
///
/// UI 一律引用本类中的令牌，禁止散落魔法值（AGENTS.md §3-9）。
abstract final class AppTokens {
  // ---- 色彩（50-ui-ux.md §2.1）----
  /// 默认种子色（MIUI 蓝）。
  static const Color seedColor = Color(0xFF3482FF);

  /// 已完成（绿）。
  static const Color colorDone = Color(0xFF4CAF50);

  /// 进行中（蓝）。
  static const Color colorInProgress = Color(0xFF3482FF);

  /// 已取消（灰）。
  static const Color colorCancelled = Color(0xFF9E9E9E);

  /// 逾期（红）。
  static const Color colorOverdue = Color(0xFFF44336);

  // ---- 圆角（50-ui-ux.md §2.2，squircle 风格）----
  /// 卡片圆角。
  static const double radiusCard = 20;

  /// 按钮圆角。
  static const double radiusButton = 16;

  /// 标签/筛选 chip 圆角。
  static const double radiusChip = 12;

  /// 对话框/底部弹层圆角。
  static const double radiusDialog = 24;

  /// 列表行圆角。
  static const double radiusList = 12;

  // ---- 间距（50-ui-ux.md §2.3）----
  static const double spaceXxs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 20;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  // ---- 字体（50-ui-ux.md §2.4）----
  /// 展示文本：28 / w700。
  static const double textDisplaySize = 28;
  static const FontWeight textDisplayWeight = FontWeight.w700;

  /// 标题文本：20 / w600。
  static const double textTitleSize = 20;
  static const FontWeight textTitleWeight = FontWeight.w600;

  /// 正文文本：16 / w400。
  static const double textBodySize = 16;
  static const FontWeight textBodyWeight = FontWeight.w400;

  /// 辅助文本：12 / w400。
  static const double textCaptionSize = 12;
  static const FontWeight textCaptionWeight = FontWeight.w400;

  // ---- 动效（50-ui-ux.md §2.5，Folme 风格弹簧）----
  /// 弹簧曲线（列表项、卡片）。
  static const Curve motionSpring = Curves.easeOutBack;

  /// 微交互时长。
  static const Duration motionFast = Duration(milliseconds: 150);

  /// 页面过渡时长。
  static const Duration motionNormal = Duration(milliseconds: 250);

  /// 弹层时长。
  static const Duration motionSlow = Duration(milliseconds: 350);
}
