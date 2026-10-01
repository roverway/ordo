import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/providers/mcp_server_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/settings_card.dart';

/// Settings card for MCP (Model Context Protocol) external integration.
class AiMcpServerCard extends ConsumerWidget {
  const AiMcpServerCard({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            color: isDark
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
                color: isDark
                    ? AppTokens.surfaceSubtleDark
                    : AppTokens.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: Border.all(
                  color: isDark
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
