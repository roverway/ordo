import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/models/ai_config.dart';
import '../../../core/ai/services/ai_client.dart';
import '../../../core/ai/services/ai_config_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../widgets/settings_card.dart';

/// Maximum width for wide screens (Linear desktop style).
const double _kFormMaxWidth = 560;

/// Settings page for AI Copilot Assistant configuration (TICKET-001).
class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAiAssistant), centerTitle: false),
      body: const AiSettingsBody(),
    );
  }
}

/// Body content of AI Assistant settings.
class AiSettingsBody extends ConsumerStatefulWidget {
  const AiSettingsBody({super.key});

  @override
  ConsumerState<AiSettingsBody> createState() => _AiSettingsBodyState();
}

class _AiSettingsBodyState extends ConsumerState<AiSettingsBody> {
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();

  AiProviderType _provider = AiProviderType.deepseek;
  bool _obscureApiKey = true;
  bool _hasSavedApiKey = false;
  String _savedMaskedKey = '';

  bool _testing = false;
  bool _saving = false;
  bool _probing = false;
  AiPingResult? _lastPingResult;
  bool _initialized = false;
  List<String> _probedModels = [];
  Map<AiProviderType, bool> _providerKeyStatus = {};

  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  Future<void> _loadInitialConfig() async {
    final service = ref.read(aiConfigServiceProvider);
    final config = await service.loadConfig();
    final keyStatus = <AiProviderType, bool>{};
    for (final p in AiProviderType.values) {
      keyStatus[p] = await service.hasKeyFor(p);
    }

    if (!mounted) return;
    setState(() {
      _provider = config.provider;
      _baseUrlController.text = config.baseUrl;
      _modelController.text = config.model;
      _hasSavedApiKey = config.apiKey != null && config.apiKey!.isNotEmpty;
      _savedMaskedKey = config.maskedApiKey;
      _providerKeyStatus = keyStatus;
      _probedModels = _provider.presetModels;
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _onProviderChanged(AiProviderType? newProvider) async {
    if (newProvider == null || newProvider == _provider) return;

    final configService = ref.read(aiConfigServiceProvider);
    final targetConfig = await configService.loadConfig(newProvider);

    if (!mounted) return;
    setState(() {
      _provider = newProvider;
      _baseUrlController.text = targetConfig.baseUrl;
      _modelController.text = targetConfig.model;
      _hasSavedApiKey =
          targetConfig.apiKey != null && targetConfig.apiKey!.isNotEmpty;
      _savedMaskedKey = targetConfig.maskedApiKey;
      _apiKeyController.clear();
      _lastPingResult = null;
      _probedModels = newProvider.presetModels;
    });
  }

  AiConfig _buildCurrentConfig() {
    final rawKey = _apiKeyController.text.trim();
    return AiConfig(
      provider: _provider,
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      apiKey: rawKey.isNotEmpty ? rawKey : null,
    );
  }

  Future<void> _probeModels() async {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final config = _buildCurrentConfig();
    final effectiveConfig = (config.apiKey == null && _hasSavedApiKey)
        ? await ref.read(aiConfigServiceProvider).loadConfig(_provider)
        : config;

    if (effectiveConfig.apiKey == null || effectiveConfig.apiKey!.isEmpty) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiProbeNeedKeyError),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _probing = true;
    });

    try {
      final models = await ref
          .read(aiConfigServiceProvider)
          .fetchModels(effectiveConfig, locale: locale);

      if (!mounted) return;
      setState(() {
        _probedModels = models;
        _probing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiProbeSuccessCount(models.length)),
          duration: const Duration(seconds: 2),
        ),
      );
      _showModelPickerSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _probing = false;
        if (_probedModels.isEmpty) {
          _probedModels = _provider.presetModels;
        }
      });
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiProbeFailedFallback(e.toString())),
          duration: const Duration(seconds: 3),
        ),
      );
      if (_probedModels.isNotEmpty) {
        _showModelPickerSheet();
      }
    }
  }

  Future<void> _testConnection() async {
    final config = _buildCurrentConfig();

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    if ((config.apiKey == null || config.apiKey!.isEmpty) && !_hasSavedApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiTestNeedKeyError),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _testing = true;
      _lastPingResult = null;
    });

    final effectiveConfig = (config.apiKey == null && _hasSavedApiKey)
        ? await ref.read(aiConfigServiceProvider).loadConfig(_provider)
        : config;

    final result = await ref
        .read(aiConfigServiceProvider)
        .testConnection(effectiveConfig, locale: locale);

    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastPingResult = result;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final config = _buildCurrentConfig();

    await ref.read(aiConfigServiceProvider).saveConfig(config);
    ref.invalidate(aiConfigProvider);

    final service = ref.read(aiConfigServiceProvider);
    final reloaded = await service.loadConfig(_provider);
    final keyStatus = <AiProviderType, bool>{};
    for (final p in AiProviderType.values) {
      keyStatus[p] = await service.hasKeyFor(p);
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _providerKeyStatus = keyStatus;
      if (reloaded.apiKey != null && reloaded.apiKey!.isNotEmpty) {
        _hasSavedApiKey = true;
        _savedMaskedKey = reloaded.maskedApiKey;
        _apiKeyController.clear();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.aiSaveSuccess),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearKey() async {
    await ref.read(aiConfigServiceProvider).clearApiKey(_provider);
    ref.invalidate(aiConfigProvider);

    final service = ref.read(aiConfigServiceProvider);
    final keyStatus = <AiProviderType, bool>{};
    for (final p in AiProviderType.values) {
      keyStatus[p] = await service.hasKeyFor(p);
    }

    if (!mounted) return;
    setState(() {
      _hasSavedApiKey = false;
      _savedMaskedKey = '';
      _apiKeyController.clear();
      _lastPingResult = null;
      _providerKeyStatus = keyStatus;
    });
  }

  void _showProviderPickerSheet() {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    showModalBottomSheet<void>(
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
                    final isSelected = p == _provider;
                    final hasKey = _providerKeyStatus[p] ?? false;

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
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusChip),
                        ),
                        child: Icon(
                          _providerIcon(p),
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
                                style: TextStyle(
                                  fontSize: AppTokens.textMicroSize,
                                  color: AppTokens.colorSuccess,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        _providerSubtitle(p, l10n),
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
                        _onProviderChanged(p);
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

  void _showModelPickerSheet() {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final allModels = <String>{
      ..._probedModels,
      ..._provider.presetModels,
      if (_modelController.text.trim().isNotEmpty) _modelController.text.trim(),
    }.toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(sheetContext);
            final isDark = theme.brightness == Brightness.dark;
            final sheetBg = isDark
                ? AppTokens.surfaceCardDark
                : AppTokens.surfaceCard;
            final borderColor = isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight;

            final filtered = allModels.where((m) {
              if (query.isEmpty) return true;
              return m.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
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
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusPill),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.aiSelectModelTitle(_provider.localizedName(languageCode)),
                          style: TextStyle(
                            fontSize: AppTokens.textTitleSize,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _probeModels();
                        },
                        icon: const Icon(Icons.refresh, size: 14),
                        label: Text(
                          l10n.aiProbeRefresh,
                          style: TextStyle(
                            fontSize: AppTokens.textFootnoteSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  TextField(
                    decoration: InputDecoration(
                      hintText: l10n.aiModelSearchHint,
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceSm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusCard),
                      ),
                    ),
                    onChanged: (val) {
                      setSheetState(() {
                        query = val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              l10n.aiNoMatchingModels,
                              style: TextStyle(
                                fontSize: AppTokens.textFootnoteSize,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                Divider(height: 1, color: borderColor),
                            itemBuilder: (context, index) {
                              final modelName = filtered[index];
                              final isSelected =
                                  modelName == _modelController.text.trim();

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppTokens.spaceXs,
                                ),
                                leading: Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 16,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  modelName,
                                  style: TextStyle(
                                    fontSize: AppTokens.textBodySize,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: theme.colorScheme.primary,
                                        size: 18,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  setState(() {
                                    _modelController.text = modelName;
                                  });
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
      },
    );
  }

  String _providerSubtitle(AiProviderType p, AppLocalizations l10n) {
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

  IconData _providerIcon(AiProviderType p) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final content = ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      children: [
        // Provider card (Linear Style Polymorphic Selector)
        SettingsCard(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.aiProvider,
                    style: TextStyle(
                      fontSize: AppTokens.textBodySize,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  l10n.aiProviderSwitchOnDemand,
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),
            InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              onTap: _showProviderPickerSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceSm,
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
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(
                          alpha: AppTokens.alphaTintSoft,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMicro),
                      ),
                      child: Icon(
                        _providerIcon(_provider),
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _provider.localizedName(languageCode),
                            style: TextStyle(
                              fontSize: AppTokens.textBodySize,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            _providerSubtitle(_provider, l10n),
                            style: TextStyle(
                              fontSize: AppTokens.textMicroSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_hasSavedApiKey) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceXs,
                          vertical: AppTokens.spaceMicro,
                        ),
                        decoration: BoxDecoration(
                          color: AppTokens.colorSuccess.withValues(
                            alpha: AppTokens.alphaTintSoft,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusPill),
                        ),
                        child: Text(
                          l10n.aiKeyConfigured,
                          style: TextStyle(
                            fontSize: AppTokens.textMicroSize,
                            color: AppTokens.colorSuccess,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceXs),
                    ],
                    Icon(
                      Icons.unfold_more,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTokens.spaceMd),

        // Endpoints & Models card
        SettingsCard(
          children: [
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: l10n.aiBaseUrl,
                hintText: l10n.aiBaseUrlHint,
                helperText: l10n.aiBaseUrlEndpointHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppTokens.spaceMd),

            // Model input with Probe & Select buttons
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: l10n.aiModel,
                hintText: l10n.aiModelHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Probe models button
                    Tooltip(
                      message: l10n.aiProbeTooltip,
                      child: TextButton.icon(
                        onPressed: _probing ? null : _probeModels,
                        icon: _probing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.radar_outlined, size: 16),
                        label: Text(
                          l10n.aiProbeButton,
                          style: TextStyle(
                            fontSize: AppTokens.textFootnoteSize,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.spaceXs,
                          ),
                        ),
                      ),
                    ),
                    // Model list selector button
                    Tooltip(
                      message: l10n.aiSelectModelTooltip,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        onPressed: _showModelPickerSheet,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceXxs),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTokens.spaceMd),

        // API Key card
        SettingsCard(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.aiApiKey,
                    style: TextStyle(
                      fontSize: AppTokens.textBodySize,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (_hasSavedApiKey)
                  TextButton.icon(
                    onPressed: _clearKey,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(
                      l10n.aiClearKey,
                      style: const TextStyle(
                        fontSize: AppTokens.textFootnoteSize,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTokens.colorDanger,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceXs,
                        vertical: AppTokens.spaceMicro,
                      ),
                    ),
                  ),
              ],
            ),
            if (_hasSavedApiKey && _savedMaskedKey.isNotEmpty) ...[
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
                  borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                  border: Border.all(
                    color: isDark
                        ? AppTokens.borderSubtleDark
                        : AppTokens.borderSubtleLight,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.vpn_key_outlined,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    Expanded(
                      child: Text(
                        _savedMaskedKey,
                        style: const TextStyle(
                          fontFamily: AppTokens.fontMonoFamily,
                          fontSize: AppTokens.textFootnoteSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppTokens.spaceSm),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: _hasSavedApiKey
                    ? l10n.aiUpdateKeyPlaceholder
                    : 'API Key',
                hintText: _hasSavedApiKey ? l10n.aiApiKeyHint : 'sk-...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.spaceXxs),
                Expanded(
                  child: Text(
                    l10n.aiKeyStoredSecurely,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppTokens.spaceMd),

        // Ping diagnostic indicator if available
        if (_lastPingResult != null) ...[
          _buildPingResultCard(_lastPingResult!, l10n, isDark),
          const SizedBox(height: AppTokens.spaceMd),
        ],

        // Action Buttons Card (Placed in a single row side-by-side)
        SettingsCard(
          children: [
            Row(
              children: [
                // Test Connection Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_outlined, size: 18),
                    label: Text(
                      _testing
                          ? l10n.aiTestingConnection
                          : l10n.aiTestConnection,
                      style: const TextStyle(
                        fontSize: AppTokens.textFootnoteSize,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusButton),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceSm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),

                // Save Configuration Button
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveConfig,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      l10n.aiSaveConfig,
                      style: const TextStyle(
                        fontSize: AppTokens.textFootnoteSize,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusButton),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceSm,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceXxl),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
        child: content,
      ),
    );
  }

  Widget _buildPingResultCard(
    AiPingResult result,
    AppLocalizations l10n,
    bool isDark,
  ) {
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
          alpha: isDark
              ? AppTokens.alphaTintStrong
              : AppTokens.alphaTintSoft,
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
