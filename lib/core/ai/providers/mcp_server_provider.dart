import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/db_providers.dart';
import '../mcp/mcp_server.dart';
import '../proposals/proposal_repository.dart';
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
    this.apiKey,
    this.isAuthEnabled = true,
    this.writeMode = 'direct',
    this.errorMessage,
  });

  final bool isEnabled;
  final bool isRunning;
  final int? port;
  final String? endpointUrl;
  final String? apiKey;
  final bool isAuthEnabled;
  final String writeMode;
  final String? errorMessage;

  McpServerState copyWith({
    bool? isEnabled,
    bool? isRunning,
    int? port,
    String? endpointUrl,
    String? apiKey,
    bool? isAuthEnabled,
    String? writeMode,
    String? errorMessage,
  }) {
    return McpServerState(
      isEnabled: isEnabled ?? this.isEnabled,
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      apiKey: apiKey ?? this.apiKey,
      isAuthEnabled: isAuthEnabled ?? this.isAuthEnabled,
      writeMode: writeMode ?? this.writeMode,
      errorMessage: errorMessage,
    );
  }
}

/// Provider for [ProposalRepository].
final proposalRepositoryProvider = Provider<ProposalRepository>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return ProposalRepository(repo.db);
});

/// Mutable runtime cache for MCP server settings so synchronous callbacks have instant access.
class _McpRuntimeConfig {
  String? apiKey;
  bool isAuthEnabled = true;
  String writeMode = 'direct';
}

final _mcpRuntimeConfigProvider = Provider<_McpRuntimeConfig>((ref) {
  return _McpRuntimeConfig();
});

/// Provider for embedded [McpServer] singleton.
final mcpServerProvider = Provider<McpServer>((ref) {
  final registry = ref.watch(aiToolRegistryProvider);
  final repo = ref.watch(todoRepositoryProvider);
  final proposalRepo = ref.watch(proposalRepositoryProvider);
  final runtime = ref.watch(_mcpRuntimeConfigProvider);

  final server = McpServer(
    registry: registry,
    apiKeyProvider: () => runtime.apiKey,
    isAuthEnabledProvider: () => runtime.isAuthEnabled,
    contextProvider: () => AiToolContext(
      repository: repo,
      proposalRepository: proposalRepo,
      writeMode: runtime.writeMode,
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
  _McpRuntimeConfig get _runtime => ref.read(_mcpRuntimeConfigProvider);

  @override
  McpServerState build() {
    _init();
    return const McpServerState(isEnabled: false, isRunning: false);
  }

  Future<void> _init() async {
    final enabled = await _configService.isMcpEnabled();
    final port = await _configService.getMcpPort();
    final apiKey = await _configService.getMcpApiKey();
    final authEnabled = await _configService.isMcpAuthEnabled();
    final writeMode = await _configService.getMcpWriteMode();

    _runtime.apiKey = apiKey;
    _runtime.isAuthEnabled = authEnabled;
    _runtime.writeMode = writeMode;

    if (enabled) {
      try {
        final activePort = await _server.start(port: port);
        state = McpServerState(
          isEnabled: true,
          isRunning: true,
          port: activePort,
          endpointUrl: _server.endpointUrl,
          apiKey: apiKey,
          isAuthEnabled: authEnabled,
          writeMode: writeMode,
        );
        return;
      } catch (e) {
        state = McpServerState(
          isEnabled: true,
          isRunning: false,
          port: port,
          apiKey: apiKey,
          isAuthEnabled: authEnabled,
          writeMode: writeMode,
          errorMessage: e.toString(),
        );
        return;
      }
    }

    state = McpServerState(
      isEnabled: false,
      isRunning: false,
      port: port,
      apiKey: apiKey,
      isAuthEnabled: authEnabled,
      writeMode: writeMode,
    );
  }

  /// Toggles the MCP server on or off.
  Future<void> toggleEnabled(bool enabled) async {
    await _configService.setMcpEnabled(enabled);

    if (enabled) {
      try {
        final port = await _configService.getMcpPort();
        final activePort = await _server.start(port: port);
        state = state.copyWith(
          isEnabled: true,
          isRunning: true,
          port: activePort,
          endpointUrl: _server.endpointUrl,
          errorMessage: null,
        );
      } catch (e) {
        state = state.copyWith(
          isEnabled: true,
          isRunning: false,
          port: state.port,
          errorMessage: e.toString(),
        );
      }
    } else {
      state = state.copyWith(
        isEnabled: false,
        isRunning: false,
        endpointUrl: null,
        errorMessage: null,
      );
      await _server.stop();
    }
  }

  /// Toggles API key authentication.
  Future<void> toggleAuth(bool enabled) async {
    await _configService.setMcpAuthEnabled(enabled);
    _runtime.isAuthEnabled = enabled;
    state = state.copyWith(isAuthEnabled: enabled);
  }

  /// Sets write mode ('direct' or 'review').
  Future<void> setWriteMode(String mode) async {
    await _configService.setMcpWriteMode(mode);
    _runtime.writeMode = mode;
    state = state.copyWith(writeMode: mode);
  }

  /// Regenerates a new API Key.
  Future<String> regenerateApiKey() async {
    final newKey = await _configService.regenerateMcpApiKey();
    _runtime.apiKey = newKey;
    state = state.copyWith(apiKey: newKey);
    return newKey;
  }

  /// Restarts the server, e.g., if port settings change.
  Future<void> restart() async {
    if (state.isEnabled) {
      await _server.stop();
      final port = await _configService.getMcpPort();
      try {
        final activePort = await _server.start(port: port);
        state = state.copyWith(
          isEnabled: true,
          isRunning: true,
          port: activePort,
          endpointUrl: _server.endpointUrl,
          errorMessage: null,
        );
      } catch (e) {
        state = state.copyWith(
          isEnabled: true,
          isRunning: false,
          port: port,
          errorMessage: e.toString(),
        );
      }
    }
  }
}
