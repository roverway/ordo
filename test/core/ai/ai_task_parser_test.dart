import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/ai_config.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/ai/services/ai_client.dart';
import 'package:ordo/core/ai/services/ai_task_parser.dart';

class _FakeAiHttpClient implements AiHttpClient {
  _FakeAiHttpClient(this.handler);

  final Future<AiHttpResponse> Function(
    Uri uri,
    Map<String, String> headers,
    Object? body,
  )
  handler;
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
    return const AiHttpResponse(statusCode: 200, body: '{"data":[]}');
  }
}

void main() {
  group('AiTaskParser JSON Extraction & Sanitization', () {
    test('extracts clean payload from standard JSON', () {
      const raw = '{"title": "完成周报", "priority": 2}';
      final extracted = AiTaskParser.extractJsonPayload(raw);
      expect(extracted, '{"title": "完成周报", "priority": 2}');
    });

    test('extracts JSON enclosed in markdown code fences', () {
      const raw = '''
```json
{
  "title": "购买办公用品",
  "priority": 1,
  "tags": ["行政"]
}
```
''';
      final extracted = AiTaskParser.extractJsonPayload(raw);
      expect(extracted, isNotNull);
      final decoded = jsonDecode(extracted!) as Map<String, dynamic>;
      expect(decoded['title'], '购买办公用品');
      expect(decoded['priority'], 1);
    });

    test(
      'AC-04: strips conversational prefix and suffix interference text',
      () {
        const raw = '''
好的，这是为您解析的任务要素：
{
  "title": "开周会",
  "dueAt": 1727510400000,
  "tags": ["工作"],
  "priority": 2
}
祝您工作顺利，如有需要随时告诉我！
''';
        final extracted = AiTaskParser.extractJsonPayload(raw);
        expect(extracted, isNotNull);
        final decoded = jsonDecode(extracted!) as Map<String, dynamic>;
        expect(decoded['title'], '开周会');
        expect(decoded['dueAt'], 1727510400000);
        expect(decoded['tags'], ['工作']);
        expect(decoded['priority'], 2);
      },
    );

    test('robustly handles trailing explanation with brackets and special characters', () {
      const raw = '''
解析结果如下：
{
  "title": "购买日用品",
  "priority": 1,
  "subtasks": [{"title": "买牙膏"}, {"title": "买毛巾"}]
}
请注意：格式说明中不要包含 {} 符号，以及示例说明 "test";
''';
      final extracted = AiTaskParser.extractJsonPayload(raw);
      expect(extracted, isNotNull);
      final decoded = jsonDecode(extracted!) as Map<String, dynamic>;
      expect(decoded['title'], '购买日用品');
      expect(decoded['priority'], 1);
      expect((decoded['subtasks'] as List).length, 2);
    });

    test('returns null when no JSON object is found', () {
      const raw = '今天天气不错，我只是随口一说。';
      final extracted = AiTaskParser.extractJsonPayload(raw);
      expect(extracted, isNull);
    });
  });

  group('AiTaskParseResult deserialization & validation', () {
    test('parses full payload correctly', () {
      final json = {
        'title': ' 季度复盘会 ',
        'description': '回顾 Q3 目标完成度',
        'priority': 3,
        'startAt': 1727500800000,
        'dueAt': 1727533200000,
        'tags': ['重要', '复盘', '复盘'],
        'substeps': [
          {'title': '整理核心指标', 'sortOrder': 0},
          {'title': '起草 PPT', 'sortOrder': 1},
        ],
      };

      final result = AiTaskParseResult.fromJson(json);

      expect(result.title, '季度复盘会');
      expect(result.description, '回顾 Q3 目标完成度');
      expect(result.priority, 3);
      expect(result.startAt, 1727500800000);
      expect(result.dueAt, 1727533200000);
      expect(result.endAt, 1727533200000);
      expect(result.tags, ['重要', '复盘']); // Deduplicated
      expect(result.substeps.length, 2);
      expect(result.substeps.first.title, '整理核心指标');
      expect(result.substeps.first.sortOrder, 0);
      expect(result.isFallback, isFalse);
    });

    test('clamps invalid priority into 0-3 range', () {
      expect(
        AiTaskParseResult.fromJson({'title': 'T', 'priority': -1}).priority,
        0,
      );
      expect(
        AiTaskParseResult.fromJson({'title': 'T', 'priority': 99}).priority,
        3,
      );
    });

    test('truncates title longer than 200 characters', () {
      final longTitle = 'a' * 250;
      final result = AiTaskParseResult.fromJson({'title': longTitle});
      expect(result.title.length, 200);
    });

    test('fallback factory produces valid fallback parse result', () {
      final fallback = AiTaskParseResult.fallback('帮我买杯咖啡');
      expect(fallback.title, '帮我买杯咖啡');
      expect(fallback.isFallback, isTrue);
      expect(fallback.priority, 0);
      expect(fallback.substeps, isEmpty);
    });
  });

  group('AiTaskParser.parse with AiClient', () {
    const config = AiConfig(
      provider: AiProviderType.deepseek,
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
      apiKey: 'sk-test',
    );

    test(
      'AC-01: parses single task elements accurately without substeps',
      () async {
        final fakeHttp = _FakeAiHttpClient((uri, headers, body) async {
          return const AiHttpResponse(
            statusCode: 200,
            body: '''
{
  "choices": [
    {
      "message": {
        "content": "{\\"title\\": \\"开周会\\", \\"dueAt\\": 1727510400000, \\"priority\\": 2, \\"tags\\": [\\"工作\\"], \\"substeps\\": []}"
      }
    }
  ]
}
''',
          );
        });

        final aiClient = AiClient(httpClient: fakeHttp);
        final parser = AiTaskParser(aiClient: aiClient);

        final result = await parser.parse('周五下午4点开周会 #工作', config: config);

        expect(result.title, '开周会');
        expect(result.tags, contains('工作'));
        expect(result.dueAt, 1727510400000);
        expect(result.substeps, isEmpty);
        expect(result.isFallback, isFalse);
      },
    );

    test('AC-02: parses task with 3-5 breakdown substeps', () async {
      final fakeHttp = _FakeAiHttpClient((uri, headers, body) async {
        return const AiHttpResponse(
          statusCode: 200,
          body: '''
{
  "choices": [
    {
      "message": {
        "content": "```json\\n{\\"title\\": \\"写完项目周报\\", \\"dueAt\\": 1727496000000, \\"priority\\": 2, \\"tags\\": [\\"工作\\"], \\"substeps\\": [{\\"title\\": \\"收集数据\\", \\"sortOrder\\": 0}, {\\"title\\": \\"起草内容\\", \\"sortOrder\\": 1}, {\\"title\\": \\"校对发送\\", \\"sortOrder\\": 2}]}\\n```"
      }
    }
  ]
}
''',
        );
      });

      final aiClient = AiClient(httpClient: fakeHttp);
      final parser = AiTaskParser(aiClient: aiClient);

      final result = await parser.parse('明天中午前写完项目周报，帮我拆细', config: config);

      expect(result.title, '写完项目周报');
      expect(result.substeps.length, 3);
      expect(result.substeps[0].title, '收集数据');
      expect(result.substeps[1].title, '起草内容');
      expect(result.substeps[2].title, '校对发送');
    });

    test(
      'AC-04: gracefully handles surrounding explanatory text without error',
      () async {
        final fakeHttp = _FakeAiHttpClient((uri, headers, body) async {
          return const AiHttpResponse(
            statusCode: 200,
            body: '''
{
  "choices": [
    {
      "message": {
        "content": "好的，这是为您解析的任务：{\\"title\\": \\"修Bug\\", \\"priority\\": 3, \\"tags\\": [\\"紧急\\"]}祝您工作顺利！"
      }
    }
  ]
}
''',
          );
        });

        final aiClient = AiClient(httpClient: fakeHttp);
        final parser = AiTaskParser(aiClient: aiClient);

        final result = await parser.parse('修Bug 紧急', config: config);
        expect(result.title, '修Bug');
        expect(result.priority, 3);
        expect(result.tags, contains('紧急'));
      },
    );

    test('Malformed output falls back safely to original text card', () async {
      final fakeHttp = _FakeAiHttpClient((uri, headers, body) async {
        return const AiHttpResponse(
          statusCode: 200,
          body: '{"choices": [{"message": {"content": "今天天气真好，去散步吧！"}}]}',
        );
      });

      final aiClient = AiClient(httpClient: fakeHttp);
      final parser = AiTaskParser(aiClient: aiClient);

      final result = await parser.parse('去散步', config: config);
      expect(result.title, '去散步');
      expect(result.isFallback, isTrue);
    });
  });
}
