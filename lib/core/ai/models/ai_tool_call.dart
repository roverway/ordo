/// Model representing a tool/function call emitted by LLM.
class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  /// The unique call ID (from OpenAI or Claude).
  final String id;

  /// The name of the tool requested.
  final String name;

  /// The parsed JSON arguments provided to the tool.
  final Map<String, dynamic> arguments;
}

/// Unified response from chat tool requests containing textual output and/or tool invocations.
class AiChatResponse {
  const AiChatResponse({
    this.text = '',
    this.toolCalls = const [],
    this.rawResponse,
  });

  /// The assistant's natural language conversational reply (if any).
  final String text;

  /// The list of tools requested to be executed by the model.
  final List<AiToolCall> toolCalls;

  /// The raw model JSON response.
  final Map<String, dynamic>? rawResponse;

  /// Whether the model requested one or more tool calls.
  bool get hasToolCalls => toolCalls.isNotEmpty;
}
