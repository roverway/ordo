import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/models/ai_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

IconData getAiProviderIcon(AiProviderType p) {
  return switch (p) {
    AiProviderType.deepseek => Icons.psychology_outlined,
    AiProviderType.kimi => Icons.dark_mode_outlined,
    AiProviderType.qwen => Icons.cloud_outlined,
    AiProviderType.glm => Icons.diamond_outlined,
    AiProviderType.openai => Icons.grain_outlined,
    AiProviderType.claude => Icons.bubble_chart_outlined,
    AiProviderType.custom => Icons.tune_outlined,
  };
}

String getAiProviderSubtitle(AiProviderType p, AppLocalizations l10n) {
  return switch (p) {
    AiProviderType.deepseek => l10n.aiProviderDeepSeekSubtitle,
    AiProviderType.kimi => l10n.aiProviderKimiSubtitle,
    AiProviderType.qwen => l10n.aiProviderQwenSubtitle,
    AiProviderType.glm => l10n.aiProviderGlmSubtitle,
    AiProviderType.openai => l10n.aiProviderOpenAiSubtitle,
    AiProviderType.claude => l10n.aiProviderClaudeSubtitle,
    AiProviderType.custom => l10n.aiProviderCustomSubtitle,
  };
}

/// Shows a bottom sheet allowing user to select an AI provider.
Future<void> showAiProviderPickerSheet({
  required BuildContext context,
  required AiProviderType selectedProvider,
  required Map<AiProviderType, bool> providerKeyStatus,
  required ValueChanged<AiProviderType> onSelected,
}) async {
  HapticFeedback.selectionClick();
  final l10n = AppLocalizations.of(context);
  final languageCode = Localizations.localeOf(context).languageCode;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final isDark = theme.brightness == Brightness.dark;
      final sheetBg = isDark
          ? AppTokens.surfaceCardDark
          : AppTokens.surfaceCard;
      final borderColor = isDark
          ? AppTokens.borderSubtleDark
          : AppTokens.borderSubtleLight;

      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusCard),
          ),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTokens.borderSubtleDark
                      : AppTokens.borderSubtleLight,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              l10n.aiSelectProviderTitle,
              style: TextStyle(
                fontSize: AppTokens.textTitleSize,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              l10n.aiSelectProviderSubtitle,
              style: TextStyle(
                fontSize: AppTokens.textMicroSize,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: ListView.separated(
                itemCount: AiProviderType.values.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (context, index) {
                  final p = AiProviderType.values[index];
                  final isSelected = p == selectedProvider;
                  final hasKey = providerKeyStatus[p] ?? false;

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceXs,
                      vertical: AppTokens.spaceMicro,
                    ),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(
                                alpha: AppTokens.alphaTintSoft,
                              )
                            : (isDark
                                  ? AppTokens.surfaceSubtleDark
                                  : AppTokens.surfaceSubtleLight),
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusChip,
                        ),
                      ),
                      child: Icon(
                        getAiProviderIcon(p),
                        size: 18,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          p.localizedName(languageCode),
                          style: TextStyle(
                            fontSize: AppTokens.textBodySize,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: AppTokens.spaceXs),
                        if (hasKey)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.spaceMicro + 2,
                              vertical: AppTokens.spaceMicro,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.colorSuccess.withValues(
                                alpha: AppTokens.alphaTintSoft,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusMicro,
                              ),
                            ),
                            child: Text(
                              l10n.aiKeyConfigured,
                              style: const TextStyle(
                                fontSize: AppTokens.textMicroSize,
                                color: AppTokens.colorSuccess,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      getAiProviderSubtitle(p, l10n),
                      style: TextStyle(
                        fontSize: AppTokens.textMicroSize,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: theme.colorScheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onSelected(p);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
