import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/models/ai_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_modal_sheet.dart';
import '../../../shared/widgets/app_scroll_fade_wrapper.dart';

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

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final isDark = theme.brightness == Brightness.dark;
      final borderColor = isDark
          ? AppTokens.borderSubtleDark
          : AppTokens.borderSubtleLight;

      return _AiProviderPickerContent(
        selectedProvider: selectedProvider,
        providerKeyStatus: providerKeyStatus,
        onSelected: onSelected,
        l10n: l10n,
        languageCode: languageCode,
        isDark: isDark,
        borderColor: borderColor,
      );
    },
  );
}

class _AiProviderPickerContent extends StatefulWidget {
  const _AiProviderPickerContent({
    required this.selectedProvider,
    required this.providerKeyStatus,
    required this.onSelected,
    required this.l10n,
    required this.languageCode,
    required this.isDark,
    required this.borderColor,
  });

  final AiProviderType selectedProvider;
  final Map<AiProviderType, bool> providerKeyStatus;
  final ValueChanged<AiProviderType> onSelected;
  final AppLocalizations l10n;
  final String languageCode;
  final bool isDark;
  final Color borderColor;

  @override
  State<_AiProviderPickerContent> createState() =>
      _AiProviderPickerContentState();
}

class _AiProviderPickerContentState extends State<_AiProviderPickerContent> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppModalSheet(
      title: widget.l10n.aiSelectProviderTitle,
      subtitle: widget.l10n.aiSelectProviderSubtitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: AppScrollFadeWrapper(
          scrollController: _scrollController,
          bottomRadius: 0,
          child: ListView.separated(
            controller: _scrollController,
            shrinkWrap: true,
            itemCount: AiProviderType.values.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: widget.borderColor),
            itemBuilder: (context, index) {
              final p = AiProviderType.values[index];
              final isSelected = p == widget.selectedProvider;
              final hasKey = widget.providerKeyStatus[p] ?? false;

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
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
                        : (widget.isDark
                              ? AppTokens.surfaceSubtleDark
                              : AppTokens.surfaceSubtleLight),
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
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
                      p.localizedName(widget.languageCode),
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
                          widget.l10n.aiKeyConfigured,
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
                  getAiProviderSubtitle(p, widget.l10n),
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
                  Navigator.pop(context);
                  widget.onSelected(p);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
