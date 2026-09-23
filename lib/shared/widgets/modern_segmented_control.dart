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

/// 现代极简风格分段选择控件（带平滑滑动滑块动画与触控反馈）。
///
/// 特性：
/// - 胶囊底槽（可自定义背景色、边框、圆角）
/// - 点击时滑块底色物理滑动过渡（[AppTokens.motionNormal] + [AppTokens.motionSpring]）
/// - 严格零纵向偏置：滑块在垂直方向严格居中贴合，杜绝任何额外内部上边距与向下偏移
/// - 自适应等宽展开（[isExpanded] = true）或内容包裹（[isExpanded] = false）
/// - 支持图标与文字混排、语义化与无障碍聚焦
class ModernSegmentedControl<T> extends StatefulWidget {
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
    this.backgroundColor,
    this.indicatorColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.borderRadius,
    this.indicatorRadius,
    this.border,
    this.indicatorShadow,
  });

  final List<ModernSegmentItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? itemPadding;
  final bool isExpanded;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final BorderRadius? borderRadius;
  final BorderRadius? indicatorRadius;
  final BoxBorder? border;
  final List<BoxShadow>? indicatorShadow;

  @override
  State<ModernSegmentedControl<T>> createState() =>
      _ModernSegmentedControlState<T>();
}

class _ModernSegmentedControlState<T> extends State<ModernSegmentedControl<T>> {
  final GlobalKey _stackKey = GlobalKey();
  final Map<T, GlobalKey> _itemKeys = {};

  Rect? _indicatorRect;
  bool _animate = false;
  late T _activeValue;

  @override
  void initState() {
    super.initState();
    _activeValue = widget.selectedValue;
    _updateKeys();
    if (!widget.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateIndicator(animate: false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ModernSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateKeys();
    if (widget.selectedValue != oldWidget.selectedValue ||
        widget.items.length != oldWidget.items.length) {
      _activeValue = widget.selectedValue;
      _animate = true;
      if (!widget.isExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateIndicator(animate: true);
        });
      }
    }
  }

  void _updateKeys() {
    for (final item in widget.items) {
      _itemKeys.putIfAbsent(item.value, () => GlobalKey());
    }
  }

  void _updateIndicator({required bool animate}) {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final targetKey = _itemKeys[_activeValue];
    final targetBox =
        targetKey?.currentContext?.findRenderObject() as RenderBox?;

    if (stackBox != null &&
        targetBox != null &&
        stackBox.hasSize &&
        targetBox.hasSize) {
      final offset = targetBox.localToGlobal(Offset.zero, ancestor: stackBox);
      final newRect = Rect.fromLTWH(
        offset.dx,
        0.0,
        targetBox.size.width,
        widget.height,
      );
      if (_indicatorRect != newRect) {
        setState(() {
          _indicatorRect = newRect;
          _animate = animate;
        });
      }
    }
  }

  void _onItemTapped(T value) {
    if (value == _activeValue) return;

    if (widget.isExpanded) {
      setState(() {
        _activeValue = value;
        _animate = true;
      });
    } else {
      final stackBox =
          _stackKey.currentContext?.findRenderObject() as RenderBox?;
      final itemKey = _itemKeys[value];
      final itemBox = itemKey?.currentContext?.findRenderObject() as RenderBox?;

      setState(() {
        _activeValue = value;
        _animate = true;
        if (stackBox != null &&
            itemBox != null &&
            stackBox.hasSize &&
            itemBox.hasSize) {
          final offset = itemBox.localToGlobal(Offset.zero, ancestor: stackBox);
          _indicatorRect = Rect.fromLTWH(
            offset.dx,
            0.0,
            itemBox.size.width,
            widget.height,
          );
        }
      });
    }

    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final containerBg =
        widget.backgroundColor ??
        colorScheme.onSurface.withValues(alpha: AppTokens.alphaTintFaint);

    final indicatorColor = widget.indicatorColor ?? colorScheme.surface;
    final selectedColor = widget.selectedTextColor ?? colorScheme.primary;
    final unselectedColor =
        widget.unselectedTextColor ?? colorScheme.onSurfaceVariant;
    final borderRadius =
        widget.borderRadius ?? BorderRadius.circular(AppTokens.radiusItem);
    final indicatorRadius =
        widget.indicatorRadius ?? BorderRadius.circular(AppTokens.radiusList);

    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: borderRadius,
        border: widget.border,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!widget.isExpanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateIndicator(animate: false);
            });
          }

          Rect? activeRect;
          if (widget.isExpanded) {
            final availableWidth = constraints.maxWidth;
            final itemWidth = widget.items.isEmpty
                ? 0.0
                : availableWidth / widget.items.length;
            final activeIndex = widget.items.indexWhere(
              (it) => it.value == _activeValue,
            );
            if (activeIndex >= 0) {
              activeRect = Rect.fromLTWH(
                activeIndex * itemWidth,
                0.0,
                itemWidth,
                widget.height,
              );
            }
          } else {
            activeRect = _indicatorRect;
          }

          final itemsWidgets = widget.items.map((item) {
            final isSelected = item.value == _activeValue;

            Widget buttonContent = Container(
              key: widget.isExpanded ? null : _itemKeys[item.value],
              height: widget.height,
              padding:
                  widget.itemPadding ??
                  EdgeInsets.symmetric(horizontal: widget.isExpanded ? 8 : 14),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: widget.isExpanded
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 15,
                      color: isSelected ? selectedColor : unselectedColor,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected ? selectedColor : unselectedColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );

            final clickableItem = Semantics(
              selected: isSelected,
              button: true,
              label: item.label,
              child: InkWell(
                onTap: () => _onItemTapped(item.value),
                borderRadius: indicatorRadius,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: buttonContent,
              ),
            );

            if (widget.isExpanded) {
              return Expanded(child: clickableItem);
            }
            return clickableItem;
          }).toList();

          return Stack(
            key: _stackKey,
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // 滑动滑块指示器
              if (activeRect != null)
                AnimatedPositioned(
                  duration: _animate ? AppTokens.motionNormal : Duration.zero,
                  curve: AppTokens.motionSpring,
                  left: activeRect.left,
                  top: 0.0,
                  width: activeRect.width,
                  height: widget.height,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        borderRadius: indicatorRadius,
                        boxShadow:
                            widget.indicatorShadow ??
                            [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark
                                      ? AppTokens.alphaTintStrong
                                      : AppTokens.alphaBorderSubtle,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                      ),
                    ),
                  ),
                ),
              // 选项行
              widget.isExpanded
                  ? Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: itemsWidgets,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: itemsWidgets,
                    ),
            ],
          );
        },
      ),
    );
  }
}
