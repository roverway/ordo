import 'package:flutter/foundation.dart';

/// Supported AI providers for Ordo Copilot Assistant (SPEC-ai-copilot-assistant).
enum AiProviderType {
  deepseek(
    id: 'deepseek',
    displayName: 'DeepSeek',
    defaultBaseUrl: 'https://api.deepseek.com',
    defaultModel: 'deepseek-chat',
  ),
  glm(
    id: 'glm',
    displayName: '智谱 GLM',
    defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-4-flash',
  ),
  openai(
    id: 'openai',
    displayName: 'OpenAI',
    defaultBaseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
  ),
  claude(
    id: 'claude',
    displayName: 'Anthropic Claude',
    defaultBaseUrl: 'https://api.anthropic.com/v1',
    defaultModel: 'claude-3-5-haiku-20241022',
  ),
  custom(
    id: 'custom',
    displayName: '自定义 (Custom)',
    defaultBaseUrl: '',
    defaultModel: '',
  );

  const AiProviderType({
    required this.id,
    required this.displayName,
    required this.defaultBaseUrl,
    required this.defaultModel,
  });

  final String id;
  final String displayName;
  final String defaultBaseUrl;
  final String defaultModel;

  static AiProviderType fromId(String? id) {
    if (id == null) return AiProviderType.deepseek;
    return AiProviderType.values.firstWhere(
      (type) => type.id == id || type.name == id,
      orElse: () => AiProviderType.deepseek,
    );
  }
}

/// AI Configuration entity.
///
/// Non-sensitive fields (provider, baseUrl, model) are stored in the Drift `settings` table.
/// Sensitive credentials (apiKey) are stored in `flutter_secure_storage`.
@immutable
class AiConfig {
  const AiConfig({
    required this.provider,
    required this.baseUrl,
    required this.model,
    this.apiKey,
  });

  final AiProviderType provider;
  final String baseUrl;
  final String model;
  final String? apiKey;

  /// Default configuration for initial state.
  factory AiConfig.initial() {
    return const AiConfig(
      provider: AiProviderType.deepseek,
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
    );
  }

  /// Returns masked API key for UI display (e.g. `sk-****cdef` or `gl****3456`).
  String get maskedApiKey {
    final key = apiKey;
    if (key == null || key.isEmpty) return '';
    if (key.length <= 8) {
      if (key.startsWith('sk-')) {
        return 'sk-****';
      }
      return '****';
    }
    if (key.startsWith('sk-')) {
      return 'sk-****${key.substring(key.length - 4)}';
    }
    return '${key.substring(0, 2)}****${key.substring(key.length - 4)}';
  }

  AiConfig copyWith({
    AiProviderType? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
  }) {
    return AiConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiConfig &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          baseUrl == other.baseUrl &&
          model == other.model &&
          apiKey == other.apiKey;

  @override
  int get hashCode => Object.hash(provider, baseUrl, model, apiKey);

  @override
  String toString() =>
      'AiConfig(provider: ${provider.id}, baseUrl: $baseUrl, model: $model, apiKey: $maskedApiKey)';
}
