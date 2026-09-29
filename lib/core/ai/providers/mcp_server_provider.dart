import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/projects/project_providers.dart';
import '../mcp/mcp_server.dart';
import '../services/ai_config_service.dart';
import '../tools/ai_tool.dart';
import 'ai_tool_providers.dart';

/// State representation for embedded MCP server.
class McpServerState {
  const McpServerState({
    required this.isEnabled,
    required this.isRunning,
    this.port,
    this.endpointUrl,
    this.errorMessage,
  });

  final bool isEnabled;
  final bool isRunning;
  final int? port;
  final String? endpointUrl;
  final String? errorMessage;
}

/// Provider for embedded [McpServer] singleton.
final mcpServerProvider = Provider<McpServer>((ref) {
  final registry = ref.watch(aiToolRegistryProvider);
  final repo = ref.watch(todoRepositoryProvider);

  final server = McpServer(
    registry: registry,
    contextProvider: () => AiToolContext(
      repository: repo,
      nowUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    ),
  );

  ref.onDispose(() {
    server.stop();
  });

  return server;
});

/// Notifier managing MCP server lifecycle, persistence, and state.
final mcpServerStateProvider =
    NotifierProvider<McpServerNotifier, McpServerState>(McpServerNotifier.new);

class McpServerNotifier extends Notifier<McpServerState> {
  AiConfigService get _configService => ref.read(aiConfigServiceProvider);
  McpServer get _server => ref.read(mcpServerProvider);

  @override
  McpServerState build() {
    _init();
    return const McpServerState(isEnabled: false, isRunning: false);
  }

  Future<void> _init() async {
    final enabled = await _configService.isMcpEnabled();
    final port = await _configService.getMcpPort();

    if (enabled) {
      try {
        final activePort = await _server.start(port: port);
        state = McpServerState(
          isEnabled: true,
          isRunning: true,
          port: activePort,
          endpointUrl: _server.endpointUrl,
        );
        return;
      } catch (e) {
        state = McpServerState(
          isEnabled: true,
          isRunning: false,
          port: port,
          errorMessage: e.toString(),
        );
        return;
      }
    }

    state = McpServerState(isEnabled: false, isRunning: false, port: port);
  }

  /// Toggles the MCP server on or off.
  Future<void> toggleEnabled(bool enabled) async {
    await _configService.setMcpEnabled(enabled);

    if (enabled) {
      try {
        final port = await _configService.getMcpPort();
        final activePort = await _server.start(port: port);
        state = McpServerState(
          isEnabled: true,
          isRunning: true,
          port: activePort,
          endpointUrl: _server.endpointUrl,
          errorMessage: null,
        );
      } catch (e) {
        state = McpServerState(
          isEnabled: true,
          isRunning: false,
          port: state.port,
          errorMessage: e.toString(),
        );
      }
    } else {
      state = McpServerState(
        isEnabled: false,
        isRunning: false,
        port: state.port,
        endpointUrl: null,
        errorMessage: null,
      );
      await _server.stop();
    }
  }

  /// Restarts the server, e.g., if port settings change.
  Future<void> restart() async {
    if (state.isEnabled) {
      await _server.stop();
      final port = await _configService.getMcpPort();
      try {
        final activePort = await _server.start(port: port);
        state = McpServerState(
          isEnabled: true,
          isRunning: true,
          port: activePort,
          endpointUrl: _server.endpointUrl,
          errorMessage: null,
        );
      } catch (e) {
        state = McpServerState(
          isEnabled: true,
          isRunning: false,
          port: port,
          errorMessage: e.toString(),
        );
      }
    }
  }
}
