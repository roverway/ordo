import 'dart:convert';

import '../models/ai_config.dart';
import '../models/ai_task_parse_result.dart';
import '../prompts/task_parse_prompts.dart';
import 'ai_client.dart';
import 'ai_config_service.dart';

/// Service responsible for parsing natural language task inputs into structured [AiTaskParseResult].
class AiTaskParser {
  AiTaskParser({required AiClient aiClient, AiConfigService? configService})
    : _aiClient = aiClient,
      _configService = configService;

  final AiClient _aiClient;
  final AiConfigService? _configService;

  /// Extracts the innermost or outermost JSON object payload from raw LLM text,
  /// stripping code block fences (```json ... ```) and conversational banter.
  static String? extractJsonPayload(String response) {
    var text = response.trim();
    if (text.isEmpty) return null;

    // 1. Strip Markdown code fences if present
    final fenceRegex = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    );
    final match = fenceRegex.firstMatch(text);
    if (match != null && match.group(1) != null) {
      text = match.group(1)!.trim();
    }

    // 2. Locate the outermost curly braces { ... }
    final startIdx = text.indexOf('{');
    final endIdx = text.lastIndexOf('}');

    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return text.substring(startIdx, endIdx + 1);
    }

    return null;
  }

  /// Parses a raw LLM text response into [AiTaskParseResult].
  ///
  /// If extraction or JSON decoding fails and [originalInput] is provided,
  /// a safe fallback result is returned instead of throwing.
  AiTaskParseResult parseRawResponse(String response, {String? originalInput}) {
    final payload = extractJsonPayload(response);
    if (payload == null) {
      if (originalInput != null) {
        return AiTaskParseResult.fallback(originalInput, rawResponse: response);
      }
      throw FormatException(
        'No valid JSON object found in response: $response',
      );
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return AiTaskParseResult.fromJson(decoded, rawResponse: response);
      } else if (decoded is Map) {
        return AiTaskParseResult.fromJson(
          Map<String, dynamic>.from(decoded),
          rawResponse: response,
        );
      }
    } catch (_) {
      if (originalInput != null) {
        return AiTaskParseResult.fallback(originalInput, rawResponse: response);
      }
      rethrow;
    }

    if (originalInput != null) {
      return AiTaskParseResult.fallback(originalInput, rawResponse: response);
    }
    throw FormatException('Decoded payload is not a valid JSON map: $payload');
  }

  /// Invokes the LLM to parse user's natural language input into structured task elements.
  Future<AiTaskParseResult> parse(
    String input, {
    AiConfig? config,
    DateTime? now,
  }) async {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) {
      return const AiTaskParseResult(title: '新任务', isFallback: true);
    }

    final effectiveConfig = config ?? await _configService?.loadConfig();
    if (effectiveConfig == null || (effectiveConfig.apiKey?.isEmpty ?? true)) {
      return AiTaskParseResult.fallback(trimmedInput);
    }

    final systemPrompt = buildTaskParseSystemPrompt(now: now);
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': trimmedInput},
    ];

    try {
      final responseContent = await _aiClient.chat(effectiveConfig, messages);
      return parseRawResponse(responseContent, originalInput: trimmedInput);
    } catch (_) {
      // Gracefully fall back on network or parsing errors
      return AiTaskParseResult.fallback(trimmedInput);
    }
  }
}
