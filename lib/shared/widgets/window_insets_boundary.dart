import 'package:flutter/material.dart';

/// 响应式视口 Insets 隔离边界组件（Standardized WindowInsets Boundary）。
///
/// 核心作用：
/// 在不订阅全局 `MediaQuery.of(context)` 的前提下（避免键盘升降 60~120fps 高频脏标记传播），
/// 通过细粒度 Aspect 读取环境尺寸与安全区，并将 `viewInsets` 重置为 [insets]（默认 [EdgeInsets.zero]）。
///
/// 这样能够彻底隔绝软键盘动画引发的父级与子组件全量 Rebuild / Relayout，
/// 同时完整保留 TextScaler、Brightness、Padding、GestureSettings 等所有无障碍与系统配置。
class WindowInsetsBoundary extends StatelessWidget {
  const WindowInsetsBoundary({
    super.key,
    required this.child,
    this.insets = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context) {
    // 关键优化：使用细粒度 Aspect 读取尺寸与安全区，不调用 MediaQuery.of(context)！
    // 使得本组件在原生 WindowInsets（键盘高度）突变时完全不订阅 viewInsets，0 次 Rebuild。
    final mediaQueryData = MediaQueryData(
      size: MediaQuery.sizeOf(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      textScaler: MediaQuery.textScalerOf(context),
      platformBrightness: MediaQuery.platformBrightnessOf(context),
      padding: MediaQuery.paddingOf(context),
      viewPadding: MediaQuery.viewPaddingOf(context),
      viewInsets: insets,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      highContrast: MediaQuery.highContrastOf(context),
      boldText: MediaQuery.boldTextOf(context),
      invertColors: MediaQuery.invertColorsOf(context),
      accessibleNavigation: MediaQuery.accessibleNavigationOf(context),
      gestureSettings: MediaQuery.gestureSettingsOf(context),
      displayFeatures: MediaQuery.displayFeaturesOf(context),
    );

    return MediaQuery(data: mediaQueryData, child: child);
  }
}
