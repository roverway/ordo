import 'ai_tool.dart';
import 'impl/create_tasks_tool.dart';
import 'impl/get_metadata_tool.dart';
import 'impl/query_tasks_tool.dart';
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

  /// Creates a registry initialized with all built-in standard tools.
  factory AiToolRegistry.standard() => AiToolRegistry([
    const QueryTasksTool(),
    const GetMetadataTool(),
    const CreateTasksTool(),
    const UpdateTaskTool(),
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
      return AiToolResult.failure('Tool "$name" not found in registry');
    }
    try {
      return await tool.execute(arguments, context);
    } catch (e, stack) {
      return AiToolResult.failure('Failed to execute tool "$name": $e\n$stack');
    }
  }
}
