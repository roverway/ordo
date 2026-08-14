import 'package:flutter/material.dart';

import '../db/tables.dart';
import 'app_tokens.dart';

/// 优先级旗帜颜色（滴答式 红/橙/蓝/无，55-ui-redesign §4.1）。
///
/// 「无」用中性灰（[AppTokens.colorCancelled]）而非透明——顶部栏旗帜在无优先级时
/// 仍需可见可点（滴答清单为灰色旗帜），避免图标隐形导致入口丢失。
///
/// 位于 theme 层：列表行（shared 层）与编辑器工具栏（features 层）共用，
/// 避免 shared → features 的层反向依赖。
Color priorityColor(TaskPriority priority) => switch (priority) {
  TaskPriority.high => AppTokens.colorPriorityHigh,
  TaskPriority.medium => AppTokens.colorPriorityMedium,
  TaskPriority.low => AppTokens.colorPriorityLow,
  TaskPriority.none => AppTokens.colorCancelled,
};
