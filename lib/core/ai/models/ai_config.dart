import 'package:flutter/foundation.dart';

/// Supported AI providers for Ordo Copilot Assistant (SPEC-ai-copilot-assistant).
enum AiProviderType {
  deepseek(
    id: 'deepseek',
    displayName: 'DeepSeek',
    displayNameEn: 'DeepSeek',
    defaultBaseUrl: 'https://api.deepseek.com',
    defaultModel: 'deepseek-chat',
    presetModels: ['deepseek-chat', 'deepseek-reasoner'],
  ),
  kimi(
    id: 'kimi',
    displayName: '月之暗面 Kimi',
    displayNameEn: 'Moonshot Kimi',
    defaultBaseUrl: 'https://api.moonshot.cn/v1',
    defaultModel: 'moonshot-v1-8k',
    presetModels: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
  ),
  qwen(
    id: 'qwen',
    displayName: '阿里通义千问 (DashScope)',
    displayNameEn: 'Alibaba Qwen (DashScope)',
    defaultBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModel: 'qwen-plus',
    presetModels: ['qwen-plus', 'qwen-turbo', 'qwen-max', 'qwen-long'],
  ),
  glm(
    id: 'glm',
    displayName: '智谱 GLM',
    displayNameEn: 'Zhipu GLM',
    defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-4-flash',
    presetModels: ['glm-4-flash', 'glm-4-plus', 'glm-4-air', 'glm-4-long'],
  ),
  openai(
    id: 'openai',
    displayName: 'OpenAI',
    displayNameEn: 'OpenAI',
    defaultBaseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
    presetModels: ['gpt-4o-mini', 'gpt-4o', 'o1', 'o3-mini'],
  ),
  claude(
    id: 'claude',
    displayName: 'Anthropic Claude',
    displayNameEn: 'Anthropic Claude',
    defaultBaseUrl: 'https://api.anthropic.com/v1',
    defaultModel: 'claude-3-5-haiku-20241022',
    presetModels: ['claude-3-5-haiku-20241022', 'claude-3-5-sonnet-20241022'],
  ),
  custom(
    id: 'custom',
    displayName: '自定义 (Custom)',
    displayNameEn: 'Custom',
    defaultBaseUrl: '',
    defaultModel: '',
    presetModels: [],
  );

  const AiProviderType({
    required this.id,
    required this.displayName,
    required this.displayNameEn,
    required this.defaultBaseUrl,
    required this.defaultModel,
    this.presetModels = const [],
  });

  final String id;
  final String displayName;
  final String displayNameEn;
  final String defaultBaseUrl;
  final String defaultModel;
  final List<String> presetModels;

  /// Returns localized display name based on language code ('zh', 'en', etc.).
  String localizedName([String? languageCode]) {
    if (languageCode != null && languageCode.toLowerCase().startsWith('en')) {
      return displayNameEn;
    }
    return displayName;
  }

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
