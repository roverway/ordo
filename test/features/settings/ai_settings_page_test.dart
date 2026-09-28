import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ordo/core/ai/services/ai_client.dart';
import 'package:ordo/core/ai/services/ai_config_service.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/security/secure_store.dart';
import 'package:ordo/features/projects/project_providers.dart';
import 'package:ordo/features/settings/views/ai_settings_page.dart';

import '../../helpers/db_test_setup.dart';

class _FakeSecureStore implements SecureKeyValueStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

class _FakeAiHttpClient implements AiHttpClient {
  int responseStatus = 200;
  String responseBody = '{}';

  @override
  Future<AiHttpResponse> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return AiHttpResponse(statusCode: responseStatus, body: responseBody);
  }
}

Future<void> _pumpAiSettingsPage(
  WidgetTester tester, {
  required TodoRepository repo,
  required SecureKeyValueStore secureStore,
  required AiHttpClient httpClient,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final client = AiClient(httpClient: httpClient);
  final service = AiConfigService(
    settingsDao: repo.settings,
    secureStore: secureStore,
    aiClient: client,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todoRepositoryProvider.overrideWithValue(repo),
        aiClientProvider.overrideWithValue(client),
        aiConfigServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiSettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late TodoRepository repo;
  late _FakeSecureStore secureStore;
  late _FakeAiHttpClient httpClient;

  setUp(() {
    db = openTestDatabase();
    repo = TodoRepository(database: db);
    secureStore = _FakeSecureStore();
    httpClient = _FakeAiHttpClient();
  });

  tearDown(() async {
    await db.close();
  });

  group('AiSettingsPage UI & Interactions', () {
    testWidgets('renders default configuration properly', (tester) async {
      await _pumpAiSettingsPage(
        tester,
        repo: repo,
        secureStore: secureStore,
        httpClient: httpClient,
      );

      // Provider default DeepSeek
      expect(find.text('DeepSeek'), findsOneWidget);
      expect(find.text('https://api.deepseek.com'), findsOneWidget);
      expect(find.text('deepseek-chat'), findsOneWidget);
      expect(find.text('测试连接'), findsOneWidget);
      expect(find.text('保存配置'), findsOneWidget);
    });

    testWidgets(
      'AC-01: Displays masked API key when pre-configured and persists updates',
      (tester) async {
        await secureStore.write('ai_api_key_deepseek', 'sk-1234567890abcdef');

        await _pumpAiSettingsPage(
          tester,
          repo: repo,
          secureStore: secureStore,
          httpClient: httpClient,
        );

        // Verify masked key chip is rendered
        expect(find.text('sk-****cdef'), findsOneWidget);

        // Enter new API key and save
        final apiKeyField = find.widgetWithText(TextField, '更新密钥 (留空则保留原密钥)');
        expect(apiKeyField, findsOneWidget);
        await tester.enterText(apiKeyField, 'sk-999988887777newk');
        await tester.pumpAndSettle();

        await tester.tap(find.text('保存配置'));
        await tester.pumpAndSettle();

        // Verify updated in secure store
        final updatedKey = await secureStore.read('ai_api_key_deepseek');
        expect(updatedKey, equals('sk-999988887777newk'));
      },
    );

    testWidgets('AC-02: Test connection success displays latency badge', (
      tester,
    ) async {
      httpClient.responseStatus = 200;
      httpClient.responseBody = '{"choices":[]}';
      await secureStore.write('ai_api_key_deepseek', 'sk-valid-key');

      await _pumpAiSettingsPage(
        tester,
        repo: repo,
        secureStore: secureStore,
        httpClient: httpClient,
      );

      await tester.tap(find.text('测试连接'));
      await tester.pumpAndSettle();

      // Verify success badge contains '连接成功'
      expect(find.textContaining('连接成功'), findsOneWidget);
    });

    testWidgets(
      'AC-03: Test connection failure displays friendly diagnostic error message',
      (tester) async {
        httpClient.responseStatus = 401;
        httpClient.responseBody =
            '{"error":{"message":"Invalid API key provided"}}';
        await secureStore.write('ai_api_key_deepseek', 'sk-invalid-key');

        await _pumpAiSettingsPage(
          tester,
          repo: repo,
          secureStore: secureStore,
          httpClient: httpClient,
        );

        await tester.tap(find.text('测试连接'));
        await tester.pumpAndSettle();

        // Diagnostic message contains 401
        expect(find.textContaining('身份鉴权失败 (401)'), findsOneWidget);
      },
    );

    testWidgets('Switching provider updates default Base URL and Model', (
      tester,
    ) async {
      await _pumpAiSettingsPage(
        tester,
        repo: repo,
        secureStore: secureStore,
        httpClient: httpClient,
      );

      // Tap Dropdown to select GLM
      await tester.tap(find.text('DeepSeek'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('智谱 GLM').last);
      await tester.pumpAndSettle();

      expect(find.text('https://open.bigmodel.cn/api/paas/v4'), findsOneWidget);
      expect(find.text('glm-4-flash'), findsOneWidget);
    });
  });
}
