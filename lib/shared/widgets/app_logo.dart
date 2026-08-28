import 'package:flutter/material.dart';

/// 应用品牌 Logo 图标组件。
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 28,
    this.borderRadius,
    this.useDarkVariant = false,
  });

  /// Logo 尺寸（宽高相同）。
  final double size;

  /// 圆角半径，缺省按尺寸等比计算。
  final double? borderRadius;

  /// 是否强制使用暗色霓光变体。
  final bool useDarkVariant;

  @override
  Widget build(BuildContext context) {
    final isDark =
        useDarkVariant || Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? (size * 0.22);
    final assetPath = isDark
        ? 'assets/images/app_logo_dark.png'
        : 'assets/images/app_logo.png';

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
