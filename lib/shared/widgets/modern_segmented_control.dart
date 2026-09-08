import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 选项项定义
class ModernSegmentItem<T> {
  const ModernSegmentItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// 现代极简风格分段选择控件（对齐 settings.html 中的 .seg / .lang-seg 胶囊分段设计）。
///
/// 特性：
/// - 浅色胶囊底槽（`colorScheme.onSurface` 极低透明度）
/// - 选中项为卡片高亮浮层（带微投影与高对比度字色）
/// - 支持图标 + 文字水平排布
/// - 支持平滑过渡动画与触控反馈
class ModernSegmentedControl<T> extends StatelessWidget {
  const ModernSegmentedControl({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.height = 34,
    this.fontSize = 13,
    this.padding = const EdgeInsets.all(3),
    this.itemPadding,
    this.isExpanded = true,
  });

  final List<ModernSegmentItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? itemPadding;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final containerBg = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.08)
        : colorScheme.onSurface.withValues(alpha: 0.06);

    final widgetList = items.map((item) {
      final isSelected = item.value == selectedValue;

      Widget buttonContent = AnimatedContainer(
        duration: AppTokens.motionFast,
        curve: AppTokens.motionSpring,
        height: height,
        padding:
            itemPadding ??
            EdgeInsets.symmetric(horizontal: isExpanded ? 8 : 14),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 15,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              item.label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

      final clickableItem = InkWell(
        onTap: () => onChanged(item.value),
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.transparent,
        highlightColor: colorScheme.onSurface.withValues(alpha: 0.04),
        child: buttonContent,
      );

      if (isExpanded) {
        return Expanded(child: clickableItem);
      }
      return clickableItem;
    }).toList();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: isExpanded
          ? Row(mainAxisSize: MainAxisSize.max, children: widgetList)
          : Row(mainAxisSize: MainAxisSize.min, children: widgetList),
    );
  }
}
