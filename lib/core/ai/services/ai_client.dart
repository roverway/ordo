import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/ai_config.dart';

/// Lightweight HTTP response representation for AI service communication.
class AiHttpResponse {
  const AiHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

/// Abstract HTTP client interface for AI requests (enables testing without network/mockito).
abstract class AiHttpClient {
  Future<AiHttpResponse> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  });

  Future<AiHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async => const AiHttpResponse(statusCode: 200, body: '{"data":[]}');
}

/// Production implementation of [AiHttpClient] using Dart's native `dart:io` [HttpClient].
class DefaultAiHttpClient implements AiHttpClient {
  const DefaultAiHttpClient();

  @override
  Future<AiHttpResponse> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final client = HttpClient();
    final effectiveTimeout = timeout ?? const Duration(seconds: 15);
    try {
      final request = await client.postUrl(uri).timeout(effectiveTimeout);
      if (headers != null) {
        headers.forEach((k, v) => request.headers.set(k, v));
      }
      if (body != null) {
        final bodyBytes = utf8.encode(body is String ? body : jsonEncode(body));
        request.headers.contentLength = bodyBytes.length;
        request.add(bodyBytes);
      }
      final response = await request.close().timeout(effectiveTimeout);
      final responseBody = await utf8
          .decodeStream(response)
          .timeout(effectiveTimeout);
      final responseHeaders = <String, String>{};
      response.headers.forEach((k, v) => responseHeaders[k] = v.join(','));
      return AiHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
        headers: responseHeaders,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<AiHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final client = HttpClient();
    final effectiveTimeout = timeout ?? const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri).timeout(effectiveTimeout);
      if (headers != null) {
        headers.forEach((k, v) => request.headers.set(k, v));
      }
      final response = await request.close().timeout(effectiveTimeout);
      final responseBody = await utf8
          .decodeStream(response)
          .timeout(effectiveTimeout);
      final responseHeaders = <String, String>{};
      response.headers.forEach((k, v) => responseHeaders[k] = v.join(','));
      return AiHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
        headers: responseHeaders,
      );
    } finally {
      client.close(force: true);
    }
  }
}

/// Structured diagnostic result of a ping connection test.
class AiPingResult {
  const AiPingResult({
    required this.isSuccess,
    required this.statusCode,
    required this.durationMs,
    this.errorMessage,
  });

  final bool isSuccess;
  final int statusCode;
  final int durationMs;
  final String? errorMessage;
}

/// Lightweight client for AI connectivity and protocol communication.
class AiClient {
  AiClient({AiHttpClient? httpClient})
    : _httpClient = httpClient ?? const DefaultAiHttpClient();

  final AiHttpClient _httpClient;

  /// Normalizes target endpoint URL for model enumeration.
  Uri normalizeModelsEndpoint(AiConfig config) {
    var rawUrl = config.baseUrl.trim();
    if (rawUrl.endsWith('/')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - 1);
    }
    if (rawUrl.endsWith('/chat/completions')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - '/chat/completions'.length);
    } else if (rawUrl.endsWith('/messages')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - '/messages'.length);
    }
    if (rawUrl.endsWith('/')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - 1);
    }
    if (!rawUrl.endsWith('/models')) {
      rawUrl = '$rawUrl/models';
    }
    return Uri.parse(rawUrl);
  }

  /// Probes the endpoint and fetches available model list.
  Future<List<String>> fetchModels(
    AiConfig config, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final endpoint = normalizeModelsEndpoint(config);
    final Map<String, String> headers;
    if (config.provider == AiProviderType.claude) {
      headers = {
        'x-api-key': config.apiKey ?? '',
        'anthropic-version': '2023-06-01',
      };
    } else {
      headers = {
        'Authorization': 'Bearer ${config.apiKey ?? ''}',
      };
    }

    final response = await _httpClient.get(
      endpoint,
      headers: headers,
      timeout: timeout,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        final List<dynamic>? rawList = decoded is Map<String, dynamic>
            ? (decoded['data'] as List<dynamic>? ?? decoded['models'] as List<dynamic>?)
            : (decoded is List<dynamic> ? decoded : null);

        if (rawList != null) {
          final models = <String>[];
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              final id = item['id']?.toString() ??
                  item['name']?.toString() ??
                  item['model']?.toString();
              if (id != null && id.trim().isNotEmpty) {
                models.add(id.trim());
              }
            } else if (item is String && item.trim().isNotEmpty) {
              models.add(item.trim());
            }
          }
          if (models.isNotEmpty) {
            models.sort();
            return models;
          }
        }
      } catch (_) {
        // Fallback or diagnostic below
      }
    }

    final errorMsg = _diagnoseError(
      response.statusCode,
      response.body,
      config.apiKey,
    );
    throw HttpException(
      '探测模型失败 (HTTP ${response.statusCode}): $errorMsg',
      uri: endpoint,
    );
  }

  /// Normalizes target endpoint URL based on provider type and base URL.
  Uri normalizeEndpoint(AiConfig config) {
    var rawUrl = config.baseUrl.trim();
    if (rawUrl.endsWith('/')) {
      rawUrl = rawUrl.substring(0, rawUrl.length - 1);
    }

    if (config.provider == AiProviderType.claude) {
      if (!rawUrl.endsWith('/messages')) {
        rawUrl = '$rawUrl/messages';
      }
    } else {
      // OpenAI compatible (deepseek, glm, openai, custom)
      if (!rawUrl.endsWith('/chat/completions')) {
        rawUrl = '$rawUrl/chat/completions';
      }
    }
    return Uri.parse(rawUrl);
  }

  /// Sends a minimal ping request to test network connectivity and authentication.
  Future<AiPingResult> ping(
    AiConfig config, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final endpoint = normalizeEndpoint(config);
      final Map<String, String> headers;
      final Map<String, dynamic> body;

      if (config.provider == AiProviderType.claude) {
        headers = {
          'x-api-key': config.apiKey ?? '',
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        };
        body = {
          'model': config.model,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 1,
        };
      } else {
        headers = {
          'Authorization': 'Bearer ${config.apiKey ?? ''}',
          'Content-Type': 'application/json',
        };
        body = {
          'model': config.model,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 1,
        };
      }

      final response = await _httpClient.post(
        endpoint,
        headers: headers,
        body: jsonEncode(body),
        timeout: timeout,
      );

      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AiPingResult(
          isSuccess: true,
          statusCode: response.statusCode,
          durationMs: durationMs,
        );
      }

      // Diagnose non-2xx statuses
      final errorMsg = _diagnoseError(
        response.statusCode,
        response.body,
        config.apiKey,
      );
      return AiPingResult(
        isSuccess: false,
        statusCode: response.statusCode,
        durationMs: durationMs,
        errorMessage: errorMsg,
      );
    } on TimeoutException {
      stopwatch.stop();
      return AiPingResult(
        isSuccess: false,
        statusCode: 0,
        durationMs: stopwatch.elapsedMilliseconds,
        errorMessage: '网络连接超时 (15s)，请检查网络或代理设置',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return AiPingResult(
        isSuccess: false,
        statusCode: 0,
        durationMs: stopwatch.elapsedMilliseconds,
        errorMessage: '网络不可达 (${e.osError?.message ?? e.message})，请检查网络或代理设置',
      );
    } catch (e) {
      stopwatch.stop();
      return AiPingResult(
        isSuccess: false,
        statusCode: 0,
        durationMs: stopwatch.elapsedMilliseconds,
        errorMessage: '网络连接异常: $e',
      );
    }
  }

  /// Sends a chat completion request to the configured AI provider.
  Future<String> chat(
    AiConfig config,
    List<Map<String, String>> messages, {
    double temperature = 0.2,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final endpoint = normalizeEndpoint(config);
    final Map<String, String> headers;
    final Map<String, dynamic> body;

    if (config.provider == AiProviderType.claude) {
      headers = {
        'x-api-key': config.apiKey ?? '',
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      };
      final systemMessages = messages
          .where((m) => m['role'] == 'system')
          .toList();
      final nonSystemMessages = messages
          .where((m) => m['role'] != 'system')
          .toList();
      body = {
        'model': config.model,
        if (systemMessages.isNotEmpty)
          'system': systemMessages.map((m) => m['content']).join('\n\n'),
        'messages': nonSystemMessages
            .map((m) => {'role': m['role'], 'content': m['content']})
            .toList(),
        'max_tokens': 2048,
        'temperature': temperature,
      };
    } else {
      headers = {
        'Authorization': 'Bearer ${config.apiKey ?? ''}',
        'Content-Type': 'application/json',
      };
      body = {
        'model': config.model,
        'messages': messages,
        'temperature': temperature,
      };
    }

    final response = await _httpClient.post(
      endpoint,
      headers: headers,
      body: jsonEncode(body),
      timeout: timeout,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (config.provider == AiProviderType.claude) {
            final content = decoded['content'];
            if (content is List && content.isNotEmpty) {
              final first = content.first;
              if (first is Map && first['text'] != null) {
                return first['text'].toString();
              }
            }
          } else {
            final choices = decoded['choices'];
            if (choices is List && choices.isNotEmpty) {
              final first = choices.first;
              if (first is Map && first['message'] is Map) {
                final msg = first['message'] as Map;
                return msg['content']?.toString() ?? '';
              }
            }
          }
        }
        return response.body;
      } on FormatException {
        throw Exception('服务商响应解析失败：返回了非 JSON 格式内容（可能是反向代理或网关错误页）');
      }
    }

    throw Exception(
      _diagnoseError(response.statusCode, response.body, config.apiKey),
    );
  }

  String _diagnoseError(int statusCode, String responseBody, String? apiKey) {
    String detail = '';
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        if (decoded['error'] is Map) {
          detail = decoded['error']['message']?.toString() ?? '';
        } else if (decoded['error'] is String) {
          detail = decoded['error'].toString();
        } else if (decoded['message'] != null) {
          detail = decoded['message'].toString();
        }
      }
    } catch (_) {
      detail = responseBody.trim();
    }

    // Mask sensitive key if echoed back in error response
    if (apiKey != null && apiKey.isNotEmpty && detail.contains(apiKey)) {
      detail = detail.replaceAll(apiKey, '***');
    }

    switch (statusCode) {
      case 401:
        return '身份鉴权失败 (401)：${detail.isNotEmpty ? detail : "请检查 API Key 是否有效"}';
      case 403:
        return '访问权限受限 (403)：${detail.isNotEmpty ? detail : "请确认该账号或密钥具备模型调用权限"}';
      case 404:
        return '接口端点未找到 (404)：请检查 Base URL 是否正确';
      case 429:
        return '请求频率超限或余额不足 (429)：${detail.isNotEmpty ? detail : "请检查账户配额"}';
      case 500:
      case 502:
      case 503:
      case 504:
        return '服务商服务器异常 ($statusCode)：${detail.isNotEmpty ? detail : "请稍后重试"}';
      default:
        return 'HTTP $statusCode 异常${detail.isNotEmpty ? ": $detail" : ""}';
    }
  }
}
