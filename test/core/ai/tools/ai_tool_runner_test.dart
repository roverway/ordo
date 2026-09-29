import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/ai_config.dart';
import 'package:ordo/core/ai/services/ai_client.dart';
import 'package:ordo/core/ai/services/ai_tool_runner.dart';
import 'package:ordo/core/ai/tools/ai_tool.dart';
import 'package:ordo/core/ai/tools/ai_tool_registry.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';

import '../../../helpers/db_test_setup.dart';

class _MockAiHttpClient implements AiHttpClient {
  _MockAiHttpClient(this.handler);

  final Future<AiHttpResponse> Function(
    Uri uri,
    Map<String, String> headers,
    Object? body,
  )
  handler;

  final List<Map<String, dynamic>> recordedBodies = [];

  @override
  Future<AiHttpResponse> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    if (body is String) {
      recordedBodies.add(jsonDecode(body) as Map<String, dynamic>);
    } else if (body is Map) {
      recordedBodies.add(Map<String, dynamic>.from(body));
    }
    return handler(uri, headers ?? {}, body);
  }

  @override
  Future<AiHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return const AiHttpResponse(statusCode: 200, body: '{}');
  }
}

void main() {
  late AppDatabase db;
  late TodoRepository repository;

  setUp(() async {
    db = openTestDatabase();
    repository = TodoRepository(database: db);
    await repository.ensureInboxProject('收件箱');
  });

  tearDown(() async {
    await db.close();
  });

  const testConfig = AiConfig(
    provider: AiProviderType.openai,
    baseUrl: 'https://api.openai.com/v1',
    apiKey: 'sk-test-key',
    model: 'gpt-4o-mini',
  );

  group('AiClient.chatWithTools', () {
    test(
      'correctly decodes tool_calls from OpenAI compatible payload',
      () async {
        final mockHttpClient = _MockAiHttpClient((uri, headers, body) async {
          return const AiHttpResponse(
            statusCode: 200,
            body: jsonPostResponseOpenAi,
          );
        });

        final client = AiClient(httpClient: mockHttpClient);
        final response = await client.chatWithTools(
          testConfig,
          [
            {'role': 'user', 'content': '帮我查一下待办'},
          ],
          tools: [
            {
              'type': 'function',
              'function': {
                'name': 'query_tasks',
                'description': 'Query tasks',
                'parameters': {'type': 'object', 'properties': {}},
              },
            },
          ],
        );

        expect(response.hasToolCalls, isTrue);
        expect(response.toolCalls.length, 1);
        final call = response.toolCalls.first;
        expect(call.name, 'query_tasks');
        expect(call.arguments['statuses'], contains('todo'));
      },
    );
  });

  group('AiToolRunner Agent Loop', () {
    test(
      'executes autonomous tool calling iteration and returns final text',
      () async {
        // 1. Insert a pending task into the DB
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'task-test-query',
            projectId: 'inbox',
            title: '发布 v2.0 正式版',
            status: TaskStatus.todo,
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );

        int round = 0;
        final mockHttpClient = _MockAiHttpClient((uri, headers, body) async {
          round++;
          if (round == 1) {
            // Round 1: Model issues a tool call to query_tasks
            return const AiHttpResponse(
              statusCode: 200,
              body: jsonPostResponseOpenAi,
            );
          } else {
            // Round 2: Model receives tool result and provides final natural language response
            return const AiHttpResponse(
              statusCode: 200,
              body: jsonFinalAnswerOpenAi,
            );
          }
        });

        final client = AiClient(httpClient: mockHttpClient);
        final registry = AiToolRegistry.standard();
        final runner = AiToolRunner(aiClient: client, registry: registry);

        final context = AiToolContext(repository: repository);
        final result = await runner.run(
          config: testConfig,
          context: context,
          userPrompt: '查看待办事项',
        );

        expect(round, 2);
        expect(result.text, contains('您有 1 个待办任务'));
        expect(result.taskProposal, isNull);
      },
    );

    test('captures create_tasks tool proposal for user confirmation', () async {
      final mockHttpClient = _MockAiHttpClient((uri, headers, body) async {
        return const AiHttpResponse(
          statusCode: 200,
          body: jsonCreateTaskToolCallOpenAi,
        );
      });

      final client = AiClient(httpClient: mockHttpClient);
      final registry = AiToolRegistry.standard();
      final runner = AiToolRunner(aiClient: client, registry: registry);

      final context = AiToolContext(repository: repository);
      final result = await runner.run(
        config: testConfig,
        context: context,
        userPrompt: '明天下午开会',
      );

      expect(result.taskProposal, isNotNull);
      expect(result.taskProposal!['title'], '需求评审会议');
      expect(result.taskProposal!['priority'], 2);
    });
  });
}

const jsonPostResponseOpenAi = '''
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": null,
        "tool_calls": [
          {
            "id": "call_123",
            "type": "function",
            "function": {
              "name": "query_tasks",
              "arguments": "{\\"statuses\\": [\\"todo\\"]}"
            }
          }
        ]
      }
    }
  ]
}
''';

const jsonFinalAnswerOpenAi = '''
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "您有 1 个待办任务：发布 v2.0 正式版。"
      }
    }
  ]
}
''';

const jsonCreateTaskToolCallOpenAi = '''
{
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "已为您规划以下任务：",
        "tool_calls": [
          {
            "id": "call_create_1",
            "type": "function",
            "function": {
              "name": "create_tasks",
              "arguments": "{\\"title\\": \\"需求评审会议\\", \\"priority\\": 2, \\"substeps\\": [\\"准备 PPT\\", \\"预约会议室\\"]}"
            }
          }
        ]
      }
    }
  ]
}
''';
