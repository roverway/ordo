import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/motion.dart';

/// 勾选弹性（docs/63-motion-polish.md §5 A；M7 抽取的共享组件，
/// task_row / simple_task_tile 共用）。
///
/// 完成态（[isDone]）变化时对 child（通常是勾选框）做一次 scale 脉冲：
/// - 勾选 `1 → [AppTokens.checkboxBounceScale] → 1`；
/// - 取消完成 `1 → [AppTokens.checkboxBounceShrink] → 1`；
/// 用 TweenSequence 关键帧（段内曲线 [motionBounceCurve]，时长 [motionFast]），
/// `didUpdateWidget` 中 [isDone] 变化时 `forward(from: 0)` 触发；
/// 首帧不播放（避免进列表就弹一下）。
///
/// reduced motion：时长归零 → 瞬时到位（不缩放）。
class CheckboxBounce extends StatefulWidget {
  const CheckboxBounce({super.key, required this.isDone, required this.child});

  final bool isDone;
  final Widget child;

  @override
  State<CheckboxBounce> createState() => _CheckboxBounceState();
}

class _CheckboxBounceState extends State<CheckboxBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 1.0).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _controller.duration = motionFast(context);
    // 首帧不播放（避免进列表就弹一下）。
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant CheckboxBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDone == widget.isDone) return;
    if (_controller.duration == Duration.zero) {
      // reduced：瞬时到位。
      _controller.value = 1.0;
      return;
    }
    final bounce = motionBounceCurve(context);
    if (widget.isDone) {
      // 触觉反馈
      HapticFeedback.lightImpact();
      // 勾选：放大回弹。
      _scale = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: AppTokens.checkboxBounceScale,
          ).chain(CurveTween(curve: bounce)),
          weight: 55,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: AppTokens.checkboxBounceScale,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 45,
        ),
      ]).animate(_controller);
    } else {
      // 取消完成：缩小回弹。
      _scale = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: AppTokens.checkboxBounceShrink,
          ).chain(CurveTween(curve: bounce)),
          weight: 55,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: AppTokens.checkboxBounceShrink,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 45,
        ),
      ]).animate(_controller);
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
