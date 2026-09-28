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

  /// Per-provider specific settings keys
  static String baseUrlFor(AiProviderType p) => 'ai_base_url_${p.id}';
  static String modelFor(AiProviderType p) => 'ai_model_${p.id}';
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
  /// If [targetProvider] is specified, loads the stored profile for that provider.
  Future<AiConfig> loadConfig([AiProviderType? targetProvider]) async {
    final activeProviderId = await _settingsDao.get(AiSettingsKeys.provider);
    final activeProvider = AiProviderType.fromId(activeProviderId);
    final provider = targetProvider ?? activeProvider;

    // 1. Try provider-specific baseUrl, then fallback to global baseUrl (if provider matches active), then default
    final providerBaseUrl = await _settingsDao.get(AiSettingsKeys.baseUrlFor(provider));
    String? storedBaseUrl = providerBaseUrl;
    if ((storedBaseUrl == null || storedBaseUrl.isEmpty) && provider == activeProvider) {
      storedBaseUrl = await _settingsDao.get(AiSettingsKeys.baseUrl);
    }
    final baseUrl = (storedBaseUrl != null && storedBaseUrl.isNotEmpty)
        ? storedBaseUrl
        : provider.defaultBaseUrl;

    // 2. Try provider-specific model, then fallback to global model (if provider matches active), then default
    final providerModel = await _settingsDao.get(AiSettingsKeys.modelFor(provider));
    String? storedModel = providerModel;
    if ((storedModel == null || storedModel.isEmpty) && provider == activeProvider) {
      storedModel = await _settingsDao.get(AiSettingsKeys.model);
    }
    final model = (storedModel != null && storedModel.isNotEmpty)
        ? storedModel
        : provider.defaultModel;

    // 3. Read API key from secure store
    String? apiKey;
    try {
      apiKey = await _secureStore.read(AiSecureKeys.keyFor(provider));
      if ((apiKey == null || apiKey.isEmpty) && provider == activeProvider) {
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

  /// Checks if an API key is stored for [provider].
  Future<bool> hasKeyFor(AiProviderType provider) async {
    try {
      final key = await _secureStore.read(AiSecureKeys.keyFor(provider));
      if (key != null && key.isNotEmpty) return true;
      final activeProviderId = await _settingsDao.get(AiSettingsKeys.provider);
      if (activeProviderId == provider.id) {
        final defKey = await _secureStore.read(AiSecureKeys.defaultApiKey);
        return defKey != null && defKey.isNotEmpty;
      }
      return false;
    } catch (_) {
      return false;
    }
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
    await _settingsDao.set(AiSettingsKeys.baseUrlFor(config.provider), config.baseUrl);
    await _settingsDao.set(AiSettingsKeys.modelFor(config.provider), config.model);

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
  Future<AiPingResult> testConnection(AiConfig config, {String locale = 'zh'}) {
    return _aiClient.ping(config, locale: locale);
  }

  /// Fetches available models using [AiClient].
  Future<List<String>> fetchModels(AiConfig config, {String locale = 'zh'}) {
    return _aiClient.fetchModels(config, locale: locale);
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
  Future<AiPingResult> testConnection(AiConfig config, {String locale = 'zh'}) async {
    final service = ref.read(aiConfigServiceProvider);
    return service.testConnection(config, locale: locale);
  }
}
