import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/motion.dart';

/// Hero 大标题区域的环形进度条组件（原型 62×62，中央显示 `1/8` 或 `100%`）。
///
/// 见于 `home.html` / `tasklist.html` / `overview.html` 头部右侧。
class HeroProgressRing extends StatelessWidget {
  const HeroProgressRing({
    super.key,
    required this.completed,
    required this.total,
    this.size = AppTokens.progressRingHeroSize,
    this.strokeWidth = AppTokens.progressRingHeroWidth,
    this.customCenterText,
  });

  final int completed;
  final int total;
  final double size;
  final double strokeWidth;
  final String? customCenterText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final targetValue = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final labelText = customCenterText ?? '$completed/$total';

    final trackColor = colorScheme.primary.withValues(
      alpha: isDark ? 0.16 : 0.10,
    );

    final barColor = colorScheme.primary;

    return Semantics(
      label: AppLocalizations.of(context).progressA11y(labelText),
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: targetValue),
                duration: motionNormal(context),
                curve: motionCurve(context),
                builder: (context, animatedValue, _) {
                  return CustomPaint(
                    size: Size(size, size),
                    painter: _RingPainter(
                      progress: animatedValue,
                      trackColor: trackColor,
                      barColor: barColor,
                      strokeWidth: strokeWidth,
                    ),
                  );
                },
              ),
              Text(
                labelText,
                style: TextStyle(
                  fontFeatures: AppTokens.fontTabular,
                  fontSize: AppTokens.textCaptionSize,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.barColor,
    required this.strokeWidth,
  }) : _trackPaint = Paint()
         ..color = trackColor
         ..style = PaintingStyle.stroke
         ..strokeWidth = strokeWidth,
       _barPaint = Paint()
         ..color = barColor
         ..style = PaintingStyle.stroke
         ..strokeWidth = strokeWidth
         ..strokeCap = StrokeCap.round;

  final double progress;
  final Color trackColor;
  final Color barColor;
  final double strokeWidth;
  final Paint _trackPaint;
  final Paint _barPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(center, radius, _trackPaint);

    if (progress > 0.001) {
      const startAngle = -3.141592653589793 / 2; // -90 deg
      final sweepAngle = 2 * 3.141592653589793 * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        _barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.barColor != barColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
