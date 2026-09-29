import 'package:flutter/material.dart';
import '../../../core/ai/services/ai_client.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Card displaying connectivity diagnostic test results (latency, error message).
class AiPingResultCard extends StatelessWidget {
  const AiPingResultCard({
    super.key,
    required this.result,
    required this.isDark,
  });

  final AiPingResult result;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSuccess = result.isSuccess;
    final color = isSuccess ? AppTokens.colorSuccess : AppTokens.colorDanger;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final text = isSuccess
        ? l10n.aiTestSuccess(result.durationMs)
        : (result.errorMessage ?? l10n.aiTestFailed);

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceSm),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: isDark ? AppTokens.alphaTintStrong : AppTokens.alphaTintSoft,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(
          color: color.withValues(
            alpha: isDark
                ? AppTokens.alphaBorderEmphasis
                : AppTokens.alphaBorderSubtle,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppTokens.textFootnoteSize,
                color: isSuccess
                    ? AppTokens.colorSuccessText
                    : AppTokens.colorDangerText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
