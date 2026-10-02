import 'ai_tool.dart';
import 'impl/aggregate_tasks_tool.dart';
import 'impl/confirm_proposals_tool.dart';
import 'impl/create_tasks_bulk_tool.dart';
import 'impl/create_tasks_tool.dart';
import 'impl/daily_briefing_tool.dart';
import 'impl/delete_tasks_tool.dart';
import 'impl/get_metadata_tool.dart';
import 'impl/get_task_tool.dart';
import 'impl/list_proposals_tool.dart';
import 'impl/manage_tags_tool.dart';
import 'impl/query_tasks_tool.dart';
import 'impl/reject_proposals_tool.dart';
import 'impl/update_task_tool.dart';

/// Central registry managing all AI Tools, handling schema conversions and dispatching calls.
class AiToolRegistry {
  AiToolRegistry([List<AiTool>? tools]) {
    if (tools != null) {
      for (final tool in tools) {
        register(tool);
      }
    }
  }

  /// Creates a registry initialized with all built-in standard tools (13 tools).
  factory AiToolRegistry.standard() => AiToolRegistry([
    const QueryTasksTool(),
    const GetMetadataTool(),
    const DailyBriefingTool(),
    const CreateTasksTool(),
    const UpdateTaskTool(),
    const CreateTasksBulkTool(),
    const ManageTagsTool(),
    const ListProposalsTool(),
    const ConfirmProposalsTool(),
    const RejectProposalsTool(),
    const GetTaskTool(),
    const DeleteTasksTool(),
    const AggregateTasksTool(),
  ]);

  final Map<String, AiTool> _tools = {};

  /// Registers a tool into the registry.
  void register(AiTool tool) {
    _tools[tool.name] = tool;
  }

  /// Checks if a tool with given [name] is registered.
  bool has(String name) => _tools.containsKey(name);

  /// Looks up a registered tool by its name.
  AiTool? getTool(String name) => _tools[name];

  /// All registered tools.
  List<AiTool> get allTools => _tools.values.toList();

  /// Converts all registered tools into OpenAI format.
  List<Map<String, dynamic>> toOpenAiTools() =>
      _tools.values.map((t) => t.toOpenAiTool()).toList();

  /// Converts all registered tools into Claude format.
  List<Map<String, dynamic>> toClaudeTools() =>
      _tools.values.map((t) => t.toClaudeTool()).toList();

  /// Converts all registered tools into MCP definitions.
  List<Map<String, dynamic>> toMcpDefinitions() =>
      _tools.values.map((t) => t.toMcpDefinition()).toList();

  /// Dispatches execution of a tool by [name] with [arguments] and [context].
  Future<AiToolResult> dispatch(
    String name,
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final tool = _tools[name];
    if (tool == null) {
      return AiToolResult.failure(
        'Tool "$name" not found in registry',
        code: 'TOOL_NOT_FOUND',
      );
    }
    try {
      return await tool.execute(arguments, context);
    } on TypeError catch (e) {
      // Sanitized error without leaking Dart runtime stack traces (resolves §5.7)
      return AiToolResult.failure(
        'Invalid argument type for tool "$name": ${e.toString().split('\n').first}',
        code: 'INVALID_ARGUMENT',
        hint:
            'Please verify argument types against the tool input schema definition.',
      );
    } on FormatException catch (e) {
      return AiToolResult.failure(e.message, code: 'INVALID_ARGUMENT');
    } catch (e) {
      return AiToolResult.failure(
        'Tool execution error for "$name": $e',
        code: 'EXECUTION_ERROR',
      );
    }
  }
}
