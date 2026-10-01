import 'package:flutter/material.dart';
import 'package:ordo/core/ai/models/efficiency_stats.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';
import 'package:ordo/shared/widgets/markdown_content_view.dart';
import 'ai_shimmer_glow.dart';

/// Linear-styled card widget visualizing weekly efficiency review and diagnostic.
class AiEfficiencyReportView extends StatelessWidget {
  const AiEfficiencyReportView({
    super.key,
    required this.stats,
    this.analysisMarkdown,
    this.isLoading = false,
  });

  /// Key identifying the 4-quadrant proportion bar in widget tests.
  static const Key quadrantBarKey = ValueKey(
    'ai_efficiency_report_quadrant_bar',
  );

  /// Key identifying the loading indicator in widget tests.
  static const Key loadingIndicatorKey = ValueKey(
    'ai_efficiency_report_loading_indicator',
  );

  final EfficiencyStats stats;
  final String? analysisMarkdown;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final cardBg = isDark
        ? AppTokens.surfaceCardDark
        : AppTokens.surfaceCardLight;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? AppTokens.cardShadowDarkList
            : AppTokens.cardShadowLight,
      ),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, isDark, l10n),
          const SizedBox(height: AppTokens.spaceMd),
          _buildKpiGrid(context, isDark, l10n),
          const SizedBox(height: AppTokens.spaceMd),
          _buildQuadrantSection(context, isDark, l10n),
          if (isLoading ||
              (analysisMarkdown != null && analysisMarkdown!.isNotEmpty)) ...[
            const SizedBox(height: AppTokens.spaceMd),
            _buildAnalysisSection(context, isDark, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final textPrimary = isDark
        ? AppTokens.textPrimaryDark
        : AppTokens.textPrimaryLight;
    final textMuted = isDark
        ? AppTokens.textMutedDark
        : AppTokens.textMutedLight;
    final tagBg = isDark
        ? AppTokens.surfaceSunkenDark
        : AppTokens.surfaceSunkenLight;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Row(
      children: [
        Container(
          width: AppTokens.spaceLg,
          height: AppTokens.spaceLg,
          decoration: BoxDecoration(
            color: AppTokens.colorInbox.withValues(
              alpha: AppTokens.alphaTintStrong,
            ),
            borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.insights_outlined,
            size: AppTokens.spaceMd,
            color: AppTokens.colorInbox,
          ),
        ),
        const SizedBox(width: AppTokens.spaceXs),
        Text(
          l10n.efficiencyWeeklyDiagnosis,
          style: TextStyle(
            fontSize: AppTokens.textTitleSize,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceXs,
            vertical: AppTokens.spaceXxs,
          ),
          decoration: BoxDecoration(
            color: tagBg,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            l10n.efficiencyPastDays,
            style: TextStyle(
              fontSize: AppTokens.textSectionLabelSize,
              color: textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final completionPct = '${stats.completionPercentage}%';

    return Row(
      children: [
        Expanded(
          child: _buildKpiItem(
            label: l10n.efficiencyCompletionRate,
            value: completionPct,
            valueColor: AppTokens.colorDone,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppTokens.spaceXs),
        Expanded(
          child: _buildKpiItem(
            label: l10n.efficiencyCompletedCount,
            value: '${stats.completedCount}',
            valueColor: isDark
                ? AppTokens.textPrimaryDark
                : AppTokens.textPrimaryLight,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppTokens.spaceXs),
        Expanded(
          child: _buildKpiItem(
            label: l10n.efficiencyCancelledCount,
            value: '${stats.cancelledCount}',
            valueColor: AppTokens.colorCancelled,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiItem({
    required String label,
    required String value,
    required Color valueColor,
    required bool isDark,
  }) {
    final itemBg = isDark
        ? AppTokens.surfaceSunkenDark
        : AppTokens.surfaceSunkenLight;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;
    final textMuted = isDark
        ? AppTokens.textMutedDark
        : AppTokens.textMutedLight;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTokens.spaceSm,
        horizontal: AppTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: AppTokens.textTitleSize,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: AppTokens.fontTabular,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXxs),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTokens.textSectionLabelSize,
              color: textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrantSection(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final textMuted = isDark
        ? AppTokens.textMutedDark
        : AppTokens.textMutedLight;
    final subtleEmptyColor = isDark
        ? AppTokens.surfaceSubtleDark
        : AppTokens.surfaceSubtleLight;

    final total = stats.totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.efficiencyQuadrantDistribution,
          style: TextStyle(
            fontSize: AppTokens.textSectionLabelSize,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
        const SizedBox(height: AppTokens.spaceXs),
        // Stacked Progress Bar
        ClipRRect(
          key: quadrantBarKey,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          child: SizedBox(
            height: AppTokens.spaceXs,
            child: total == 0
                ? Container(color: subtleEmptyColor)
                : Row(
                    children: [
                      if (stats.q1Count > 0)
                        Expanded(
                          flex: stats.q1Count,
                          child: Container(color: AppTokens.colorPriorityHigh),
                        ),
                      if (stats.q2Count > 0)
                        Expanded(
                          flex: stats.q2Count,
                          child: Container(
                            color: AppTokens.colorPriorityMedium,
                          ),
                        ),
                      if (stats.q3Count > 0)
                        Expanded(
                          flex: stats.q3Count,
                          child: Container(color: AppTokens.colorPriorityLow),
                        ),
                      if (stats.q4Count > 0)
                        Expanded(
                          flex: stats.q4Count,
                          child: Container(color: AppTokens.colorQuadrantQ4),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppTokens.spaceXs),
        // Legends
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLegendItem(
              'Q1',
              stats.q1Ratio,
              AppTokens.colorPriorityHigh,
              textMuted,
            ),
            _buildLegendItem(
              'Q2',
              stats.q2Ratio,
              AppTokens.colorPriorityMedium,
              textMuted,
            ),
            _buildLegendItem(
              'Q3',
              stats.q3Ratio,
              AppTokens.colorPriorityLow,
              textMuted,
            ),
            _buildLegendItem(
              'Q4',
              stats.q4Ratio,
              AppTokens.colorQuadrantQ4,
              textMuted,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(
    String name,
    double ratio,
    Color dotColor,
    Color textColor,
  ) {
    final pct = (ratio * 100).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppTokens.spaceXs,
          height: AppTokens.spaceXs,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTokens.spaceXxs),
        Text(
          '$name $pct%',
          style: TextStyle(
            fontSize: AppTokens.textSectionLabelSize,
            color: textColor,
            fontFeatures: AppTokens.fontTabular,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisSection(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final textMuted = isDark
        ? AppTokens.textMutedDark
        : AppTokens.textMutedLight;
    final subtleBg = isDark
        ? AppTokens.surfaceSunkenDark
        : AppTokens.surfaceSunkenLight;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceSm),
      decoration: BoxDecoration(
        color: subtleBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: AppTokens.spaceSm,
                color: AppTokens.colorInbox,
              ),
              const SizedBox(width: AppTokens.spaceXxs),
              Text(
                l10n.efficiencyAnalysisTitle,
                style: TextStyle(
                  fontSize: AppTokens.textSectionLabelSize,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXs),
          if (isLoading)
            Row(
              key: loadingIndicatorKey,
              children: [
                AiThinkingPulse(label: l10n.efficiencyDiagnosisGenerating),
              ],
            )
          else if (analysisMarkdown != null)
            MarkdownContentView(content: analysisMarkdown!, compact: true),
        ],
      ),
    );
  }
}
