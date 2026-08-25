import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/motion.dart';

/// 动态文字划线组件（Linear / Things 3 风格任务完成仪式感）。
///
/// 当 [isDone] 由 false 变为 true 时：
/// 1. 触发平滑删除线动画（从左至右平滑延展，[motionNormal] 时长）；
/// 2. 文本透明度平滑过渡至 [AppTokens.doneContentOpacity]；
/// 3. reduced motion 时瞬时到位。
class AnimatedStrikethrough extends StatefulWidget {
  const AnimatedStrikethrough({
    super.key,
    required this.text,
    required this.isDone,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.lineColor,
    this.lineWidth = 1.5,
  });

  final String text;
  final bool isDone;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final Color? lineColor;
  final double lineWidth;

  @override
  State<AnimatedStrikethrough> createState() => _AnimatedStrikethroughState();
}

class _AnimatedStrikethroughState extends State<AnimatedStrikethrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _controller.duration = motionNormal(context);
    _controller.value = widget.isDone ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant AnimatedStrikethrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDone == widget.isDone) return;

    if (_controller.duration == Duration.zero || isReducedMotion(context)) {
      _controller.value = widget.isDone ? 1.0 : 0.0;
      return;
    }

    if (widget.isDone) {
      _controller.forward(from: 0.0);
    } else {
      _controller.reverse(from: 1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = widget.style ?? theme.textTheme.bodyMedium!;
    final colorScheme = theme.colorScheme;
    final strikeColor =
        widget.lineColor ??
        effectiveStyle.color ??
        colorScheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = 1.0 - (1.0 - AppTokens.doneContentOpacity) * progress;

        return Opacity(
          opacity: opacity.clamp(AppTokens.doneContentOpacity, 1.0),
          child: CustomPaint(
            foregroundPainter: _StrikethroughPainter(
              progress: progress,
              color: strikeColor,
              lineWidth: widget.lineWidth,
            ),
            child: Text(
              widget.text,
              style: effectiveStyle,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
            ),
          ),
        );
      },
    );
  }
}

class _StrikethroughPainter extends CustomPainter {
  const _StrikethroughPainter({
    required this.progress,
    required this.color,
    required this.lineWidth,
  });

  final double progress;
  final Color color;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final y = size.height * 0.52;
    final targetX = size.width * progress.clamp(0.0, 1.0);

    canvas.drawLine(Offset(0, y), Offset(targetX, y), paint);
  }

  @override
  bool shouldRepaint(covariant _StrikethroughPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.lineWidth != lineWidth;
  }
}
