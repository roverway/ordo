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

  /// Executes agent loop responding to [userPrompt] with multi-turn [history].
  Future<AiToolRunnerResult> run({
    required AiConfig config,
    required AiToolContext context,
    required String userPrompt,
    List<Map<String, dynamic>>? history,
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
      if (history != null && history.isNotEmpty) ...history,
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
你是 Ordo 智能待办助手的内核。当前时间：${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 星期$weekday。

你是一个专注于任务管理的行动助手，而不是聊天机器人。你的核心目标是帮助用户清晰行动、减轻认知负荷、掌控时间与进度。

### 可用工具
1. `get_metadata`: 获取当前时间、系统项目清单与标签字典。
2. `query_tasks`: 查询用户任务。支持多维过滤（日期范围 dateScope、已完成时段 completedScope、状态 statuses、优先级 priorities、关键字 searchQuery）。
3. `create_tasks`: 创建待办任务或将复杂任务拆解为子任务。此工具会在界面向用户呈现可视化的交互提案卡片，供用户审查、自由勾选子步骤并一键入库或放弃。
4. `update_task`: 修改待办任务的属性（标题、状态、优先级、日期）。含子任务的父任务状态自动派生。

### 核心行动契约与铁律（必须严格遵守）
1. **【创建与分解必须调用 create_tasks，严禁文本假装分解】**：
   - 当用户要求创建任务、规划日程，或明确要求“分解/拆解/细化/拆细/列出步骤”时，**必须且只能调用 `create_tasks` 工具**生成提案卡片！
   - **绝对严禁**仅仅在自然语言回复中用 Markdown 列表列举步骤而不调用 `create_tasks` 工具。因为只有调用该工具，前端界面才会渲染出可供用户审查、勾选子步骤并一键添加到待办的卡片；若仅用文本回复，用户无法保存任务。
2. **【任务分解判定标准（何为复杂 vs 何为简单）】**：
   - **必须在 `create_tasks` 的 `substeps` 中生成 3~6 个具体子步骤**：
     a) 用户明确提出分解诉求（例如“帮我分解”、“拆解任务”、“规划步骤”、“细化一下”）；
     b) 任务本身是目标性、复合型的复杂项目（如“准备周五产品发布会”、“撰写年度述职报告”、“组织部门团建”）。子步骤应当为动宾清晰、可独立推进的具体行动。
   - **`substeps` 必须保持为空（不进行分解）**：
     a) 单一操作的具体原子任务（如“买牛奶”、“给李总回电话”、“晚上倒垃圾”），除非用户明确要求分解，否则不要过度拆解，避免增加用户认知负担。
3. **【已完成任务查询与时间追溯】**：
   - 当用户询问完成情况（如“我昨天完成了什么”、“某段时间完成情况”、“今天完成了哪些任务”）时，必须先调用 `query_tasks`，并传入 `completedScope`（'yesterday', 'today', 'thisWeek', 'lastWeek'）或 `statuses: ['done']`。
   - `query_tasks` 返回的数据中包含每个任务的 `completedDate`、`completedAt`、`subtaskCount`、`description` 等完整信息，请结合这些字段给出精准自然的回答。
4. **【多轮对话上下文与代词指代】**：
   - 密切关注对话历史（history）。当用户使用代词（如“把它分解一下”、“将这个任务改到周五”、“添加一个子步骤”）时，结合上一轮讨论的任务标题与内容进行连贯操作。
''';
    } else {
      return '''
You are the intelligent core of the Ordo task management assistant. Current time: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ($weekday).

You are a focused productivity companion, not a casual chat bot. Your core goal is to help users take action and maintain clarity.

### Available Tools
1. `get_metadata`: Get system time, project list, and tag taxonomy.
2. `query_tasks`: Query user tasks with rich multi-dimensional filters, including `completedScope` ('today', 'yesterday', 'thisWeek', 'lastWeek'), status, priority, and keywords.
3. `create_tasks`: Propose creating tasks or breaking tasks down into substeps. Calling this emits an interactive review card on the user interface.
4. `update_task`: Modify task properties. Parent task status is derived automatically if subtasks exist.

### Core Action Principles (Strictly Enforced)
1. **Always invoke `create_tasks` for creation or breakdown**:
   - Whenever the user asks to add, plan, or break down / decompose a task, you MUST call the `create_tasks` tool.
   - NEVER simply list steps in markdown text without calling `create_tasks`, because only calling the tool renders the interactive proposal card for the user to review and add.
2. **Task Decomposition Criteria**:
   - Decompose into 3-6 actionable `substeps` when:
     a) The user explicitly asks to break down or plan steps;
     b) The task is composite or goal-oriented (e.g., "Prepare product launch", "Organize team offsite").
   - Keep `substeps` empty for simple atomic actions (e.g., "Buy milk", "Call John back") unless requested.
3. **Historical Completion Queries**:
   - When asked what tasks were completed (yesterday, this week, today), invoke `query_tasks` with `completedScope`. Use the returned `completedDate`, `description`, and `subtaskCount` to answer accurately.
4. **Multi-turn Context**:
   - Refer to previous dialogue history when pronouns ("break it down", "postpone it to tomorrow") are used.
''';
    }
  }
}
