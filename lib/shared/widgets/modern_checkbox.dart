import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'checkbox_bounce.dart';

/// Modern Minimal Checkbox matching prototype (`home.html` / `tasklist.html`).
///
/// - Box: 22x22dp (or 20x20dp for compact), border radius 6dp.
/// - Unchecked: 1.5dp border (onSurface 34% alpha), background surface.
/// - Checked: background onSurface, checkmark drawn with smooth stroke animation.
/// - Integrated with [CheckboxBounce] for spring scale feedback.
class ModernCheckbox extends StatefulWidget {
  const ModernCheckbox({
    super.key,
    required this.checked,
    this.onChanged,
    this.size = 22.0,
    this.borderRadius = 6.0,
    this.fillColor,
    this.tapTargetSize = AppTokens.checkboxTapTargetSize,
    this.semanticLabel,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final double size;
  final double borderRadius;
  final Color? fillColor;
  final double tapTargetSize;
  final String? semanticLabel;

  @override
  State<ModernCheckbox> createState() => _ModernCheckboxState();
}

class _ModernCheckboxState extends State<ModernCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkAnim;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.checked ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(parent: _checkAnim, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant ModernCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checked != widget.checked) {
      if (widget.checked) {
        _checkAnim.forward();
      } else {
        _checkAnim.reverse();
      }
    }
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fgColor = widget.fillColor ?? theme.colorScheme.onSurface;
    final uncheckedBorderColor = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.38 : 0.34,
    );
    final surfaceColor = theme.colorScheme.surface;

    final box = AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value;
        final currentBg = Color.lerp(surfaceColor, fgColor, t)!;
        final currentBorder = Color.lerp(uncheckedBorderColor, fgColor, t)!;

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: currentBg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: currentBorder, width: 1.5),
          ),
          child: t > 0.01
              ? CustomPaint(
                  painter: _CheckmarkPainter(
                    progress: t,
                    color: isDark ? theme.colorScheme.surface : Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : null,
        );
      },
    );

    final content = CheckboxBounce(isDone: widget.checked, child: box);

    final wrappedBox = SizedBox(
      width: widget.tapTargetSize,
      height: widget.tapTargetSize,
      child: Center(child: content),
    );

    if (widget.onChanged == null) {
      return Semantics(
        label: widget.semanticLabel,
        checked: widget.checked,
        enabled: false,
        child: wrappedBox,
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      checked: widget.checked,
      button: true,
      child: InkWell(
        onTap: () => widget.onChanged?.call(!widget.checked),
        borderRadius: BorderRadius.circular(widget.borderRadius + 2),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: wrappedBox,
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p0 = Offset(size.width * 0.22, size.height * 0.52);
    final p1 = Offset(size.width * 0.44, size.height * 0.73);
    final p2 = Offset(size.width * 0.80, size.height * 0.28);

    final path = Path();
    final firstSegLen = (p1 - p0).distance;
    final secondSegLen = (p2 - p1).distance;
    final totalLen = firstSegLen + secondSegLen;
    final currentLen = totalLen * progress;

    path.moveTo(p0.dx, p0.dy);
    if (currentLen <= firstSegLen) {
      final ratio = currentLen / firstSegLen;
      final cur = Offset.lerp(p0, p1, ratio)!;
      path.lineTo(cur.dx, cur.dy);
    } else {
      path.lineTo(p1.dx, p1.dy);
      final ratio = (currentLen - firstSegLen) / secondSegLen;
      final cur = Offset.lerp(p1, p2, ratio)!;
      path.lineTo(cur.dx, cur.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
