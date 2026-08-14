import 'package:flutter/widgets.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/motion.dart';

/// 列表逐项错落入场（docs/63-motion-polish.md §5 B，共享组件）。
///
/// 用法：列表每一项外包一层，`index` 传该项在列表中的位置（0-based）：
///
/// ```dart
/// ListView(
///   children: [
///     for (var i = 0; i < items.length; i++)
///       StaggeredFadeSlide(index: i, child: _MyRow(item: items[i])),
///   ],
/// )
/// ```
///
/// 行为约定：
/// - **首帧逐项入场**：fade + slide-up [AppTokens.motionStaggerSlideOffset]px，
///   间隔 [AppTokens.motionStaggerDelay]，可视动画段总时长 [AppTokens.motionNormal]，
///   曲线 [motionCurve]；
/// - **仅首次 build 播放一次**：数据刷新/排序变更导致的列表重建不会重放
///   （内部 [AnimationController] 播放一次后保持终值；如需重播，用新的 key
///   重建本组件即可）；
/// - **reduced motion**：经 [motionNormal]（reduced → 零时长）瞬时到位，
///   纯淡入语义（无位移残留）；
/// - **长列表保护**：`index >= [maxStaggerItems]` 时直接平铺不包动画，
///   控制总错落时长上限（默认 [AppTokens.motionMaxStaggerItems]）。
class StaggeredFadeSlide extends StatefulWidget {
  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.maxStaggerItems = AppTokens.motionMaxStaggerItems,
  });

  /// 该项在列表中的位置（0-based），决定延迟：`index × staggerDelay`。
  final int index;

  /// 列表项内容。
  final Widget child;

  /// 超过该数量后不再错落（长列表性能保护）。
  final int maxStaggerItems;

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _opacity = Tween<double>(begin: 0, end: 1).animate(_controller);
    _offset = Tween<Offset>(
      begin: Offset(0, AppTokens.motionStaggerSlideOffset),
      end: Offset.zero,
    ).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // reduced motion：motionNormal 归零 → 瞬时到位（不再播放动画）。
    final normal = motionNormal(context);
    final delay = Duration(
      milliseconds: widget.index * AppTokens.motionStaggerDelay.inMilliseconds,
    );
    final total = normal + delay;
    if (total == Duration.zero) {
      _controller.value = 1.0;
      return;
    }

    _controller.duration = total;
    // 用 Interval 把可视动画压缩到最后的 normal 段：延迟段停在初始态
    //（淡出 + 下沉 8px），到点后统一用 motionCurve 入场。
    final beginFraction = delay.inMicroseconds / total.inMicroseconds;
    final animated = CurvedAnimation(
      parent: _controller,
      curve: Interval(beginFraction, 1.0, curve: motionCurve(context)),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(animated);
    _offset = Tween<Offset>(
      begin: Offset(0, AppTokens.motionStaggerSlideOffset),
      end: Offset.zero,
    ).animate(animated);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 长列表保护：超出上限直接平铺（不建动画包装）。
    if (widget.index >= widget.maxStaggerItems) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
