import 'dart:convert';
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

  @override
  Future<AiHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
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
  Locale locale = const Locale('zh'),
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
      child: MaterialApp(
        locale: locale,
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

    testWidgets(
      'Action buttons (测试连接, 保存配置) are placed side-by-side in a single Row',
      (tester) async {
        await _pumpAiSettingsPage(
          tester,
          repo: repo,
          secureStore: secureStore,
          httpClient: httpClient,
        );

        final testBtn = find.text('测试连接');
        final saveBtn = find.text('保存配置');

        expect(testBtn, findsOneWidget);
        expect(saveBtn, findsOneWidget);

        final testCenter = tester.getCenter(testBtn);
        final saveCenter = tester.getCenter(saveBtn);

        // They must share approximately the same Y-coordinate (within 2px) and test button is to the left of save button
        expect((testCenter.dy - saveCenter.dy).abs(), lessThan(2.0));
        expect(testCenter.dx, lessThan(saveCenter.dx));
      },
    );

    testWidgets('Switching to Kimi and Alibaba Qwen updates presets properly', (
      tester,
    ) async {
      await _pumpAiSettingsPage(
        tester,
        repo: repo,
        secureStore: secureStore,
        httpClient: httpClient,
      );

      // Switch to Kimi
      await tester.tap(find.text('DeepSeek'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Kimi').last);
      await tester.pumpAndSettle();

      expect(find.text('https://api.moonshot.cn/v1'), findsOneWidget);
      expect(find.text('moonshot-v1-8k'), findsOneWidget);

      // Switch to Qwen
      await tester.tap(find.textContaining('Kimi').first);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('阿里通义千问').last);
      await tester.pumpAndSettle();

      expect(find.text('qwen-plus'), findsOneWidget);
    });

    testWidgets(
      'Probe models button triggers model discovery and opens picker',
      (tester) async {
        httpClient.responseStatus = 200;
        httpClient.responseBody = jsonEncode({
          'data': [
            {'id': 'custom-probed-model-v1'},
            {'id': 'custom-probed-model-v2'},
          ],
        });

        await _pumpAiSettingsPage(
          tester,
          repo: repo,
          secureStore: secureStore,
          httpClient: httpClient,
        );

        // Input API Key first so probe is allowed
        await tester.enterText(
          find.widgetWithText(TextField, 'API Key'),
          'sk-test-probe-key',
        );
        await tester.pumpAndSettle();

        // Tap probe models button
        await tester.tap(find.byIcon(Icons.radar_outlined));
        await tester.pumpAndSettle();

        // Verify model picker sheet is displayed with probed model
        expect(find.text('选择模型 (DeepSeek)'), findsOneWidget);
        expect(find.text('custom-probed-model-v1'), findsOneWidget);

        // Tap probed model to select it
        await tester.tap(find.text('custom-probed-model-v1'));
        await tester.pumpAndSettle();

        // Verify model textfield is updated
        expect(find.text('custom-probed-model-v1'), findsOneWidget);
      },
    );

    testWidgets(
      'renders properly under English locale with no hardcoded Chinese',
      (tester) async {
        await _pumpAiSettingsPage(
          tester,
          repo: repo,
          secureStore: secureStore,
          httpClient: httpClient,
          locale: const Locale('en'),
        );

        // Verify English labels
        expect(find.text('DeepSeek'), findsOneWidget);
        expect(find.text('https://api.deepseek.com'), findsOneWidget);
        expect(find.text('deepseek-chat'), findsOneWidget);
        expect(find.text('Test Connection'), findsOneWidget);
        expect(find.text('Save Settings'), findsOneWidget);
        expect(find.text('AI Assistant Settings'), findsOneWidget);
        expect(find.text('Provider'), findsOneWidget);
        expect(find.text('Model Name'), findsOneWidget);

        // Assert no Chinese text in widget tree
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        final chineseRegex = RegExp(r'[一-龥]');
        for (final widget in textWidgets) {
          final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
          expect(
            chineseRegex.hasMatch(text),
            isFalse,
            reason: 'Found unexpected Chinese text in English locale: "$text"',
          );
        }
      },
    );

    testWidgets('MCP External Integration switch can be toggled on/off', (
      tester,
    ) async {
      await _pumpAiSettingsPage(
        tester,
        repo: repo,
        secureStore: secureStore,
        httpClient: httpClient,
      );

      // Verify MCP card exists
      expect(find.text('MCP 外部集成 (Model Context Protocol)'), findsOneWidget);

      // Initially off, no endpoint URL displayed
      expect(find.text('端点地址'), findsNothing);

      // Toggle switch to ON
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      var switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);

      switchWidget.onChanged!(true);
      await tester.pumpAndSettle();

      // Now running, endpoint URL is displayed
      expect(find.text('服务运行中'), findsOneWidget);
      expect(find.text('端点地址'), findsOneWidget);
      expect(find.textContaining('http://127.0.0.1:'), findsOneWidget);

      // Toggle switch back to OFF
      switchWidget = tester.widget<Switch>(switchFinder);
      switchWidget.onChanged!(false);
      await tester.pumpAndSettle();

      // Endpoint URL disappeared
      expect(find.text('端点地址'), findsNothing);
      expect(find.text('未启动'), findsNothing);
    });
  });
}
