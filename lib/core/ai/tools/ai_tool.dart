import 'package:ordo/core/db/repositories/todo_repository.dart';
import '../proposals/proposal_repository.dart';

/// Context provided to [AiTool] execution containing repositories and runtime state.
class AiToolContext {
  const AiToolContext({
    required this.repository,
    this.proposalRepository,
    this.writeMode = 'review',
    this.nowUtcMs,
    this.locale = 'zh',
  });

  /// The primary repository for accessing tasks, projects, and tags.
  final TodoRepository repository;

  /// Optional proposal repository for human-in-the-loop staging queue.
  final ProposalRepository? proposalRepository;

  /// Current write execution policy: 'direct' (instant commit) or 'review' (staging queue).
  final String writeMode;

  /// Optional current timestamp in milliseconds UTC (defaults to [DateTime.now]).
  final int? nowUtcMs;

  /// Current UI language/locale.
  final String locale;

  /// Returns effective current timestamp in milliseconds UTC.
  int get currentNowUtcMs =>
      nowUtcMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
}

/// Result returned from executing an [AiTool].
class AiToolResult {
  const AiToolResult({
    required this.success,
    this.data,
    this.error,
    this.errorCode,
    this.errorHint,
    this.errorDetails,
  });

  factory AiToolResult.ok(Map<String, dynamic> data) =>
      AiToolResult(success: true, data: data);

  factory AiToolResult.failure(
    String error, {
    String? code,
    String? hint,
    Map<String, dynamic>? details,
  }) => AiToolResult(
    success: false,
    error: error,
    errorCode: code ?? 'EXECUTION_FAILED',
    errorHint: hint,
    errorDetails: details,
  );

  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final String? errorCode;
  final String? errorHint;
  final Map<String, dynamic>? errorDetails;

  Map<String, dynamic> toJson() => {
    'success': success,
    if (data != null) 'data': data,
    if (error != null)
      'error': {
        'code': errorCode ?? 'EXECUTION_FAILED',
        'message': error,
        if (errorHint != null) 'hint': errorHint,
        if (errorDetails != null) 'details': errorDetails,
      },
  };
}

/// Abstract base class for AI tools compatible with both Model Context Protocol (MCP)
/// and LLM Native Function Calling (OpenAI / Claude).
abstract class AiTool {
  const AiTool();

  /// Unique identifier of the tool (e.g., 'query_tasks').
  String get name;

  /// Detailed human & model-readable explanation of when and how to use this tool.
  String get description;

  /// JSON Schema specification of the parameters accepted by this tool.
  Map<String, dynamic> get inputSchema;

  /// Executes the tool with the given [arguments] under [context].
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  );

  /// Converts this tool specification into OpenAI function calling format.
  Map<String, dynamic> toOpenAiTool() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': inputSchema,
      },
    };
  }

  /// Converts this tool specification into Claude/Anthropic tool format.
  Map<String, dynamic> toClaudeTool() {
    return {
      'name': name,
      'description': description,
      'input_schema': inputSchema,
    };
  }

  /// Whether this tool only reads data without modifying state.
  bool get isReadOnly => false;

  /// Whether this tool performs destructive or irreversible operations (e.g. deletion).
  bool get isDestructive => false;

  /// Whether repeated calls with identical arguments produce the same side-effects.
  bool get isIdempotent => false;

  /// MCP tool annotations dictionary conforming to Model Context Protocol specification.
  Map<String, dynamic> get annotations => {
    'readOnlyHint': isReadOnly,
    'destructiveHint': isDestructive,
    'idempotentHint': isIdempotent,
    'openWorldHint': false,
  };

  /// Converts this tool specification into Model Context Protocol (MCP) definition format.
  Map<String, dynamic> toMcpDefinition() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
      'annotations': annotations,
    };
  }
}
