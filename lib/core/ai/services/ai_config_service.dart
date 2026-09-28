import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/projects/project_providers.dart';
import '../../db/daos/settings_dao.dart';
import '../../security/secure_store.dart';
import '../models/ai_config.dart';
import 'ai_client.dart';

/// Keys used in Drift `settings` table for non-sensitive AI configurations.
abstract final class AiSettingsKeys {
  static const String provider = 'ai_provider';
  static const String baseUrl = 'ai_base_url';
  static const String model = 'ai_model';
}

/// Key prefix for sensitive credentials stored in [SecureKeyValueStore].
abstract final class AiSecureKeys {
  static const String apiKeyPrefix = 'ai_api_key_';
  static const String defaultApiKey = 'ai_api_key';

  static String keyFor(AiProviderType provider) =>
      '$apiKeyPrefix${provider.id}';
}

/// Service managing persistent storage and security isolation for AI configuration.
class AiConfigService {
  AiConfigService({
    required SettingsDao settingsDao,
    SecureKeyValueStore? secureStore,
    AiClient? aiClient,
  }) : _settingsDao = settingsDao,
       _secureStore = secureStore ?? const FlutterSecureKeyValueStore(),
       _aiClient = aiClient ?? AiClient();

  final SettingsDao _settingsDao;
  final SecureKeyValueStore _secureStore;
  final AiClient _aiClient;

  /// Loads AI configuration. Non-sensitive from Drift settings, API Key from secure store.
  Future<AiConfig> loadConfig() async {
    final providerId = await _settingsDao.get(AiSettingsKeys.provider);
    final provider = AiProviderType.fromId(providerId);

    final storedBaseUrl = await _settingsDao.get(AiSettingsKeys.baseUrl);
    final baseUrl = (storedBaseUrl != null && storedBaseUrl.isNotEmpty)
        ? storedBaseUrl
        : provider.defaultBaseUrl;

    final storedModel = await _settingsDao.get(AiSettingsKeys.model);
    final model = (storedModel != null && storedModel.isNotEmpty)
        ? storedModel
        : provider.defaultModel;

    // Read API key from secure store with exception defense for platform keyring issues
    String? apiKey;
    try {
      apiKey = await _secureStore.read(AiSecureKeys.keyFor(provider));
      if (apiKey == null || apiKey.isEmpty) {
        // Fallback to generic key if present
        apiKey = await _secureStore.read(AiSecureKeys.defaultApiKey);
      }
    } catch (_) {
      apiKey = null;
    }

    return AiConfig(
      provider: provider,
      baseUrl: baseUrl,
      model: model,
      apiKey: (apiKey != null && apiKey.isNotEmpty) ? apiKey : null,
    );
  }

  /// Saves AI configuration.
  ///
  /// Non-sensitive fields are written to `settings` table.
  /// API key (if provided and non-empty) is written to `flutter_secure_storage`.
  /// If `config.apiKey` is null, existing API key in secure storage is preserved.
  Future<void> saveConfig(AiConfig config) async {
    await _settingsDao.set(AiSettingsKeys.provider, config.provider.id);
    await _settingsDao.set(AiSettingsKeys.baseUrl, config.baseUrl);
    await _settingsDao.set(AiSettingsKeys.model, config.model);

    if (config.apiKey != null) {
      if (config.apiKey!.isNotEmpty) {
        await _secureStore.write(
          AiSecureKeys.keyFor(config.provider),
          config.apiKey!,
        );
        await _secureStore.write(AiSecureKeys.defaultApiKey, config.apiKey!);
      } else {
        await _secureStore.delete(AiSecureKeys.keyFor(config.provider));
      }
    }
  }

  /// Clears the API key for the specified provider from secure storage.
  Future<void> clearApiKey(AiProviderType provider) async {
    await _secureStore.delete(AiSecureKeys.keyFor(provider));
    await _secureStore.delete(AiSecureKeys.defaultApiKey);
  }

  /// Tests connectivity and authentication using [AiClient].
  Future<AiPingResult> testConnection(AiConfig config) {
    return _aiClient.ping(config);
  }
}

/// Provider for [AiClient].
final aiClientProvider = Provider<AiClient>((ref) {
  return AiClient();
});

/// Provider for [AiConfigService].
final aiConfigServiceProvider = Provider<AiConfigService>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  final client = ref.watch(aiClientProvider);
  return AiConfigService(settingsDao: repo.settings, aiClient: client);
});

/// Async notifier provider for currently active [AiConfig].
final aiConfigProvider = AsyncNotifierProvider<AiConfigNotifier, AiConfig>(
  AiConfigNotifier.new,
);

class AiConfigNotifier extends AsyncNotifier<AiConfig> {
  @override
  Future<AiConfig> build() async {
    final service = ref.watch(aiConfigServiceProvider);
    return service.loadConfig();
  }

  /// Updates and persists the AI configuration, then refreshes state with persisted values.
  Future<void> updateConfig(AiConfig newConfig) async {
    final service = ref.read(aiConfigServiceProvider);
    await service.saveConfig(newConfig);
    final reloaded = await service.loadConfig();
    state = AsyncData(reloaded);
  }

  /// Tests connectivity with given config.
  Future<AiPingResult> testConnection(AiConfig config) async {
    final service = ref.read(aiConfigServiceProvider);
    return service.testConnection(config);
  }
}
