import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/models/ai_config.dart';
import '../../../core/ai/services/ai_client.dart';
import '../../../core/ai/services/ai_config_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

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
  AiPingResult? _lastPingResult;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  Future<void> _loadInitialConfig() async {
    final config = await ref.read(aiConfigServiceProvider).loadConfig();
    if (!mounted) return;
    setState(() {
      _provider = config.provider;
      _baseUrlController.text = config.baseUrl;
      _modelController.text = config.model;
      if (config.apiKey != null && config.apiKey!.isNotEmpty) {
        _hasSavedApiKey = true;
        _savedMaskedKey = config.maskedApiKey;
      }
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

  void _onProviderChanged(AiProviderType? newProvider) {
    if (newProvider == null || newProvider == _provider) return;

    final prevProvider = _provider;
    setState(() {
      _provider = newProvider;
      // Auto-update base URL if empty or still matching previous provider default
      if (_baseUrlController.text.trim().isEmpty ||
          _baseUrlController.text.trim() == prevProvider.defaultBaseUrl) {
        _baseUrlController.text = newProvider.defaultBaseUrl;
      }
      // Auto-update model if empty or still matching previous provider default
      if (_modelController.text.trim().isEmpty ||
          _modelController.text.trim() == prevProvider.defaultModel) {
        _modelController.text = newProvider.defaultModel;
      }
      _lastPingResult = null;
    });
  }

  AiConfig _buildCurrentConfig() {
    final rawKey = _apiKeyController.text.trim();
    return AiConfig(
      provider: _provider,
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      // If user left input blank but had a saved key, passing null preserves existing key
      apiKey: rawKey.isNotEmpty ? rawKey : null,
    );
  }

  Future<void> _testConnection() async {
    final config = _buildCurrentConfig();

    // If no new key entered and no saved key, prompt user
    if ((config.apiKey == null || config.apiKey!.isEmpty) && !_hasSavedApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入 API Key 再测试连接'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _testing = true;
      _lastPingResult = null;
    });

    final effectiveConfig = (config.apiKey == null && _hasSavedApiKey)
        ? await ref.read(aiConfigServiceProvider).loadConfig()
        : config;

    final result = await ref
        .read(aiConfigServiceProvider)
        .testConnection(effectiveConfig);

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

    // Refresh display
    final reloaded = await ref.read(aiConfigServiceProvider).loadConfig();

    if (!mounted) return;
    setState(() {
      _saving = false;
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

    if (!mounted) return;
    setState(() {
      _hasSavedApiKey = false;
      _savedMaskedKey = '';
      _apiKeyController.clear();
      _lastPingResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        // Provider card
        _AiCard(
          children: [
            Text(
              l10n.aiProvider,
              style: TextStyle(
                fontSize: AppTokens.textBodySize,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            DropdownButtonFormField<AiProviderType>(
              initialValue: _provider,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                  vertical: AppTokens.spaceSm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
              ),
              items: AiProviderType.values.map((type) {
                return DropdownMenuItem<AiProviderType>(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: _onProviderChanged,
            ),
          ],
        ),

        const SizedBox(height: AppTokens.spaceMd),

        // Endpoints & Models card
        _AiCard(
          children: [
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: l10n.aiBaseUrl,
                hintText: l10n.aiBaseUrlHint,
                helperText:
                    'OpenAI 协议服务兼容 /chat/completions，Claude 服务兼容 /messages',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: l10n.aiModel,
                hintText: l10n.aiModelHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTokens.spaceMd),

        // API Key card
        _AiCard(
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
                labelText: _hasSavedApiKey ? '更新密钥 (留空则保留原密钥)' : 'API Key',
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

        // Action Buttons Card
        _AiCard(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_outlined),
                label: Text(
                  _testing ? l10n.aiTestingConnection : l10n.aiTestConnection,
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.spaceSm,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveConfig,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.aiSaveConfig),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.spaceSm,
                  ),
                ),
              ),
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
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3)),
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

/// Linear style card container adhering strictly to AppTokens.
class _AiCard extends StatelessWidget {
  const _AiCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfaceDark : AppTokens.surfaceCardLight,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleNeutralLight,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppTokens.borderSubtleLight,
                  blurRadius: AppTokens.radiusXs,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
