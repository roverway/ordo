import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/ai_config.dart';
import 'package:ordo/core/ai/services/ai_client.dart';

class _FakeAiHttpClient implements AiHttpClient {
  _FakeAiHttpClient(this.handler, {this.getHandler});

  final Future<AiHttpResponse> Function(
    Uri uri,
    Map<String, String> headers,
    Object? body,
  )
  handler;

  final Future<AiHttpResponse> Function(
    Uri uri,
    Map<String, String> headers,
  )? getHandler;

  final List<({Uri uri, Map<String, String> headers, String body})>
  recordedRequests = [];

  @override
  Future<AiHttpResponse> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    recordedRequests.add((
      uri: uri,
      headers: headers ?? {},
      body: body is String ? body : (body != null ? jsonEncode(body) : ''),
    ));
    return handler(uri, headers ?? {}, body);
  }

  @override
  Future<AiHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    if (getHandler != null) {
      return getHandler!(uri, headers ?? {});
    }
    return const AiHttpResponse(statusCode: 200, body: '{"data":[]}');
  }
}

void main() {
  group('OpenAI Compatible Ping', () {
    test(
      'Successful ping returns isSuccess true and records latency',
      () async {
        final fakeClient = _FakeAiHttpClient((uri, headers, body) async {
          return const AiHttpResponse(
            statusCode: 200,
            body: '{"choices":[{"message":{"content":"pong"}}]}',
          );
        });

        final client = AiClient(httpClient: fakeClient);
        const config = AiConfig(
          provider: AiProviderType.deepseek,
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat',
          apiKey: 'sk-deepseek-test-key',
        );

        final result = await client.ping(config);

        expect(result.isSuccess, isTrue);
        expect(result.statusCode, 200);
        expect(result.errorMessage, isNull);
        expect(result.durationMs, greaterThanOrEqualTo(0));

        // Check request details
        expect(fakeClient.recordedRequests.length, 1);
        final req = fakeClient.recordedRequests.first;
        expect(req.uri.toString(), 'https://api.deepseek.com/chat/completions');
        expect(req.headers['Authorization'], 'Bearer sk-deepseek-test-key');
        expect(req.headers['Content-Type'], 'application/json');

        final bodyMap = jsonDecode(req.body) as Map<String, dynamic>;
        expect(bodyMap['model'], 'deepseek-chat');
        expect(bodyMap['max_tokens'], 1);
      },
    );

    test('Url normalization handles trailing slash and /v1 properly', () async {
      final fakeClient = _FakeAiHttpClient((uri, headers, body) async {
        return const AiHttpResponse(statusCode: 200, body: '{}');
      });

      final client = AiClient(httpClient: fakeClient);

      // Trailing slash
      await client.ping(
        const AiConfig(
          provider: AiProviderType.openai,
          baseUrl: 'https://api.openai.com/v1/',
          model: 'gpt-4o-mini',
          apiKey: 'key',
        ),
      );
      expect(
        fakeClient.recordedRequests.last.uri.toString(),
        'https://api.openai.com/v1/chat/completions',
      );

      // Full endpoint already specified
      await client.ping(
        const AiConfig(
          provider: AiProviderType.custom,
          baseUrl: 'https://my-custom.ai/v1/chat/completions',
          model: 'llama3',
          apiKey: 'key',
        ),
      );
      expect(
        fakeClient.recordedRequests.last.uri.toString(),
        'https://my-custom.ai/v1/chat/completions',
      );
    });

    test(
      '401 Authentication Failure returns structured error diagnostic',
      () async {
        final fakeClient = _FakeAiHttpClient((uri, headers, body) async {
          return const AiHttpResponse(
            statusCode: 401,
            body: '{"error": {"message": "Invalid API Key"}}',
          );
        });

        final client = AiClient(httpClient: fakeClient);
        const config = AiConfig(
          provider: AiProviderType.glm,
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          model: 'glm-4-flash',
          apiKey: 'bad-key',
        );

        final result = await client.ping(config);

        expect(result.isSuccess, isFalse);
        expect(result.statusCode, 401);
        expect(result.errorMessage, contains('401'));
        // Ensure raw key is NOT in error message
        expect(result.errorMessage?.contains('bad-key'), isFalse);
      },
    );

    test('404 Endpoint Not Found returns structured diagnostic', () async {
      final fakeClient = _FakeAiHttpClient((uri, headers, body) async {
        return const AiHttpResponse(
          statusCode: 404,
          body: '{"error": "Not Found"}',
        );
      });

      final client = AiClient(httpClient: fakeClient);
      const config = AiConfig(
        provider: AiProviderType.custom,
        baseUrl: 'https://invalid-host.com/wrong/path',
        model: 'm',
        apiKey: 'key',
      );

      final result = await client.ping(config);

      expect(result.isSuccess, isFalse);
      expect(result.statusCode, 404);
      expect(result.errorMessage, contains('404'));
    });

    test(
      'Network SocketException is handled safely without crashing',
      () async {
        final fakeClient = _FakeAiHttpClient((uri, headers, body) async {
          throw const SocketException('Failed host lookup');
        });

        final client = AiClient(httpClient: fakeClient);
        const config = AiConfig(
          provider: AiProviderType.deepseek,
          baseUrl: 'https://api.deepseek.com',
          model: 'deepseek-chat',
          apiKey: 'key',
        );

        final result = await client.ping(config);

        expect(result.isSuccess, isFalse);
        expect(result.statusCode, 0);
        expect(result.errorMessage, isNotNull);
      },
    );

    test('TimeoutException is handled safely and reports timeout', () async {
      final fakeClient = _FakeAiHttpClient((uri, headers, body) async {
        throw TimeoutException('Request timed out');
      });

      final client = AiClient(httpClient: fakeClient);
      const config = AiConfig(
        provider: AiProviderType.deepseek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'key',
      );

      final result = await client.ping(config);

      expect(result.isSuccess, isFalse);
      expect(result.statusCode, 0);
      expect(result.errorMessage, isNotNull);
    });
  });

  group('Claude (Anthropic) Ping', () {
    test('Claude protocol uses x-api-key and /messages endpoint', () async {
      final fakeClient = _FakeAiHttpClient((uri, headers, body) async {
        return const AiHttpResponse(
          statusCode: 200,
          body: '{"content":[{"text":"pong"}]}',
        );
      });

      final client = AiClient(httpClient: fakeClient);
      const config = AiConfig(
        provider: AiProviderType.claude,
        baseUrl: 'https://api.anthropic.com/v1',
        model: 'claude-3-5-haiku-20241022',
        apiKey: 'sk-ant-test-key',
      );

      final result = await client.ping(config);

      expect(result.isSuccess, isTrue);
      expect(result.statusCode, 200);

      expect(fakeClient.recordedRequests.length, 1);
      final req = fakeClient.recordedRequests.first;
      expect(req.uri.toString(), 'https://api.anthropic.com/v1/messages');
      expect(req.headers['x-api-key'], 'sk-ant-test-key');
      expect(req.headers['anthropic-version'], '2023-06-01');
      expect(req.headers['content-type'], 'application/json');

      final bodyMap = jsonDecode(req.body) as Map<String, dynamic>;
      expect(bodyMap['model'], 'claude-3-5-haiku-20241022');
      expect(bodyMap['max_tokens'], 1);
    });
  });

  group('Models probing & endpoint normalization', () {
    test('normalizeModelsEndpoint formats base url with /models suffix', () {
      final client = AiClient();
      expect(
        client.normalizeModelsEndpoint(
          const AiConfig(
            provider: AiProviderType.deepseek,
            baseUrl: 'https://api.deepseek.com',
            model: 'deepseek-chat',
          ),
        ),
        Uri.parse('https://api.deepseek.com/models'),
      );

      expect(
        client.normalizeModelsEndpoint(
          const AiConfig(
            provider: AiProviderType.openai,
            baseUrl: 'https://api.openai.com/v1/chat/completions',
            model: 'gpt-4o',
          ),
        ),
        Uri.parse('https://api.openai.com/v1/models'),
      );
    });

    test('fetchModels parses OpenAI style models JSON payload', () async {
      final fakeClient = _FakeAiHttpClient(
        (uri, headers, body) async => const AiHttpResponse(statusCode: 200, body: '{}'),
        getHandler: (uri, headers) async {
          return AiHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': [
                {'id': 'moonshot-v1-8k'},
                {'id': 'moonshot-v1-32k'},
                {'id': 'moonshot-v1-128k'},
              ],
            }),
          );
        },
      );

      final client = AiClient(httpClient: fakeClient);
      final models = await client.fetchModels(
        const AiConfig(
          provider: AiProviderType.kimi,
          baseUrl: 'https://api.moonshot.cn/v1',
          model: 'moonshot-v1-8k',
          apiKey: 'test-key',
        ),
      );

      expect(models, ['moonshot-v1-128k', 'moonshot-v1-32k', 'moonshot-v1-8k']);
    });
  });

  group('PooledAiHttpClient connection pooling', () {
    test('PooledAiHttpClient closes cached client safely', () {
      final pool = PooledAiHttpClient(idleTimeout: const Duration(seconds: 10));
      expect(() => pool.close(), returnsNormally);
      expect(() => pool.close(force: true), returnsNormally);
    });

    test('AiClient.dispose releases underlying PooledAiHttpClient safely', () {
      final client = AiClient();
      expect(() => client.dispose(), returnsNormally);
    });
  });
}
