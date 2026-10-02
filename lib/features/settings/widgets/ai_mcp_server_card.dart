import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/providers/mcp_server_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/settings_card.dart';

/// Settings card for MCP (Model Context Protocol) external integration.
class AiMcpServerCard extends ConsumerStatefulWidget {
  const AiMcpServerCard({super.key, required this.isDark});

  final bool isDark;

  @override
  ConsumerState<AiMcpServerCard> createState() => _AiMcpServerCardState();
}

class _AiMcpServerCardState extends ConsumerState<AiMcpServerCard> {
  bool _revealApiKey = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mcpState = ref.watch(mcpServerStateProvider);

    return SettingsCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: AppTokens.alphaTintSoft,
                ),
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
              ),
              child: Icon(
                Icons.hub_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aiMcpCardTitle,
                    style: TextStyle(
                      fontSize: AppTokens.textBodySize,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceMicro),
                  Text(
                    l10n.aiMcpCardSubtitle,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Transform.scale(
              scale: 0.88,
              child: Switch(
                activeTrackColor: colorScheme.primary,
                activeThumbColor: colorScheme.onPrimary,
                value: mcpState.isEnabled,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  ref.read(mcpServerStateProvider.notifier).toggleEnabled(val);
                },
              ),
            ),
          ],
        ),
        if (mcpState.isEnabled) ...[
          const SizedBox(height: AppTokens.spaceSm),
          Divider(
            height: 1,
            color: widget.isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceXs,
                  vertical: AppTokens.spaceMicro,
                ),
                decoration: BoxDecoration(
                  color:
                      (mcpState.isRunning
                              ? AppTokens.colorSuccess
                              : AppTokens.colorDanger)
                          .withValues(alpha: AppTokens.alphaTintSoft),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: mcpState.isRunning
                          ? AppTokens.colorSuccess
                          : AppTokens.colorDanger,
                    ),
                    const SizedBox(width: AppTokens.spaceMicro),
                    Text(
                      mcpState.isRunning
                          ? l10n.aiMcpStatusRunning
                          : l10n.aiMcpStatusStopped,
                      style: TextStyle(
                        fontSize: AppTokens.textMicroSize,
                        fontWeight: FontWeight.w500,
                        color: mcpState.isRunning
                            ? AppTokens.colorSuccessText
                            : AppTokens.colorDangerText,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (mcpState.endpointUrl != null)
                Text(
                  l10n.aiMcpEndpointLabel,
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (mcpState.endpointUrl != null) ...[
            const SizedBox(height: AppTokens.spaceXs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceXs,
              ),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppTokens.surfaceSubtleDark
                    : AppTokens.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: Border.all(
                  color: widget.isDark
                      ? AppTokens.borderSubtleDark
                      : AppTokens.borderSubtleLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  Expanded(
                    child: SelectableText(
                      mcpState.endpointUrl!,
                      style: const TextStyle(
                        fontFamily: AppTokens.fontMonoFamily,
                        fontSize: AppTokens.textFootnoteSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    tooltip: l10n.aiMcpEndpointCopied,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Clipboard.setData(
                        ClipboardData(text: mcpState.endpointUrl!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.aiMcpEndpointCopied),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          // --- API Key & Authentication Section ---
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            children: [
              Text(
                l10n.aiMcpAuthToggle,
                style: TextStyle(
                  fontSize: AppTokens.textFootnoteSize,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  activeTrackColor: colorScheme.primary,
                  activeThumbColor: colorScheme.onPrimary,
                  value: mcpState.isAuthEnabled,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    ref.read(mcpServerStateProvider.notifier).toggleAuth(val);
                  },
                ),
              ),
            ],
          ),
          if (mcpState.isAuthEnabled && mcpState.apiKey != null) ...[
            const SizedBox(height: AppTokens.spaceMicro),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceMicro,
              ),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppTokens.surfaceSubtleDark
                    : AppTokens.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: Border.all(
                  color: widget.isDark
                      ? AppTokens.borderSubtleDark
                      : AppTokens.borderSubtleLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.key_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  Expanded(
                    child: SelectableText(
                      _revealApiKey
                          ? mcpState.apiKey!
                          : '••••••••••••••••••••••••••••••••',
                      style: const TextStyle(
                        fontFamily: AppTokens.fontMonoFamily,
                        fontSize: AppTokens.textFootnoteSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _revealApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _revealApiKey = !_revealApiKey;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    tooltip: l10n.aiMcpApiKeyCopied,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Clipboard.setData(ClipboardData(text: mcpState.apiKey!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.aiMcpApiKeyCopied),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_outlined, size: 16),
                    tooltip: l10n.aiMcpApiKeyRegenerate,
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.aiMcpApiKeyRegenerate),
                          content: Text(l10n.aiMcpApiKeyRegenerateConfirm),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(
                                MaterialLocalizations.of(ctx).cancelButtonLabel,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(
                                MaterialLocalizations.of(ctx).okButtonLabel,
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(mcpServerStateProvider.notifier)
                            .regenerateApiKey();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          // --- Write Mode Section ---
          const SizedBox(height: AppTokens.spaceSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.aiMcpWriteModeLabel,
                style: TextStyle(
                  fontSize: AppTokens.textFootnoteSize,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'direct',
                    label: Text(l10n.aiMcpWriteModeDirect),
                    icon: const Icon(Icons.flash_on_outlined, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: 'review',
                    label: Text(l10n.aiMcpWriteModeReview),
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                  ),
                ],
                selected: {mcpState.writeMode},
                onSelectionChanged: (Set<String> newSelection) {
                  HapticFeedback.selectionClick();
                  ref
                      .read(mcpServerStateProvider.notifier)
                      .setWriteMode(newSelection.first);
                },
              ),
              const SizedBox(height: AppTokens.spaceMicro),
              Text(
                mcpState.writeMode == 'direct'
                    ? l10n.aiMcpWriteModeDirectDesc
                    : l10n.aiMcpWriteModeReviewDesc,
                style: TextStyle(
                  fontSize: AppTokens.textMicroSize,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (mcpState.errorMessage != null) ...[
            const SizedBox(height: AppTokens.spaceXs),
            Container(
              padding: const EdgeInsets.all(AppTokens.spaceSm),
              decoration: BoxDecoration(
                color: AppTokens.colorDanger.withValues(
                  alpha: AppTokens.alphaTintSoft,
                ),
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: Border.all(
                  color: AppTokens.colorDanger.withValues(
                    alpha: AppTokens.alphaBorderSubtle,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppTokens.colorDanger,
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  Expanded(
                    child: Text(
                      mcpState.errorMessage!,
                      style: const TextStyle(
                        fontSize: AppTokens.textMicroSize,
                        color: AppTokens.colorDangerText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTokens.spaceXs),
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTokens.spaceXxs),
              Expanded(
                child: Text(
                  l10n.aiMcpSecurityHint,
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
