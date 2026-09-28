import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Linear-style breathing shimmer & micro-glow thinking indicator.
///
/// Replaces generic circular spinners with an organic, breathing capsule
/// inspired by Apple Intelligence and Linear design aesthetics.
class AiThinkingPulse extends StatefulWidget {
  const AiThinkingPulse({super.key, this.label});

  final String? label;

  @override
  State<AiThinkingPulse> createState() => _AiThinkingPulseState();
}

class _AiThinkingPulseState extends State<AiThinkingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTokens.motionPulse,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowValue = _glowAnimation.value;
        final baseColor = isDark
            ? AppTokens.surfaceCardDark
            : AppTokens.surfaceCardLight;
        final borderColor = primary.withValues(
          alpha: (0.2 + (0.4 * glowValue)).clamp(0.0, 1.0),
        );

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceSm + 2,
            vertical: AppTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(
                  alpha: (0.05 + 0.15 * glowValue).clamp(0.0, 1.0),
                ),
                blurRadius: 10 * glowValue + 2,
                spreadRadius: 1 * glowValue,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [primary, Colors.cyanAccent.shade200],
                    stops: [0.0, 1.0],
                  ).createShader(bounds);
                },
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppTokens.spaceXs),
              Text(
                widget.label ?? l10n.aiShimmerThinking,
                style: TextStyle(
                  fontSize: AppTokens.textFootnoteSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: isDark
                      ? AppTokens.textPrimaryDark.withValues(
                          alpha: (0.7 + 0.3 * glowValue).clamp(0.0, 1.0),
                        )
                      : AppTokens.textPrimaryLight.withValues(
                          alpha: (0.7 + 0.3 * glowValue).clamp(0.0, 1.0),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
