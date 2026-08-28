import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/motion.dart';

/// 动态文字划线组件（Linear / Things 3 风格任务完成仪式感）。
///
/// 当 [isDone] 由 false 变为 true 时：
/// 1. 触发平滑删除线动画（从左至右平滑延展，[motionNormal] 时长；多行文本
///    逐行划线，按累计行宽顺序扫过）；
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
              text: widget.text,
              style: effectiveStyle,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: widget.maxLines,
              overflow: widget.overflow,
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
    required this.text,
    required this.style,
    required this.textDirection,
    required this.textScaler,
    required this.maxLines,
    required this.overflow,
  });

  final double progress;
  final Color color;
  final double lineWidth;

  /// 文本布局参数：与内部 [Text] 完全一致，painter 用 [TextPainter] 复算
  /// 行度量，实现多行逐行划线（单行时退化为整行一条线）。
  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: maxLines,
      // TextPainter 无 overflow 参数；单行截断（ellipsis）经 ellipsis 复现，
      // 与内部 Text 的排版宽度一致。maxLines 为 null（折行）时无截断。
      ellipsis: maxLines != null && overflow == TextOverflow.ellipsis
          ? '\u2026'
          : null,
    )..layout(maxWidth: size.width);
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 各行行高一致（同一 style），行 i 的划线 y = 行顶 + 52% 行高；
    // 划线进度按累计行宽从首行向末行顺序推进（单行与旧实现完全一致）。
    final lineHeight = size.height / metrics.length;
    final totalWidth = metrics.fold<double>(0, (sum, m) => sum + m.width);
    var consumedWidth = 0.0;
    for (var i = 0; i < metrics.length; i++) {
      final metric = metrics[i];
      final y = i * lineHeight + lineHeight * 0.52;
      final lineFraction = metric.width / totalWidth;
      final drawn = ((progress - consumedWidth) / lineFraction).clamp(0.0, 1.0);
      consumedWidth += lineFraction;
      if (drawn <= 0) break;

      final start = metric.left;
      final end = textDirection == TextDirection.rtl
          ? start - metric.width * drawn
          : start + metric.width * drawn;
      canvas.drawLine(Offset(start, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrikethroughPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.text != text ||
        oldDelegate.style != style ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.maxLines != maxLines ||
        oldDelegate.overflow != overflow;
  }
}
