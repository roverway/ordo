import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';

/// Lightweight, embedded Model Context Protocol (MCP) HTTP Server.
///
/// Implements standard JSON-RPC 2.0 handling for MCP methods:
/// - `initialize`
/// - `notifications/initialized`
/// - `ping`
/// - `tools/list`
/// - `tools/call`
///
/// Security: Binds strictly to [InternetAddress.loopbackIPv4] (`127.0.0.1`)
/// so that only local client applications (e.g. Cursor, Claude Desktop, local scripts)
/// can communicate with this service.
class McpServer {
  McpServer({
    required AiToolRegistry registry,
    required AiToolContext Function() contextProvider,
    this.serverName = 'ordo-tasks',
    this.serverVersion = '1.0.0',
    this.protocolVersion = '2024-11-05',
  }) : _registry = registry,
       _contextProvider = contextProvider;

  final AiToolRegistry _registry;
  final AiToolContext Function() _contextProvider;
  final String serverName;
  final String serverVersion;
  final String protocolVersion;

  HttpServer? _server;
  int? _port;

  /// Whether the MCP server is currently listening.
  bool get isRunning => _server != null;

  /// The active listening port, or null if stopped.
  int? get port => _port;

  /// Full endpoint URL for external MCP clients.
  String? get endpointUrl =>
      _server != null ? 'http://127.0.0.1:$_port/mcp' : null;

  /// Starts the MCP server on the specified [port] (default: 8765).
  ///
  /// If the requested port is taken, setting [allowFallbackPort] to true
  /// will bind to any available ephemeral port (port 0).
  Future<int> start({int port = 8765, bool allowFallbackPort = true}) async {
    if (_server != null) {
      return _port!;
    }

    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      _port = _server!.port;
    } catch (e) {
      if (allowFallbackPort && port != 0) {
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
          shared: false,
        );
        _port = _server!.port;
      } else {
        rethrow;
      }
    }

    _server!.listen(
      _handleRequest,
      onError: (Object error) {
        // Prevent unhandled server loop errors
      },
    );

    return _port!;
  }

  /// Stops the MCP server.
  Future<void> stop() async {
    if (_server == null) return;
    final serverToClose = _server;
    _server = null;
    _port = null;
    await serverToClose?.close(force: true);
  }

  /// Internal HTTP request dispatcher with CORS support.
  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // Standard CORS headers for local tools & browser extensions
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, x-api-key',
    );

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    // Health-check / Status info via GET
    if (request.method == 'GET') {
      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.ok;
      final statusInfo = {
        'status': 'ok',
        'server': serverName,
        'version': serverVersion,
        'protocolVersion': protocolVersion,
        'toolsCount': _registry.allTools.length,
        'endpoint': endpointUrl,
      };
      response.write(jsonEncode(statusInfo));
      await response.close();
      return;
    }

    if (request.method != 'POST') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }

    // Read and parse JSON-RPC payload
    try {
      final bodyString = await utf8.decoder.bind(request).join();
      if (bodyString.trim().isEmpty) {
        _writeJsonRpcError(
          response,
          id: null,
          code: -32600,
          message: 'Invalid Request: empty body',
        );
        return;
      }

      final dynamic decoded = jsonDecode(bodyString);
      if (decoded is List) {
        // Batch requests
        final responses = <Map<String, dynamic>>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final res = await _processSingleRpc(item);
            if (res != null) responses.add(res);
          }
        }
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(responses));
        await response.close();
      } else if (decoded is Map<String, dynamic>) {
        final result = await _processSingleRpc(decoded);
        if (result != null) {
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(result));
        } else {
          response.statusCode = HttpStatus.noContent;
        }
        await response.close();
      } else {
        _writeJsonRpcError(
          response,
          id: null,
          code: -32600,
          message: 'Invalid Request: expected JSON object or array',
        );
      }
    } on FormatException {
      _writeJsonRpcError(
        response,
        id: null,
        code: -32700,
        message: 'Parse error: invalid JSON',
      );
    } catch (e) {
      _writeJsonRpcError(
        response,
        id: null,
        code: -32603,
        message: 'Internal error: $e',
      );
    }
  }

  /// Processes a single JSON-RPC 2.0 object.
  Future<Map<String, dynamic>?> _processSingleRpc(
    Map<String, dynamic> request,
  ) async {
    final id = request['id'];
    final method = request['method'];
    final isNotification = id == null;

    if (method is! String) {
      if (isNotification) return null;
      return _buildRpcError(
        id: id,
        code: -32600,
        message: 'Invalid Request: missing method',
      );
    }

    try {
      switch (method) {
        case 'initialize':
          return _buildRpcSuccess(
            id: id,
            result: {
              'protocolVersion': protocolVersion,
              'serverInfo': {'name': serverName, 'version': serverVersion},
              'capabilities': {
                'tools': {'listChanged': false},
              },
            },
          );

        case 'notifications/initialized':
          // Notification: no response required
          return null;

        case 'ping':
          return _buildRpcSuccess(id: id, result: <String, dynamic>{});

        case 'tools/list':
          return _buildRpcSuccess(
            id: id,
            result: {'tools': _registry.toMcpDefinitions()},
          );

        case 'tools/call':
          final params = request['params'] as Map<String, dynamic>?;
          if (params == null || !params.containsKey('name')) {
            return _buildRpcError(
              id: id,
              code: -32602,
              message: 'Invalid params: name required for tools/call',
            );
          }

          final toolName = params['name'] as String;
          final arguments =
              (params['arguments'] as Map<String, dynamic>?) ?? {};
          final context = _contextProvider();

          final toolResult = await _registry.dispatch(
            toolName,
            arguments,
            context,
          );

          return _buildRpcSuccess(
            id: id,
            result: {
              'content': [
                {'type': 'text', 'text': jsonEncode(toolResult.data)},
              ],
              'isError': !toolResult.success,
            },
          );

        default:
          if (isNotification) return null;
          return _buildRpcError(
            id: id,
            code: -32601,
            message: 'Method not found: $method',
          );
      }
    } catch (e) {
      if (isNotification) return null;
      return _buildRpcError(
        id: id,
        code: -32603,
        message: 'Internal error while processing $method: $e',
      );
    }
  }

  Map<String, dynamic> _buildRpcSuccess({
    required dynamic id,
    required dynamic result,
  }) {
    return {'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  Map<String, dynamic> _buildRpcError({
    required dynamic id,
    required int code,
    required String message,
  }) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    };
  }

  Future<void> _writeJsonRpcError(
    HttpResponse response, {
    required dynamic id,
    required int code,
    required String message,
  }) async {
    response.headers.contentType = ContentType.json;
    response.statusCode = HttpStatus.ok;
    response.write(
      jsonEncode(_buildRpcError(id: id, code: code, message: message)),
    );
    await response.close();
  }
}
