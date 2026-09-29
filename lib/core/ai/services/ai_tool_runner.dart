import 'dart:convert';
import '../models/ai_config.dart';
import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';
import 'ai_client.dart';

/// Execution result of [AiToolRunner].
class AiToolRunnerResult {
  const AiToolRunnerResult({
    required this.text,
    this.taskProposal,
    this.toolCallsExecuted = const [],
  });

  /// Final conversational response text to present to the user.
  final String text;

  /// Optional task proposal payload if [create_tasks] or structured tool was called.
  final Map<String, dynamic>? taskProposal;

  /// History of tool calls executed during this turn.
  final List<String> toolCallsExecuted;
}

/// Agent coordinator responsible for autonomous tool execution loop.
class AiToolRunner {
  const AiToolRunner({
    required this.aiClient,
    required this.registry,
    this.maxRounds = 4,
  });

  final AiClient aiClient;
  final AiToolRegistry registry;
  final int maxRounds;

  /// Executes agent loop responding to [userPrompt].
  Future<AiToolRunnerResult> run({
    required AiConfig config,
    required AiToolContext context,
    required String userPrompt,
    String locale = 'zh',
  }) async {
    final systemPrompt = _buildSystemPrompt(context, locale);

    // Format tools based on model provider
    final List<Map<String, dynamic>> toolsJson =
        config.provider == AiProviderType.claude
        ? registry.toClaudeTools()
        : registry.toOpenAiTools();

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final executedTools = <String>[];
    Map<String, dynamic>? capturedProposal;
    String finalText = '';

    for (int round = 0; round < maxRounds; round++) {
      final response = await aiClient.chatWithTools(
        config,
        messages,
        tools: toolsJson,
        locale: locale,
      );

      if (!response.hasToolCalls) {
        finalText = response.text;
        break;
      }

      // Append assistant call message into history
      if (config.provider == AiProviderType.claude) {
        messages.add({
          'role': 'assistant',
          'content': response.rawResponse?['content'] ?? [],
        });
      } else {
        messages.add({
          'role': 'assistant',
          'content': response.text.isEmpty ? null : response.text,
          'tool_calls':
              (response.rawResponse?['choices']?[0]?['message']?['tool_calls']
                  as List?) ??
              [],
        });
      }

      // Execute each tool requested by the model
      for (final call in response.toolCalls) {
        executedTools.add(call.name);

        final result = await registry.dispatch(
          call.name,
          call.arguments,
          context,
        );

        // If tool generates task creation proposal, capture it
        if (call.name == 'create_tasks' &&
            result.success &&
            result.data != null &&
            result.data!['proposal'] != null) {
          capturedProposal = Map<String, dynamic>.from(
            result.data!['proposal'],
          );
        }

        final resultString = jsonEncode(result.data ?? {'error': result.error});

        // Append tool result into messages
        if (config.provider == AiProviderType.claude) {
          messages.add({
            'role': 'user',
            'content': [
              {
                'type': 'tool_result',
                'tool_use_id': call.id,
                'content': resultString,
              },
            ],
          });
        } else {
          messages.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'name': call.name,
            'content': resultString,
          });
        }
      }

      // If a task creation was proposed, stop agent loop to allow user confirmation
      if (capturedProposal != null) {
        if (response.text.isNotEmpty) {
          finalText = response.text;
        }
        break;
      }
    }

    return AiToolRunnerResult(
      text: finalText,
      taskProposal: capturedProposal,
      toolCallsExecuted: executedTools,
    );
  }

  String _buildSystemPrompt(AiToolContext context, String locale) {
    final now = DateTime.fromMillisecondsSinceEpoch(
      context.currentNowUtcMs,
      isUtc: true,
    ).toLocal();
    final weekdayNames = locale == 'zh'
        ? ['一', '二', '三', '四', '五', '六', '日']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdayNames[now.weekday - 1];

    if (locale == 'zh') {
      return '''
你是一个智能待办任务助手。当前时间：${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 星期$weekday。

你可以使用系统提供的工具来查询或建议操作待办事项：
1. `get_metadata`: 获取当前时间、系统项目清单与标签字典。
2. `query_tasks`: 查询用户任务。支持多维过滤（今天、本周、已过期、状态、优先级、关键字）。
3. `create_tasks`: 当用户想要创建待办任务或将任务拆解为子步骤时使用。请注意这会生成待办提案供用户人工确认，遵循确认原则。
4. `update_task`: 当用户要求修改待办任务的属性（标题、状态、优先级、日期）时使用。注意：含有子任务的父任务不可直接修改状态，其状态由子任务自动推导。

规则与原则：
- 回答保持清晰、专业、极简。
- 当用户要求创建或拆解任务时，使用 `create_tasks` 工具提出建议。
- 当用户询问或检索已有任务时，先调用 `query_tasks` 查询，再以友好的自然语言汇总回答。
''';
    } else {
      return '''
You are an intelligent todo assistant. Current time: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ($weekday).

You can use the provided tools to query or suggest changes to tasks:
1. `get_metadata`: Get system time, project list, and tag taxonomy.
2. `query_tasks`: Query user tasks with rich multi-dimensional filters.
3. `create_tasks`: Propose creating tasks or breaking tasks down into substeps. Requires user confirmation.
4. `update_task`: Propose modifying task properties. Parent task status is derived automatically if subtasks exist.

Be concise, accurate, and helpful.
''';
    }
  }
}
