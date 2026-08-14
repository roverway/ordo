import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// 应用动效统一入口（docs/63-motion-polish.md）。
///
/// 所有自定义动画（勾选弹性/错落入场/树展开/转场/进度环等）必须经本工具
/// 选取时长与曲线，禁止散落魔法值（AGENTS.md §3-9）：
/// - 常规场景：时长/曲线取自 [AppTokens.motion*] 令牌；
/// - **reduced motion（NFR-06）**：系统开启「减弱动态效果」时（
///   `MediaQuery.disableAnimations`，跟随系统设置）自动降级——位移/缩放类
///   动画退化为纯淡入或瞬时切换，避免诱发前庭不适。
///
/// 注意：[BuildContext] 依赖的方法需在能访问 MediaQuery 的 build 上下文中调用；
/// 无 context 的场景（如顶层常量曲线）直接用 [AppTokens] 令牌。

/// 系统是否开启「减弱动态效果」（reduced motion）。
///
/// 跟随 `MediaQuery.disableAnimations`；测试中可经
/// `tester.platformDispatcher.accessibilityFeaturesTestValue` 注入。
bool isReducedMotion(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  return media?.disableAnimations ?? false;
}

/// 常规动画时长；reduced motion 时降级为 [Duration.zero]（瞬时）。
Duration motionDuration(BuildContext context, Duration full) {
  return isReducedMotion(context) ? Duration.zero : full;
}

/// 常规动画时长（[AppTokens.motionNormal]，页面转场/树展开等中等动效）。
Duration motionNormal(BuildContext context) =>
    motionDuration(context, AppTokens.motionNormal);

/// 快速动画时长（[AppTokens.motionFast]，微交互/勾选等）。
Duration motionFast(BuildContext context) =>
    motionDuration(context, AppTokens.motionFast);

/// 慢速动画时长（[AppTokens.motionSlow]，弹层/底部弹窗等）。
Duration motionSlow(BuildContext context) =>
    motionDuration(context, AppTokens.motionSlow);

/// 位移/缩放类动画曲线（克制轻盈，滴答风格）；reduced motion 时退化为
/// 纯淡入曲线（位移/缩放归零由调用方配合 [durationFor] == 0 处理）。
Curve motionCurve(BuildContext context) {
  return isReducedMotion(context) ? Curves.easeOut : AppTokens.motionSpring;
}

/// 弹性回弹曲线（勾选/按压等微交互）；reduced motion 时退化为 [Curves.easeOut]。
Curve motionBounceCurve(BuildContext context) {
  return isReducedMotion(context) ? Curves.easeOut : Curves.easeOutBack;
}

/// 淡入曲线（reduced motion 时也安全——纯透明度变化无位移）。
const Curve motionFadeCurve = Curves.easeOut;
