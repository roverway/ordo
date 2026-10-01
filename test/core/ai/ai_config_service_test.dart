import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/ai_config.dart';
import 'package:ordo/core/ai/services/ai_config_service.dart';
import 'package:ordo/core/db/daos/settings_dao.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/security/secure_store.dart';

import '../../helpers/db_test_setup.dart';

class _InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }
}

void main() {
  late AppDatabase db;
  late SettingsDao settingsDao;
  late _InMemorySecureStore secureStore;
  late AiConfigService configService;

  setUp(() {
    db = openTestDatabase();
    settingsDao = SettingsDao(db);
    secureStore = _InMemorySecureStore();
    configService = AiConfigService(
      settingsDao: settingsDao,
      secureStore: secureStore,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('AiConfig & Provider defaults', () {
    test('Default provider has valid baseUrl and model', () {
      expect(
        AiProviderType.deepseek.defaultBaseUrl,
        'https://api.deepseek.com',
      );
      expect(AiProviderType.deepseek.defaultModel, 'deepseek-chat');
      expect(AiProviderType.kimi.defaultBaseUrl, 'https://api.moonshot.cn/v1');
      expect(AiProviderType.kimi.defaultModel, 'moonshot-v1-8k');
      expect(
        AiProviderType.qwen.defaultBaseUrl,
        contains('dashscope.aliyuncs.com'),
      );
      expect(AiProviderType.qwen.defaultModel, 'qwen-plus');
      expect(AiProviderType.glm.defaultBaseUrl, contains('bigmodel.cn'));
      expect(AiProviderType.openai.defaultBaseUrl, contains('api.openai.com'));
      expect(
        AiProviderType.claude.defaultBaseUrl,
        contains('api.anthropic.com'),
      );
    });

    test('Masked API key handles long, short and null keys', () {
      const config1 = AiConfig(
        provider: AiProviderType.deepseek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'sk-1234567890abcdef',
      );
      expect(config1.maskedApiKey, 'sk-****cdef');

      const configShort = AiConfig(
        provider: AiProviderType.deepseek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'sk-1234',
      );
      expect(configShort.maskedApiKey, 'sk-****');

      const configEmpty = AiConfig(
        provider: AiProviderType.deepseek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: '',
      );
      expect(configEmpty.maskedApiKey, '');

      const configNull = AiConfig(
        provider: AiProviderType.deepseek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
      );
      expect(configNull.maskedApiKey, '');
    });
  });

  group('AiConfigService persistence isolation', () {
    test('loadConfig returns default config when database is empty', () async {
      final config = await configService.loadConfig();
      expect(config.provider, AiProviderType.deepseek);
      expect(config.baseUrl, AiProviderType.deepseek.defaultBaseUrl);
      expect(config.model, AiProviderType.deepseek.defaultModel);
      expect(config.apiKey, isNull);
    });

    test(
      'saveConfig isolates API key in secure store and non-sensitive in settingsDao',
      () async {
        const configToSave = AiConfig(
          provider: AiProviderType.glm,
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          model: 'glm-4-flash',
          apiKey: 'glm-secret-key-123456',
        );

        await configService.saveConfig(configToSave);

        // Verify non-sensitive stored in Drift settingsDao
        final allSettings = await settingsDao.getAll();
        expect(allSettings['ai_provider'], 'glm');
        expect(
          allSettings['ai_base_url'],
          'https://open.bigmodel.cn/api/paas/v4',
        );
        expect(allSettings['ai_model'], 'glm-4-flash');

        // Verify API Key NOT in settingsDao
        expect(
          allSettings.values.any((val) => val.contains('glm-secret-key')),
          isFalse,
        );
        expect(allSettings.containsKey('ai_api_key'), isFalse);

        // Verify API Key in secureStore
        final secureKey = await secureStore.read('ai_api_key_glm');
        expect(secureKey, 'glm-secret-key-123456');

        // Now reload via configService
        final loaded = await configService.loadConfig();
        expect(loaded.provider, AiProviderType.glm);
        expect(loaded.baseUrl, 'https://open.bigmodel.cn/api/paas/v4');
        expect(loaded.model, 'glm-4-flash');
        expect(loaded.apiKey, 'glm-secret-key-123456');
        expect(loaded.maskedApiKey, 'gl****3456');
      },
    );

    test(
      'saveConfig without changing apiKey preserves existing secure apiKey',
      () async {
        const initial = AiConfig(
          provider: AiProviderType.deepseek,
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat',
          apiKey: 'sk-initial-secret-key',
        );
        await configService.saveConfig(initial);

        // Save new baseUrl without providing apiKey
        const updated = AiConfig(
          provider: AiProviderType.deepseek,
          baseUrl: 'https://custom-proxy.deepseek.com',
          model: 'deepseek-coder',
        );
        await configService.saveConfig(updated);

        final loaded = await configService.loadConfig();
        expect(loaded.baseUrl, 'https://custom-proxy.deepseek.com');
        expect(loaded.model, 'deepseek-coder');
        expect(loaded.apiKey, 'sk-initial-secret-key');
      },
    );

    test('clearApiKey removes key from secure storage', () async {
      const config = AiConfig(
        provider: AiProviderType.openai,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'sk-openai-key',
      );
      await configService.saveConfig(config);
      expect(await secureStore.read('ai_api_key_openai'), 'sk-openai-key');

      await configService.clearApiKey(AiProviderType.openai);
      expect(await secureStore.read('ai_api_key_openai'), isNull);

      final loaded = await configService.loadConfig();
      expect(loaded.apiKey, isNull);
    });

    test(
      'supports independent multi-provider configuration and switching',
      () async {
        // Configure DeepSeek
        const deepseekConfig = AiConfig(
          provider: AiProviderType.deepseek,
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat',
          apiKey: 'sk-deepseek-key-12345',
        );
        await configService.saveConfig(deepseekConfig);

        // Configure Kimi
        const kimiConfig = AiConfig(
          provider: AiProviderType.kimi,
          baseUrl: 'https://api.moonshot.cn/v1',
          model: 'moonshot-v1-32k',
          apiKey: 'sk-kimi-key-67890',
        );
        await configService.saveConfig(kimiConfig);

        // Now active provider is Kimi
        final active = await configService.loadConfig();
        expect(active.provider, AiProviderType.kimi);
        expect(active.model, 'moonshot-v1-32k');
        expect(active.apiKey, 'sk-kimi-key-67890');

        // Load DeepSeek profile explicitly without changing active provider
        final loadedDeepSeek = await configService.loadConfig(
          AiProviderType.deepseek,
        );
        expect(loadedDeepSeek.provider, AiProviderType.deepseek);
        expect(loadedDeepSeek.model, 'deepseek-chat');
        expect(loadedDeepSeek.apiKey, 'sk-deepseek-key-12345');

        // Both keys exist in secure store
        expect(await configService.hasKeyFor(AiProviderType.deepseek), isTrue);
        expect(await configService.hasKeyFor(AiProviderType.kimi), isTrue);
        expect(await configService.hasKeyFor(AiProviderType.claude), isFalse);
      },
    );
  });
}
